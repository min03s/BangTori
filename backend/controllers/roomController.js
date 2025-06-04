// backend/controllers/roomController.js
const roomService = require('../services/roomService');
const notificationService = require('../services/notificationService');
const RoomMember = require('../models/RoomMember');
const { body, validationResult } = require('express-validator');
const mongoose = require('mongoose');

// 입력값 검증 미들웨어
const validateRoomInput = [
  body('roomName').trim().escape().notEmpty().withMessage('방 이름은 필수입니다.'),
  body('address').optional().trim().escape()
];

// 응답 포맷 생성 함수
const createResponse = (status, message, data = null) => {
  const response = {
    resultCode: status.toString(),
    resultMessage: message
  };
  if (data) {
    Object.assign(response, data);
  }
  return response;
};

// 방 관련 컨트롤러
const roomController = {
  /**
   * 방 생성 컨트롤러
   * @route POST /rooms
   * @description 새로운 방을 생성하고 초대 코드를 발급합니다.
   * @param {string} roomName - 방 이름 (필수)
   * @param {string} address - 방 주소 (선택)
   * @returns {Object} 생성된 방 정보와 초대 코드
   */
  async createRoom(req, res) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json(
          createResponse(400, '잘못된 입력입니다.')
        );
      }

      const room = await roomService.createRoom(req.body, req.user._id);

      // 방 생성 알림은 roomService에서 처리됨

      return res.status(201).json(
        createResponse(201, '방 생성 완료', {
          room: {
            roomId: room._id,
            roomName: room.roomName,
            address: room.address
          },
          inviteCode: room.inviteCode,
          expiresIn: 180
        })
      );
    } catch (error) {
      console.error('방 생성 중 에러:', error);
      return res.status(500).json(
        createResponse(500, '서버 오류로 방 생성에 실패했습니다.')
      );
    }
  },

  /**
   * 초대코드 생성 컨트롤러
   * @route POST /rooms/invite
   * @description 방장이 새로운 초대 코드를 생성합니다.
   * @param {string} roomId - 방 ID
   * @returns {Object} 새로 생성된 초대 코드와 만료 시간
   */
  async generateInviteCode(req, res) {
    try {
      const { roomId } = req.body;
      const room = await roomService.generateInviteCode(roomId, req.user._id);

      // 초대 코드 생성 알림
      try {
        const generatedBy = await RoomMember.findOne({
          roomId: roomId,
          userId: req.user._id
        });

        await notificationService.notifyRoomMembers({
          roomId: roomId,
          fromUserId: req.user._id,
          type: 'invite_code_generated',
          title: '초대 코드 생성',
          message: `${generatedBy?.nickname || '방장'}님이 새로운 초대 코드를 생성했습니다.`,
          relatedData: {
            inviteCode: room.inviteCode,
            expiresAt: room.inviteCodeExpiresAt
          }
        });
      } catch (notificationError) {
        console.error('초대 코드 생성 알림 전송 실패:', notificationError);
      }

      return res.status(200).json(
        createResponse(200, '초대 코드 생성 완료', {
          inviteCode: room.inviteCode,
          expiresIn: 180
        })
      );
    } catch (error) {
      console.error('초대코드 생성 중 에러:', error);
      return res.status(400).json(
        createResponse(400, error.message)
      );
    }
  },

  /**
   * 방 참여 컨트롤러
   * @route POST /rooms/join
   * @description 초대 코드를 사용하여 방에 참여합니다.
   * @param {string} inviteCode - 초대 코드
   * @returns {Object} 참여한 방 정보
   */
  async joinRoom(req, res) {
    try {
      const { inviteCode } = req.body;
      const room = await roomService.joinRoom(inviteCode, req.user._id);

      // 방 참여 알림은 roomService에서 처리됨

      return res.status(200).json(
        createResponse(200, '방 참여 완료', {
          room: {
            roomId: room._id,
            roomName: room.roomName
          }
        })
      );
    } catch (error) {
      console.error('방 참여 중 에러:', error);
      return res.status(400).json(
        createResponse(400, error.message)
      );
    }
  },

  /**
   * 현재 참여 중인 방 조회 컨트롤러
   * @route GET /rooms/me
   * @description 현재 로그인한 사용자가 참여 중인 방 정보를 조회합니다.
   * @returns {Object} 참여 중인 방 정보
   */
  async getMyRoom(req, res) {
    try {
      const roomMember = await roomService.getMyRoom(req.user._id);

      return res.status(200).json(
        createResponse(200, '방 정보 조회 완료', {
          room: {
            roomId: roomMember.roomId._id,
            roomName: roomMember.roomId.roomName,
            address: roomMember.roomId.address,
            isOwner: roomMember.isOwner
          }
        })
      );
    } catch (error) {
      console.error('방 조회 중 에러:', error);
      return res.status(404).json(
        createResponse(404, error.message)
      );
    }
  },

  /**
   * 방 상세 정보 조회 컨트롤러
   * @route GET /rooms/:roomId
   * @description 특정 방의 상세 정보를 조회합니다.
   * @param {string} roomId - 방 ID
   * @returns {Object} 방 상세 정보와 멤버 목록
   */
  async getRoomDetail(req, res) {
    try {
      const room = await roomService.getRoomDetail(req.params.roomId, req.user._id);

      return res.status(200).json(
        createResponse(200, '방 상세 정보 조회 완료', {
          room: {
            roomId: room._id,
            roomName: room.roomName,
            address: room.address,
            members: room.members.map(member => ({
              userId: member.userId,
              isOwner: member.isOwner
            }))
          }
        })
      );
    } catch (error) {
      console.error('방 상세 정보 조회 중 에러:', error);
      return res.status(403).json(
        createResponse(403, error.message)
      );
    }
  },

  /**
   * 방 삭제 컨트롤러
   * @route DELETE /rooms/:roomId
   * @description 방장이 방을 삭제합니다.
   * @param {string} roomId - 방 ID
   * @returns {Object} 삭제 결과
   */
  async deleteRoom(req, res) {
    try {
      await roomService.deleteRoom(req.params.roomId, req.user._id);

      return res.status(200).json(
        createResponse(200, '방 삭제 완료')
      );
    } catch (error) {
      console.error('방 삭제 중 에러:', error);
      return res.status(403).json(
        createResponse(403, error.message)
      );
    }
  },

  /**
   * 방 정보 수정 컨트롤러 - isOwner 정보 포함하여 응답
   * @route PATCH /rooms/:roomId
   * @description 방장이 방 정보를 수정합니다.
   * @param {string} roomId - 방 ID
   * @param {string} roomName - 새로운 방 이름 (선택)
   * @param {string} address - 새로운 방 주소 (선택)
   * @returns {Object} 수정된 방 정보 (isOwner 포함)
   */
  async updateRoom(req, res) {
    try {
      const updatedRoom = await roomService.updateRoom(
        req.params.roomId,
        req.user._id,
        req.body
      );

      // 방 정보 수정 알림
      try {
        const updatedBy = await RoomMember.findOne({
          roomId: req.params.roomId,
          userId: req.user._id
        });

        await notificationService.notifyRoomMembers({
          roomId: req.params.roomId,
          fromUserId: req.user._id,
          type: 'room_updated',
          title: '방 정보 수정',
          message: `${updatedBy?.nickname || '방장'}님이 방 정보를 수정했습니다.`,
          relatedData: {
            roomName: updatedRoom.roomName,
            address: updatedRoom.address
          }
        });
      } catch (notificationError) {
        console.error('방 정보 수정 알림 전송 실패:', notificationError);
      }

      // 방장인지 확인 (수정 권한이 있었다는 것은 방장이라는 의미)
      const isOwner = updatedRoom.ownerId.toString() === req.user._id.toString();

      return res.status(200).json(
        createResponse(200, '방 정보 수정 완료', {
          room: {
            roomId: updatedRoom._id,
            roomName: updatedRoom.roomName,
            address: updatedRoom.address,
            isOwner: isOwner
          }
        })
      );
    } catch (error) {
      console.error('방 정보 수정 중 에러:', error);
      return res.status(403).json(
        createResponse(403, error.message)
      );
    }
  },

  /**
   * 방 멤버 목록 조회
   */
  async getRoomMembers(req, res) {
    try {
      const { roomId } = req.params;
      const members = await roomService.getRoomMembers(roomId);

      return res.status(200).json({
        resultCode: '200',
        resultMessage: '방 멤버 목록 조회 성공',
        members
      });
    } catch (error) {
      console.error('방 멤버 목록 조회 중 에러:', error);
      return res.status(400).json({
        resultCode: '400',
        resultMessage: error.message
      });
    }
  },

  /**
   * 방 나가기 컨트롤러
   * @route DELETE /rooms/leave
   * @description 사용자가 현재 참여 중인 방을 나갑니다.
   * @returns {Object} 나가기 결과
   */
  async leaveRoom(req, res) {
    try {
      await roomService.leaveRoom(req.user._id);

      // 방 나가기 알림은 roomService에서 처리됨

      return res.status(200).json(
        createResponse(200, '방을 성공적으로 나갔습니다.')
      );
    } catch (error) {
      console.error('방 나가기 중 에러:', error);
      return res.status(400).json(
        createResponse(400, error.message)
      );
    }
  },

  /**
   * 방장 위임 컨트롤러
   * @route PATCH /rooms/:roomId/transfer-ownership
   * @description 방장이 다른 멤버에게 방장을 위임합니다.
   * @param {string} roomId - 방 ID
   * @param {string} newOwnerId - 새로운 방장 ID
   * @returns {Object} 위임 결과
   */
  async transferOwnership(req, res) {
    try {
      const { roomId } = req.params;
      const { newOwnerId } = req.body;

      if (!newOwnerId) {
        return res.status(400).json(
          createResponse(400, '새로운 방장 ID가 필요합니다.')
        );
      }

      await roomService.transferOwnership(roomId, req.user._id, newOwnerId);

      // 방장 위임 알림은 roomService에서 처리됨

      return res.status(200).json(
        createResponse(200, '방장 위임이 완료되었습니다.')
      );
    } catch (error) {
      console.error('방장 위임 중 에러:', error);
      return res.status(400).json(
        createResponse(400, error.message)
      );
    }
  },

  /**
   * 방 멤버 내보내기(추방)
   * @route DELETE /rooms/:roomId/members/:userId
   * @description 방장이 특정 멤버를 방에서 내보냅니다.
   */
  async kickMember(req, res) {
    try {
      const { roomId, userId } = req.params;

      // 내보내기 전에 멤버 정보 조회 (알림을 위해)
      const member = await RoomMember.findOne({ roomId, userId });

      await roomService.kickMember(roomId, userId, req.user._id);

      // 멤버 내보내기 알림
      try {
        if (member) {
          // 내보낸 멤버에게 알림
          await notificationService.notifyUser({
            userId: userId,
            fromUserId: req.user._id,
            roomId: roomId,
            type: 'member_kicked',
            title: '방에서 내보내짐',
            message: '방에서 내보내졌습니다.',
            relatedData: { kickedByOwnerId: req.user._id }
          });

          // 다른 멤버들에게 알림
          await notificationService.notifyRoomMembers({
            roomId: roomId,
            fromUserId: req.user._id,
            type: 'member_kicked',
            title: '멤버 내보내기',
            message: `${member.nickname}님이 방에서 내보내졌습니다.`,
            relatedData: {
              kickedUserId: userId,
              kickedUserNickname: member.nickname
            },
            excludeUserIds: [userId] // 내보낸 멤버는 이미 개별 알림을 받았으므로 제외
          });
        }
      } catch (notificationError) {
        console.error('멤버 내보내기 알림 전송 실패:', notificationError);
      }

      return res.status(200).json({
        resultCode: '200',
        resultMessage: '멤버 내보내기 완료'
      });
    } catch (error) {
      console.error('멤버 내보내기 중 에러:', error);
      return res.status(400).json({
        resultCode: '400',
        resultMessage: error.message
      });
    }
  }
};

module.exports = {
  ...roomController,
  validateRoomInput
};