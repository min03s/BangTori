const express = require('express');
const router = express.Router();

// 방 목록 조회
router.get('/', (req, res) => {
  res.json({ message: '방 목록', rooms: [] });
});

// 방 생성
router.post('/', (req, res) => {
  res.json({ message: '방 생성 준비 중' });
});

// 방 참여
router.post('/join', (req, res) => {
  res.json({ message: '방 참여 준비 중' });
});

module.exports = router;