const crypto = require('crypto');

class CodeGenerator {
  // 6자리 대문자+숫자 초대 코드 생성
  static generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let result = '';
    
    for (let i = 0; i < 6; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    
    return result;
  }

  // 고유한 초대 코드 생성 (중복 방지)
  static async generateUniqueInviteCode(Room) {
    let code;
    let attempts = 0;
    const maxAttempts = 10;

    do {
      code = this.generateInviteCode();
      const existingRoom = await Room.findOne({ inviteCode: code });
      
      if (!existingRoom) {
        return code;
      }
      
      attempts++;
    } while (attempts < maxAttempts);

    // 최대 시도 횟수 초과 시 타임스탬프 추가
    return this.generateInviteCode() + Date.now().toString().slice(-2);
  }

  // 프로필 색상 목록
  static getProfileColors() {
    return [
      '#FF5722', '#E91E63', '#9C27B0', '#673AB7',
      '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4',
      '#009688', '#4CAF50', '#8BC34A', '#CDDC39',
      '#FFC107', '#FF9800', '#FF5722', '#795548'
    ];
  }

  // 랜덤 프로필 색상 선택
  static getRandomProfileColor() {
    const colors = this.getProfileColors();
    return colors[Math.floor(Math.random() * colors.length)];
  }
}

module.exports = CodeGenerator;