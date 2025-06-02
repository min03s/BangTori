// backend/routes/roomRoutes.js
const express = require('express');
const router = express.Router();
const roomController = require('../controllers/roomController');
const isRoomOwner = require('../middlewares/isRoomOwner');
const { simpleAuth } = require('../middlewares/simpleAuth');
const { validateRoomInput } = require('../controllers/roomController');

// [POST] /rooms - 방 생성
router.post('/', simpleAuth, validateRoomInput, roomController.createRoom);

// [POST] /rooms/invite - 방 초대코드 생성
router.post('/invite', simpleAuth, roomController.generateInviteCode);

// [POST] /rooms/join - 초대 코드로 방 참여
router.post('/join', simpleAuth, roomController.joinRoom);

// [GET] /rooms/me - 현재 참여 중인 방 조회
router.get('/me', simpleAuth, roomController.getMyRoom);

// [DELETE] /rooms/leave - 방 나가기 (수정: isRoomOwner 미들웨어 제거)
router.delete('/leave', simpleAuth, roomController.leaveRoom);

// [GET] /rooms/:roomId - 방 상세 정보 조회
router.get('/:roomId', simpleAuth, roomController.getRoomDetail);

// [GET] /rooms/:roomId/members - 방 멤버 목록 조회
router.get('/:roomId/members', simpleAuth, roomController.getRoomMembers);

// [DELETE] /rooms/:roomId - 방 삭제 (방장만)
router.delete('/:roomId', simpleAuth, isRoomOwner, roomController.deleteRoom);

// [PATCH] /rooms/:roomId - 방 정보 수정 (방장만)
router.patch('/:roomId', simpleAuth, isRoomOwner, roomController.updateRoom);

// [PATCH] /rooms/:roomId/transfer-ownership - 방장 위임 (방장만)
router.patch('/:roomId/transfer-ownership', simpleAuth, isRoomOwner, roomController.transferOwnership);

// [DELETE] /rooms/:roomId/members/:userId - 방 멤버 내보내기 (방장만)
router.delete('/:roomId/members/:userId', simpleAuth, isRoomOwner, roomController.kickMember);

// 중복된 라우트 제거 (원래 있던 /rooms/me 삭제 라우트는 이미 위에 있음)

module.exports = router;