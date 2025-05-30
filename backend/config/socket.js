const jwt = require('jsonwebtoken');
const User = require('../models/User');

module.exports = (io) => {
  // 인증 미들웨어
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token;
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const user = await User.findById(decoded.id).populate('currentRoom');
      
      socket.userId = user._id;
      socket.roomId = user.currentRoom?._id;
      socket.user = user;
      
      next();
    } catch (error) {
      next(new Error('Authentication error'));
    }
  });

  io.on('connection', (socket) => {
    console.log(`사용자 연결: ${socket.user.nickname}`);

    // 방 참여
    if (socket.roomId) {
      socket.join(socket.roomId.toString());
      
      // 접속 상태 알림
      socket.to(socket.roomId.toString()).emit('user_status', {
        userId: socket.userId,
        status: 'online',
        nickname: socket.user.nickname
      });
    }

    // 채팅 메시지
    socket.on('chat_message', async (data) => {
      try {
        const Message = require('../models/Message');
        
        const message = new Message({
          room: socket.roomId,
          sender: socket.userId,
          content: data.content,
          type: data.type || 'text'
        });
        
        await message.save();
        await message.populate('sender', 'nickname profileImage');

        // 방의 모든 사용자에게 메시지 전송
        io.to(socket.roomId.toString()).emit('chat_message', {
          id: message._id,
          content: message.content,
          type: message.type,
          sender: message.sender,
          createdAt: message.createdAt
        });

      } catch (error) {
        console.error('채팅 메시지 오류:', error);
        socket.emit('error', { message: '메시지 전송에 실패했습니다' });
      }
    });

    // 쪽지 전송
    socket.on('send_note', async (data) => {
      try {
        const { recipientId, message } = data;
        
        // 수신자에게 쪽지 전송
        const recipientSockets = await io.in(socket.roomId.toString()).fetchSockets();
        const recipientSocket = recipientSockets.find(s => s.userId.toString() === recipientId);
        
        if (recipientSocket) {
          recipientSocket.emit('note_received', {
            from: socket.user.nickname,
            message,
            timestamp: new Date()
          });
        }

        socket.emit('note_sent', { success: true });

      } catch (error) {
        console.error('쪽지 전송 오류:', error);
        socket.emit('error', { message: '쪽지 전송에 실패했습니다' });
      }
    });

    // 위치 상태 업데이트
    socket.on('location_update', async (data) => {
      try {
        const { status } = data; // 'home' | 'out'
        
        await User.findByIdAndUpdate(socket.userId, {
          'location.status': status,
          'location.lastUpdated': new Date()
        });

        // 룸메이트들에게 위치 상태 알림
        socket.to(socket.roomId.toString()).emit('location_update', {
          userId: socket.userId,
          nickname: socket.user.nickname,
          status
        });

      } catch (error) {
        console.error('위치 업데이트 오류:', error);
      }
    });

    // 체크리스트 업데이트
    socket.on('checklist_update', (data) => {
      socket.to(socket.roomId.toString()).emit('checklist_update', {
        ...data,
        updatedBy: socket.user.nickname
      });
    });

    // 룰렛 게임
    socket.on('roulette_spin', (data) => {
      socket.to(socket.roomId.toString()).emit('roulette_result', {
        ...data,
        spinner: socket.user.nickname
      });
    });

    // 연결 해제
    socket.on('disconnect', () => {
      console.log(`사용자 연결 해제: ${socket.user.nickname}`);
      
      if (socket.roomId) {
        socket.to(socket.roomId.toString()).emit('user_status', {
          userId: socket.userId,
          status: 'offline',
          nickname: socket.user.nickname
        });
      }
    });
  });
};