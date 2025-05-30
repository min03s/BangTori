const express = require('express');
const router = express.Router();
const RoomController = require('../controllers/roomController');
const { roomValidation } = require('../middleware/validation');

// 방 생성
router.post('/', roomValidation.create, RoomController.createRoom);

// 방 참여
router.post('/join', roomValidation.join, RoomController.joinRoom);

// 방 정보 조회
router.get('/:id', RoomController.getRoom);

// 초대 코드로 방 조회
router.get('/invite/:inviteCode', RoomController.getRoomByInviteCode);

// 사용자가 속한 방 목록 조회
router.get('/user/:userId', RoomController.getUserRooms);

// 방 정보 업데이트
router.put('/:roomId', roomValidation.update, RoomController.updateRoom);

// 방에서 나가기
router.delete('/:roomId/leave/:userId', RoomController.leaveRoom);

// 방 삭제 (방장만)
router.delete('/:roomId/owner/:ownerId', RoomController.deleteRoom);

module.exports = router;