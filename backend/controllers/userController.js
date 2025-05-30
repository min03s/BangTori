const User = require('../models/User');
const CodeGenerator = require('../utils/codeGenerator');
const ResponseHelper = require('../utils/responseHelper');
const { validationResult } = require('express-validator');

class UserController {
  // 사용자 생성
  static async createUser(req, res) {
    try {
      // 유효성 검사
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return ResponseHelper.validationError(res, errors.array());
      }

      const { nickname } = req.body;

      // 사용자 생성
      const user = new User({
        nickname: nickname.trim(),
        profileColor: CodeGenerator.getRandomProfileColor()
      });

      await user.save();

      ResponseHelper.created(res, user, '사용자가 성공적으로 생성되었습니다');
    } catch (error) {
      console.error('사용자 생성 오류:', error);
      ResponseHelper.serverError(res, '사용자 생성 중 오류가 발생했습니다');
    }
  }

  // 사용자 조회
  static async getUser(req, res) {
    try {
      const { id } = req.params;

      const user = await User.findById(id);
      if (!user) {
        return ResponseHelper.notFound(res, '사용자를 찾을 수 없습니다');
      }

      ResponseHelper.success(res, user);
    } catch (error) {
      console.error('사용자 조회 오류:', error);
      ResponseHelper.serverError(res, '사용자 조회 중 오류가 발생했습니다');
    }
  }

  // 사용자 정보 업데이트
  static async updateUser(req, res) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return ResponseHelper.validationError(res, errors.array());
      }

      const { id } = req.params;
      const updates = req.body;

      const user = await User.findByIdAndUpdate(
        id,
        { ...updates, lastActive: Date.now() },
        { new: true, runValidators: true }
      );

      if (!user) {
        return ResponseHelper.notFound(res, '사용자를 찾을 수 없습니다');
      }

      ResponseHelper.success(res, user, '사용자 정보가 업데이트되었습니다');
    } catch (error) {
      console.error('사용자 업데이트 오류:', error);
      ResponseHelper.serverError(res, '사용자 정보 업데이트 중 오류가 발생했습니다');
    }
  }

  // 사용자 삭제
  static async deleteUser(req, res) {
    try {
      const { id } = req.params;

      const user = await User.findByIdAndDelete(id);
      if (!user) {
        return ResponseHelper.notFound(res, '사용자를 찾을 수 없습니다');
      }

      ResponseHelper.success(res, null, '사용자가 삭제되었습니다');
    } catch (error) {
      console.error('사용자 삭제 오류:', error);
      ResponseHelper.serverError(res, '사용자 삭제 중 오류가 발생했습니다');
    }
  }
}

module.exports = UserController;