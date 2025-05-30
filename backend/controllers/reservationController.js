const Reservation = require('../models/Reservation');
const Room = require('../models/Room');
const User = require('../models/User');
const { validationResult } = require('express-validator');
const socketService = require('../services/socketService');

// 예약 생성
exports.createReservation = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { type, date, startTime, endTime, isRepeating, weekdays } = req.body;
    const userId = req.user._id;

    // 사용자의 방 확인
    const user = await User.findById(userId).populate('currentRoom');
    if (!user.currentRoom) {
      return res.status(400).json({ message: '방에 속해있지 않습니다' });
    }

    // 시간 충돌 검사
    const conflictingReservation = await checkTimeConflict(
      user.currentRoom._id,
      type,
      date,
      startTime,
      endTime
    );

    if (conflictingReservation) {
      return res.status(400).json({ 
        message: '해당 시간에 이미 예약이 있습니다',
        conflict: conflictingReservation
      });
    }

    // 예약 생성
    const reservations = [];
    
    if (isRepeating && weekdays.length > 0) {
      // 반복 예약 생성 (다음 4주간)
      for (let week = 0; week < 4; week++) {
        for (const weekday of weekdays) {
          const reservationDate = new Date(date);
          reservationDate.setDate(reservationDate.getDate() + (week * 7) + weekday);
          
          const reservation = new Reservation({
            room: user.currentRoom._id,
            user: userId,
            type,
            date: reservationDate,
            startTime,
            endTime,
            isRepeating,
            repeatGroup: new mongoose.Types.ObjectId() // 반복 그룹 ID
          });
          
          reservations.push(reservation);
        }
      }
    } else {
      // 단일 예약
      const reservation = new Reservation({
        room: user.currentRoom._id,
        user: userId,
        type,
        date,
        startTime,
        endTime,
        isRepeating: false
      });
      
      reservations.push(reservation);
    }

    await Reservation.insertMany(reservations);

    // 룸메이트들에게 알림 전송
    const roomMembers = await User.find({ 
      currentRoom: user.currentRoom._id,
      _id: { $ne: userId }
    });

    const notificationData = {
      type: 'reservation_created',
      message: `${user.nickname}님이 ${type} 예약을 추가했습니다`,
      reservation: reservations[0]
    };

    // Socket.IO로 실시간 알림
    socketService.sendToRoom(user.currentRoom._id, 'notification', notificationData);

    // FCM 푸시 알림
    const pushTokens = roomMembers
      .filter(member => member.notifications.push && member.notifications.token)
      .map(member => member.notifications.token);

    if (pushTokens.length > 0) {
      await sendPushNotification(pushTokens, notificationData);
    }

    res.status(201).json({
      message: '예약이 생성되었습니다',
      reservations
    });

  } catch (error) {
    console.error('예약 생성 오류:', error);
    res.status(500).json({ message: '서버 오류가 발생했습니다' });
  }
};

// 예약 조회
exports.getReservations = async (req, res) => {
  try {
    const { startDate, endDate, type } = req.query;
    const userId = req.user._id;

    const user = await User.findById(userId).populate('currentRoom');
    if (!user.currentRoom) {
      return res.status(400).json({ message: '방에 속해있지 않습니다' });
    }

    const query = {
      room: user.currentRoom._id,
      date: {
        $gte: new Date(startDate),
        $lte: new Date(endDate)
      }
    };

    if (type) {
      query.type = type;
    }

    const reservations = await Reservation.find(query)
      .populate('user', 'nickname profileImage')
      .sort({ date: 1, startTime: 1 });

    res.json({ reservations });

  } catch (error) {
    console.error('예약 조회 오류:', error);
    res.status(500).json({ message: '서버 오류가 발생했습니다' });
  }
};

// 예약 삭제
exports.deleteReservation = async (req, res) => {
  try {
    const { id } = req.params;
    const { deleteType } = req.body; // 'single' | 'future'
    const userId = req.user._id;

    const reservation = await Reservation.findById(id);
    if (!reservation) {
      return res.status(404).json({ message: '예약을 찾을 수 없습니다' });
    }

    // 권한 확인 (예약자 본인 또는 방장)
    const user = await User.findById(userId).populate('currentRoom');
    const isOwner = user.currentRoom.owner.toString() === userId.toString();
    const isReservationOwner = reservation.user.toString() === userId.toString();

    if (!isOwner && !isReservationOwner) {
      return res.status(403).json({ message: '권한이 없습니다' });
    }

    if (reservation.isRepeating && deleteType === 'future') {
      // 이후 모든 반복 일정 삭제
      await Reservation.deleteMany({
        repeatGroup: reservation.repeatGroup,
        date: { $gte: reservation.date }
      });
    } else {
      // 단일 일정 삭제
      await Reservation.findByIdAndDelete(id);
    }

    res.json({ message: '예약이 삭제되었습니다' });

  } catch (error) {
    console.error('예약 삭제 오류:', error);
    res.status(500).json({ message: '서버 오류가 발생했습니다' });
  }
};

// 시간 충돌 검사 함수
async function checkTimeConflict(roomId, type, date, startTime, endTime) {
  const existingReservations = await Reservation.find({
    room: roomId,
    type,
    date: new Date(date)
  });

  for (const existing of existingReservations) {
    const existingStart = parseTime(existing.startTime);
    const existingEnd = parseTime(existing.endTime);
    const newStart = parseTime(startTime);
    const newEnd = parseTime(endTime);

    // 시간 겹침 검사
    if (
      (newStart >= existingStart && newStart < existingEnd) ||
      (newEnd > existingStart && newEnd <= existingEnd) ||
      (newStart <= existingStart && newEnd >= existingEnd)
    ) {
      return existing;
    }
  }

  return null;
}

function parseTime(timeString) {
  const [hours, minutes] = timeString.split(':').map(Number);
  return hours * 60 + minutes;
}

// FCM 푸시 알림 전송
async function sendPushNotification(tokens, data) {
  const admin = require('firebase-admin');
  
  const message = {
    notification: {
      title: '방토리',
      body: data.message
    },
    data: {
      type: data.type,
      payload: JSON.stringify(data)
    },
    tokens
  };

  try {
    const response = await admin.messaging().sendMulticast(message);
    console.log('푸시 알림 전송 성공:', response.successCount);
  } catch (error) {
    console.error('푸시 알림 전송 실패:', error);
  }
}