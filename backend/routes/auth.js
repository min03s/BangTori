const express = require('express');
const router = express.Router();

// 기본 인증 라우트
router.get('/test', (req, res) => {
  res.json({ message: '인증 라우트 테스트 성공' });
});

// Google 로그인 (임시)
router.get('/google', (req, res) => {
  res.json({ message: 'Google 로그인 준비 중' });
});

// 카카오 로그인 (임시)
router.get('/kakao', (req, res) => {
  res.json({ message: '카카오 로그인 준비 중' });
});

// 네이버 로그인 (임시)
router.get('/naver', (req, res) => {
  res.json({ message: '네이버 로그인 준비 중' });
});

module.exports = router;