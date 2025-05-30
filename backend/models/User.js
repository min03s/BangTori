const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  socialId: {
    type: String,
    required: true,
    unique: true
  },
  provider: {
    type: String,
    enum: ['google', 'kakao', 'naver'],
    required: true
  },
  email: {
    type: String,
    required: true
  },
  nickname: {
    type: String,
    required: true
  },
  profileImage: {
    type: String,
    default: ''
  },
  currentRoom: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Room'
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('User', userSchema);