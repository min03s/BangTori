const Room = require('../models/Room');
const User = require('../models/User');
const CodeGenerator = require('../utils/codeGenerator');
const ResponseHelper = require('../utils/responseHelper');
const { validationResult } = require('express-validator');
const { io } = require('../server');

class RoomController {
  // 방 생성
  static async createRoom(req, res) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return ResponseHelper.validationError(res, errors.array());
      }

      const { name, description, ownerId } = req.body;

      // 소유자 확인
      const owner = await User.findById(ownerId);
      if (!owner) {
        return ResponseHelper.notFound(res, '사용자를 찾을 수 없습니다');
      }

      // 고유한 초대 코드 생성
      const inviteCode = await CodeGenerator.generateUniqueInviteCode(Room);

      // 방 생성
      const room = new Room({
        name: name.trim(),
        description: description?.trim() || '',
        inviteCode,
        owner: ownerId,
        members: [{
          user: ownerId,
          joinedAt: new Date()
        }]
      });

      await room.save();
      await room.populate('owner members.user');

      ResponseHelper.created(res, room, '방이 성공적으로 생성되었습니다');
    } catch (error) {
      console.error('방 생성 오류:', error);
      ResponseHelper.serverError(res, '방 생성 중 오류가 발생했습니다');
    }
  }

  // 초대 코드로 방 참여
  static async joinRoom(req, res) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return ResponseHelper.validationError(res, errors.array());
      }

      const { inviteCode, userId } = req.body;

      // 사용자 확인
      const user = await User.findById(userId);
      if (!user) {
        return ResponseHelper.notFound(res, '사용자를 찾을 수 없습니다');
      }

      // 방 찾기
      const room = await Room.findOne({ 
        inviteCode: inviteCode.toUpperCase(),
        isActive: true 
      }).populate('owner members.user');

      if (!room) {
        return ResponseHelper.notFound(res, '유효하지 않은 초대 코드입니다');
      }

      // 이미 멤버인지 확인
      const isAlreadyMember = room.members.some(
        member => member.user._id.toString() === userId
      );

      if (isAlreadyMember) {
        return ResponseHelper.success(res, room, '이미 참여 중인 방입니다');
      }

      // 최대 인원 확인
      if (room.members.length >= room.maxMembers) {
        return ResponseHelper.error(res, '방이 가득 찼습니다', 400);
      }

      // 멤버 추가
      room.members.push({
        user: userId,
        joinedAt: new Date()
      });

      await room.save();
      await room.populate('owner members.user');

      // Socket.IO로 실시간 업데이트
      io.to(room.id).emit('member_joined', {
        room: room,
        newMember: user
      });

      ResponseHelper.success(res, room, '방에 성공적으로 참여했습니다');
    } catch (error) {
      console.error('방 참여 오류:', error);
      ResponseHelper.serverError(res, '방 참여 중 오류가 발생했습니다');
    }
  }

  // 방 정보 조회
  static async getRoom(req, res) {
    try {
      const { id } = req.params;

      const room = await Room.findById(id)
        .populate('owner members.user');

      if (!room || !room.isActive) {
        return ResponseHelper.notFound(res, '방을 찾을 수 없습니다');
      }

      ResponseHelper.success(res, room);
    } catch (error) {
      console.error('방 조회 오류:', error);
      ResponseHelper.serverError(res, '방 조회 중 오류가 발생했습니다');
    }
  }

  // 초대 코드로 방 조회
  static async getRoomByInviteCode(req, res) {
    try {
      const { inviteCode } = req.params;

      const room = await Room.findOne({ 
        inviteCode: inviteCode.toUpperCase(),
        isActive: true 
      }).populate('owner members.user');

      if (!room) {
        return ResponseHelper.notFound(res, '유효하지 않은 초대 코드입니다');
      }

      ResponseHelper.success(res, room);
    } catch (error) {
      console.error('방 조회 오류:', error);
      ResponseHelper.serverError(res, '방 조회 중 오류가 발생했습니다');
    }
  }

  // 사용자가 속한 방 목록 조회
  static async getUserRooms(req, res) {
    try {
      const { userId } = req.params;

      const rooms = await Room.find({
        'members.user': userId,
        isActive: true
      }).populate('owner members.user');

      ResponseHelper.success(res, rooms);
    } catch (error) {
      console.error('사용자 방 목록 조회 오류:', error);
      ResponseHelper.serverError(res, '방 목록 조회 중 오류가 발생했습니다');
    }
  }

  // 방에서 나가기
  static async leaveRoom(req, res) {
    try {
      const { roomId, userId } = req.params;

      const room = await Room.findById(roomId).populate('owner members.user');
      if (!room || !room.isActive) {
        return ResponseHelper.notFound(res, '방을 찾을 수 없습니다');
      }

      // 방장인 경우 처리
      if (room.owner._id.toString() === userId) {
        if (room.members.length > 1) {
          // 다른 멤버가 있으면 첫 번째 멤버에게 방장 권한 이전
          const newOwner = room.members.find(member => 
            member.user._id.toString() !== userId
          );
          room.owner = newOwner.user._id;
        } else {
          // 혼자 있으면 방 비활성화
          room.isActive = false;
        }
      }

      // 멤버에서 제거
      room.members = room.members.filter(
        member => member.user._id.toString() !== userId
      );

      await room.save();

      // Socket.IO로 실시간 업데이트
      io.to(roomId).emit('member_left', {
        room: room,
        leftUserId: userId
      });

      ResponseHelper.success(res, null, '방에서 나왔습니다');
    } catch (error) {
      console.error('방 나가기 오류:', error);
      ResponseHelper.serverError(res, '방 나가기 중 오류가 발생했습니다');
    }
  }

  // 방 정보 업데이트
  static async updateRoom(req, res) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return ResponseHelper.validationError(res, errors.array());
      }

      const { roomId } = req.params;
      const { name, description, ownerId } = req.body;

      const room = await Room.findById(roomId).populate('owner members.user');
      if (!room || !room.isActive) {
        return ResponseHelper.notFound(res, '방을 찾을 수 없습니다');
      }

      // 권한 확인 (방장만 수정 가능)
      if (room.owner._id.toString() !== ownerId) {
        return ResponseHelper.forbidden(res, '방장만 방 정보를 수정할 수 있습니다');
      }

      // 정보 업데이트
      if (name) room.name = name.trim();
      if (description !== undefined) room.description = description.trim();

      await room.save();

      // Socket.IO로 실시간 업데이트
      io.to(roomId).emit('room_updated', { room });

      ResponseHelper.success(res, room, '방 정보가 업데이트되었습니다');
    } catch (error) {
      console.error('방 업데이트 오류:', error);
      ResponseHelper.serverError(res, '방 정보 업데이트 중 오류가 발생했습니다');
    }
  }

  // 방 삭제 (방장만)
  static async deleteRoom(req, res) {
    try {
      const { roomId, ownerId } = req.params;

      const room = await Room.findById(roomId);
      if (!room) {
        return ResponseHelper.notFound(res, '방을 찾을 수 없습니다');
      }

      // 권한 확인
      if (room.owner.toString() !== ownerId) {
        return ResponseHelper.forbidden(res, '방장만 방을 삭제할 수 있습니다');
      }

      // 방 비활성화 (완전 삭제 대신)
      room.isActive = false;
      await room.save();

      // Socket.IO로 방 삭제 알림
      io.to(roomId).emit('room_deleted', { roomId });

      ResponseHelper.success(res, null, '방이 삭제되었습니다');
    } catch (error) {
      console.error('방 삭제 오류:', error);
      ResponseHelper.serverError(res, '방 삭제 중 오류가 발생했습니다');
    }
  }
}

module.exports = RoomController;