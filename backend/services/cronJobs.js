const cron = require('node-cron');
const Schedule = require('../models/Schedule');
const Notification = require('../models/Notification');
const NotificationService = require('./notificationService');

// 매일 자정에 완료된 일정 삭제
cron.schedule('0 0 * * *', async () => {
  try {
    console.log('완료된 일정 자동 삭제 시작...');
    
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(23, 59, 59, 999);

    // 어제 완료된 일정들 삭제
    const result = await Schedule.deleteMany({
      isCompleted: true,
      date: { $lte: yesterday }
    });

    console.log(`${result.deletedCount}개의 완료된 일정이 삭제되었습니다.`);

  } catch (error) {
    console.error('완료된 일정 삭제 오류:', error);
  }
});

// 30일 이상 된 알림 삭제
cron.schedule('0 2 * * *', async () => {
  try {
    console.log('오래된 알림 자동 삭제 시작...');
    
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const result = await Notification.deleteMany({
      createdAt: { $lte: thirtyDaysAgo }
    });

    console.log(`${result.deletedCount}개의 오래된 알림이 삭제되었습니다.`);

  } catch (error) {
    console.error('오래된 알림 삭제 오류:', error);
  }
});

// 일정 알림 (매 30분마다 체크)
cron.schedule('*/30 * * * *', async () => {
  try {
    const now = new Date();
    const thirtyMinutesLater = new Date(now.getTime() + 30 * 60 * 1000);

    // 30분 후 시작되는 일정들 조회
    const upcomingSchedules = await Schedule.find({
      date: {
        $gte: now,
        $lte: thirtyMinutesLater
      },
      isCompleted: false,
      reminderSent: { $ne: true }
    }).populate('room assignedTo');

    for (const schedule of upcomingSchedules) {
      if (schedule.assignedTo && schedule.room) {
        await NotificationService.sendScheduleReminder(
          schedule.room._id,
          schedule.assignedTo._id,
          {
            title: schedule.title,
            time: schedule.time,
            category: schedule.category
          }
        );

        // 알림 전송 표시
        schedule.reminderSent = true;
        await schedule.save();
      }
    }

    if (upcomingSchedules.length > 0) {
      console.log(`${upcomingSchedules.length}개의 일정 알림을 전송했습니다.`);
    }

  } catch (error) {
    console.error('일정 알림 전송 오류:', error);
  }
});

// 만료된 초대 코드 정리 (매시간)
cron.schedule('0 * * * *', async () => {
  try {
    const Room = require('../models/Room');
    const now = new Date();

    const result = await Room.updateMany(
      { 'inviteCode.expiresAt': { $lte: now } },
      { $unset: { inviteCode: 1 } }
    );

    if (result.modifiedCount > 0) {
      console.log(`${result.modifiedCount}개의 만료된 초대 코드를 정리했습니다.`);
    }

  } catch (error) {
    console.error('초대 코드 정리 오류:', error);
  }
});

console.log('크론 작업이 시작되었습니다.');