const express = require('express');
const jwt = require('jsonwebtoken');
const { MongoClient } = require('mongodb');
const multer = require('multer');
const cors = require('cors');
const { OAuth2Client } = require('google-auth-library');
const path = require('path');
const fs = require('fs');

const app = express();

// Google OAuth 클라이언트
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';

// MongoDB 연결
const mongoUrl = 'mongodb://localhost:27017/bangtori';
let db;

MongoClient.connect(mongoUrl).then(mongoClient => {
  console.log('MongoDB 연결 성공');
  db = mongoClient.db();
});

// 업로드 폴더 생성
const uploadDir = 'uploads';
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir);
}

// 미들웨어
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static('uploads')); // 이미지 정적 서빙

// 파일 업로드 설정 (로컬 저장)
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${Date.now()}_${Math.random().toString(36).substr(2, 9)}${ext}`);
  }
});
const upload = multer({ storage });

// JWT 토큰 검증 미들웨어
const verifyToken = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) {
    return res.status(401).json({ error: '토큰이 필요합니다' });
  }
  
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    res.status(401).json({ error: '유효하지 않은 토큰' });
  }
};

// Google 로그인
app.post('/api/login', async (req, res) => {
  try {
    const { idToken } = req.body;
    
    // Google ID 토큰 검증
    const ticket = await client.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    
    const payload = ticket.getPayload();
    const { sub: googleId, email, name, picture } = payload;
    
    // JWT 토큰 생성
    const token = jwt.sign(
      { googleId, email, name },
      JWT_SECRET,
      { expiresIn: '7d' }
    );
    
    // 사용자 정보 DB에 저장 (처음 로그인시)
    await db.collection('users').updateOne(
      { googleId },
      { 
        $set: { 
          email, 
          googleName: name,
          googlePicture: picture,
          lastLogin: new Date() 
        } 
      },
      { upsert: true }
    );
    
    res.json({ token, user: { googleId, email, name } });
  } catch (error) {
    console.error(error);
    res.status(401).json({ error: 'Google 로그인 실패' });
  }
});

// 사용자 프로필 저장/업데이트
app.post('/api/profile', verifyToken, upload.single('profileImage'), async (req, res) => {
  try {
    const { name } = req.body;
    const { googleId } = req.user;
    
    let profileImageUrl = null;
    if (req.file) {
      profileImageUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
    }
    
    const updateData = {
      name,
      updatedAt: new Date()
    };
    
    if (profileImageUrl) {
      updateData.profileImageUrl = profileImageUrl;
    }
    
    await db.collection('users').updateOne(
      { googleId },
      { $set: updateData }
    );
    
    res.json({ message: '프로필이 저장되었습니다', profileImageUrl });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: '프로필 저장 실패' });
  }
});

// 사용자 프로필 조회
app.get('/api/profile', verifyToken, async (req, res) => {
  try {
    const { googleId } = req.user;
    const profile = await db.collection('users').findOne({ googleId });
    
    if (!profile) {
      return res.status(404).json({ error: '프로필을 찾을 수 없습니다' });
    }
    
    res.json(profile);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: '프로필 조회 실패' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`서버가 포트 ${PORT}에서 실행 중입니다`);
});