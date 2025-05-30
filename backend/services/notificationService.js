const admin = require('firebase-admin');
const Notification = require('../models/Notification');
const User = require('../models/User');

class NotificationService {
  static async sendNotification(roomId, senderId, type, message, data = {}) {
    try {
      // 알림을 받을 사용자들 조회 (발신자 제외)
      const recipients = await User.find({
        currentRoom: roomId,
        _id: { $ne: senderId },
        'notifications.push': true
      });

      if (recipients.length === 0) return;

      // 데이터베이스에 알림 저장
      const notifications = recipients.map(recipient => ({
        room: roomId,
        recipient: recipient._id,
        sender: senderId,
        type,
        message,
        data,
        isRead: false
      }));

      await Notification.insertMany(notifications);

      // FCM 푸시 알림 전송
      const pushTokens = recipients
        .filter(user => user.notifications.token)
        .map(user => user.notifications.token);

      if (pushTokens.length > 0) {
        await this.sendPushNotification(pushTokens, {
          title: '방토리',
          body: message,
          data: {
            type,
            roomId: roomId.toString(),
            ...data
          }
        });
      }

    } catch (error) {
      console.error('알림 전송 오류:', error);
    }
  }

  static async sendPushNotification(tokens, payload) {
    try {
      const message = {
        notification: {
          title: payload.title,
          body: payload.body
        },
        data: payload.data || {},
        tokens
      };

      const response = await admin.messaging().sendMulticast(message);
      console.log(`푸시 알림 전송 완료: ${response.successCount}/${tokens.length}`);
      
      if (response.failureCount > 0) {
        console.log('푸시 알림 실패:', response.responses.filter(r => !r.success));
      }

    } catch (error) {
      console.error('FCM 푸시 알림 오류:', error);
    }
  }

  // 방문객 예약 확인 알림
  static async sendVisitorConfirmation(roomId, senderId, visitorInfo) {
    const message = `${visitorInfo.date} ${visitorInfo.time}에 방문객이 예정되어 있습니다. 확인해주세요.`;
    
    await this.sendNotification(
      roomId,
      senderId,
      'visitor_confirmation',
      message,
      { visitorInfo, requireConfirmation: true }
    );
  }

  // 일정 완료 알림
  static async sendScheduleCompleted(roomId, userId, scheduleInfo) {
    const user = await User.findById(userId);
    const message = `${user.nickname}님이 "${scheduleInfo.title}" 일정을 완료했습니다.`;
    
    await this.sendNotification(
      roomId,
      userId,
      'schedule_completed',
      message,
      { scheduleInfo }
    );
  }

  // 일정 알림 (30분 전)
  static async sendScheduleReminder(roomId, userId, scheduleInfo) {
    const user = await User.findById(userId);
    const message = `30분 후 "${scheduleInfo.title}" 일정이 시작됩니다.`;
    
    // 담당자에게만 알림
    const notification = new Notification({
      room: roomId,
      recipient: userId,
      type: 'schedule_reminder',
      message,
      data: { scheduleInfo }
    });

    await notification.save();

    // 개별 푸시 알림
    if (user.notifications.push && user.notifications.token) {
      await this.sendPushNotification([user.notifications.token], {
        title: '방토리 - 일정 알림',
        body: message,
        data: { type: 'schedule_reminder' }
      });
    }
  }
}

module.exports = NotificationService;