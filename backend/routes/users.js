const express = require('express');
const router = express.Router();

// 사용자 목록 조회
router.get('/', (req, res) => {
  res.json({ message: '사용자 목록', users: [] });
});

// 사용자 정보 조회
router.get('/me', (req, res) => {
  res.json({ message: '사용자 정보 조회 준비 중' });
});

// 프로필 업데이트
router.put('/profile', (req, res) => {
  res.json({ message: '프로필 업데이트 준비 중' });
});

module.exports = router;