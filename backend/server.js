const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');
const passport = require('passport');
const http = require('http');
const socketIo = require('socket.io');

// 환경변수 로드
dotenv.config();

// Express 앱 생성
const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// 미들웨어
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(passport.initialize());

// 데이터베이스 연결
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/bangtori', {
  useNewUrlParser: true,
  useUnifiedTopology: true
})
.then(() => console.log('MongoDB 연결 성공'))
.catch(err => console.error('MongoDB 연결 실패:', err));

// 기본 라우트
app.get('/', (req, res) => {
  res.json({ message: '방토리 API 서버가 실행 중입니다.' });
});

// 헬스 체크
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// 라우트 (파일이 존재할 때만 로드)
try {
  const authRoutes = require('./routes/auth');
  app.use('/api/auth', authRoutes);
} catch (error) {
  console.log('auth 라우트 파일이 없습니다. 기본 인증 라우트를 사용합니다.');
  
  // 기본 인증 라우트
  app.get('/api/auth/test', (req, res) => {
    res.json({ message: '인증 테스트 성공' });
  });
}

try {
  const userRoutes = require('./routes/users');
  app.use('/api/users', userRoutes);
} catch (error) {
  console.log('users 라우트 파일이 없습니다.');
}

try {
  const roomRoutes = require('./routes/rooms');
  app.use('/api/rooms', roomRoutes);
} catch (error) {
  console.log('rooms 라우트 파일이 없습니다.');
}

// 에러 핸들링 미들웨어
app.use((error, req, res, next) => {
  console.error('서버 오류:', error);
  res.status(500).json({ 
    message: '서버 내부 오류가 발생했습니다.',
    error: process.env.NODE_ENV === 'development' ? error.message : undefined
  });
});

// 404 핸들러
app.use('*', (req, res) => {
  res.status(404).json({ message: '요청한 리소스를 찾을 수 없습니다.' });
});

// Socket.IO 기본 설정
io.on('connection', (socket) => {
  console.log('사용자가 연결되었습니다:', socket.id);
  
  socket.on('disconnect', () => {
    console.log('사용자가 연결을 해제했습니다:', socket.id);
  });
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`서버가 포트 ${PORT}에서 실행 중입니다.`);
  console.log(`http://localhost:${PORT} 에서 접속 가능합니다.`);
});