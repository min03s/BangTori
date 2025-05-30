const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');
const http = require('http');
const socketIo = require('socket.io');

// 환경변수 로드
dotenv.config();

// Express 앱 생성
const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: process.env.FRONTEND_URL || "http://localhost:3000",
    methods: ["GET", "POST", "PUT", "DELETE"]
  }
});

// 미들웨어
app.use(cors({
  origin: process.env.FRONTEND_URL || "http://localhost:3000",
  credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 데이터베이스 연결
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/bangtori', {
  useNewUrlParser: true,
  useUnifiedTopology: true
})
.then(() => console.log('✅ MongoDB 연결 성공'))
.catch(err => console.error('❌ MongoDB 연결 실패:', err));

// 기본 라우트
app.get('/', (req, res) => {
  res.json({ 
    message: '방토리 API 서버가 실행 중입니다',
    version: '1.0.0',
    endpoints: {
      users: '/api/users',
      rooms: '/api/rooms'
    }
  });
});

// 헬스 체크
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// API 라우트
app.use('/api/users', require('./routes/users'));
app.use('/api/rooms', require('./routes/rooms'));

// Socket.IO 연결 처리
io.on('connection', (socket) => {
  console.log('🔗 사용자 연결:', socket.id);

  // 방 참여
  socket.on('join_room', (roomId) => {
    socket.join(roomId);
    console.log(`📍 사용자 ${socket.id}가 방 ${roomId}에 참여`);
  });

  // 방 나가기
  socket.on('leave_room', (roomId) => {
    socket.leave(roomId);
    console.log(`🚪 사용자 ${socket.id}가 방 ${roomId}에서 나감`);
  });

  // 방 정보 업데이트 브로드캐스트
  socket.on('room_updated', (data) => {
    socket.to(data.roomId).emit('room_updated', data);
  });

  // 연결 해제
  socket.on('disconnect', () => {
    console.log('❌ 사용자 연결 해제:', socket.id);
  });
});

// 에러 핸들링 미들웨어
app.use((error, req, res, next) => {
  console.error('서버 오류:', error);
  res.status(500).json({ 
    success: false,
    message: '서버 내부 오류가 발생했습니다.',
    error: process.env.NODE_ENV === 'development' ? error.message : undefined
  });
});

// 404 핸들러
app.use('*', (req, res) => {
  res.status(404).json({ 
    success: false,
    message: '요청한 리소스를 찾을 수 없습니다.' 
  });
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`🚀 서버가 포트 ${PORT}에서 실행 중입니다.`);
  console.log(`🌐 http://localhost:${PORT} 에서 접속 가능합니다.`);
});

// 글로벌 Socket.IO 인스턴스 내보내기
module.exports = { io };