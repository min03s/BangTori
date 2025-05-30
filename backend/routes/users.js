const express = require('express');
const router = express.Router();
const UserController = require('../controllers/userController');
const { userValidation } = require('../middleware/validation');

// 사용자 생성
router.post('/', userValidation.create, UserController.createUser);

// 사용자 조회
router.get('/:id', UserController.getUser);

// 사용자 정보 업데이트
router.put('/:id', userValidation.update, UserController.updateUser);

// 사용자 삭제
router.delete('/:id', UserController.deleteUser);

module.exports = router;