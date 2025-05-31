// backend/services/reservationScheduleService.js
const ReservationSchedule = require('../models/ReservationSchedule');
const ReservationCategory = require('../models/ReservationCategory');
const ReservationApproval = require('../models/ReservationApproval');
const Room = require('../models/Room');
const RoomMember = require('../models/RoomMember');
const { ReservationError } = require('../utils/errors');

const reservationScheduleService = {
  /**
     * 특정 방의 주간 예약 일정 조회 (승인된 예약, 방문객 제외)
     * 모든 예약 카테고리 포함하도록 수정
     */
    async getWeeklySchedules(roomId, weekStartDate, categoryId) {
      const query = {
        room: roomId,
        status: 'approved',
        specificDate: { $exists: false } // 방문객 예약 제외 (specificDate가 있는 것들)
      };

      // 주간 시작 날짜가 제공된 경우에만 필터 적용
      if (weekStartDate) {
        query.weekStartDate = new Date(weekStartDate);
      }

      // 특정 카테고리 필터 (선택사항)
      if (categoryId) {
        query.category = categoryId;
      }

      const schedules = await ReservationSchedule.find(query)
        .populate({
          path: 'category',
          select: 'name icon isVisitor',
          match: { isVisitor: false } // 방문객 카테고리 제외
        })
        .populate('reservedBy', 'nickname profileImageUrl')
        .sort({ dayOfWeek: 1, startHour: 1 });

      // populate 결과에서 category가 null인 항목 제거
      return schedules.filter(schedule => schedule.category);
    },

    /**
     * 현재 주의 예약 일정 조회 (승인된 예약, 방문객 제외)
     * 현재 주의 모든 예약 카테고리 반환
     */
    async getCurrentWeekSchedules(roomId, categoryId) {
      const today = new Date();
      const weekStartDate = ReservationSchedule.getWeekStartDate(today);

      return await this.getWeeklySchedules(roomId, weekStartDate, categoryId);
    },

    /**
       * 특정 카테고리의 현재 주 예약만 조회 (새로 추가)
       */
      async getCategoryWeeklySchedules(roomId, categoryId) {
        try {
          console.log('getCategoryWeeklySchedules 호출:', { roomId, categoryId });

          const today = new Date();
          const weekStartDate = ReservationSchedule.getWeekStartDate(today);

          console.log('현재 주 시작일:', weekStartDate);

          const query = {
            room: roomId,
            category: categoryId,
            weekStartDate: weekStartDate,
            status: 'approved',
            specificDate: { $exists: false }
          };

          console.log('검색 쿼리:', query);

          const schedules = await ReservationSchedule.find(query)
            .populate('category', 'name icon isVisitor')
            .populate('reservedBy', 'nickname profileImageUrl')
            .sort({ dayOfWeek: 1, startHour: 1 });

          console.log('조회된 스케줄 수:', schedules.length);
          console.log('조회된 스케줄:', schedules);

          return schedules;
        } catch (error) {
          console.error('getCategoryWeeklySchedules 오류:', error);
          throw error;
        }
      },

  /**
   * 방문객 예약 조회 (모든 상태 포함)
   */
  async getVisitorReservations(roomId) {
    const query = {
      room: roomId,
      specificDate: { $exists: true } // 방문객 예약은 specificDate 필드가 있음
    };

    const schedules = await ReservationSchedule.find(query)
      .populate({
        path: 'category',
        select: 'name icon isVisitor',
        match: { isVisitor: true }
      })
      .populate('reservedBy', 'nickname profileImageUrl')
      .sort({ specificDate: 1, startHour: 1 });

    const visitorReservations = schedules.filter(schedule => schedule.category);

    // 방 총 멤버 수 조회
    const totalMembers = await RoomMember.countDocuments({ roomId: roomId });

    // 각 예약의 승인 정보 추가
    const reservationsWithApproval = await Promise.all(
      visitorReservations.map(async (reservation) => {
        let approvalInfo = null;
        let approvalStatus = 'approved'; // 기본값

        if (reservation.status === 'pending') {
          approvalInfo = await ReservationApproval.findOne({
            reservation: reservation._id
          }).populate('approvedBy.user', 'nickname');

          if (approvalInfo) {
            const approvedCount = approvalInfo.approvedBy.length;
            const requiredApprovals = totalMembers - 1; // 예약자 제외

            if (approvedCount >= requiredApprovals) {
              approvalStatus = 'fully_approved';
            } else if (approvedCount > 0) {
              approvalStatus = 'partial_approved';
            } else {
              approvalStatus = 'pending';
            }
          } else {
            approvalStatus = 'pending';
          }
        }

        return {
          ...reservation.toObject(),
          approval: approvalInfo,
          approvalStatus,
          totalMembers,
          requiredApprovals: totalMembers - 1,
          currentApprovals: approvalInfo?.approvedBy.length || 0
        };
      })
    );

    return reservationsWithApproval;
  },

  /**
   * 승인 대기 중인 예약 목록 조회 (방문객만)
   */
  async getPendingReservations(roomId, userId) {
    const pendingReservations = await ReservationSchedule.find({
      room: roomId,
      status: 'pending'
    })
    .populate({
      path: 'category',
      select: 'name icon isVisitor',
      match: { isVisitor: true }
    })
    .populate('reservedBy', 'nickname profileImageUrl')
    .populate({
      path: 'room',
      select: 'name'
    })
    .sort({ createdAt: -1 });

    const visitorReservations = pendingReservations.filter(reservation => reservation.category);

    const reservationsWithApproval = await Promise.all(
      visitorReservations.map(async (reservation) => {
        const approval = await ReservationApproval.findOne({
          reservation: reservation._id
        }).populate('approvedBy.user', 'nickname');

        const hasUserApproved = approval?.approvedBy.some(
          app => app.user._id.toString() === userId.toString()
        ) || false;

        return {
          ...reservation.toObject(),
          approval: approval || null,
          hasUserApproved
        };
      })
    );

    return reservationsWithApproval;
  },

  /**
   * 예약 일정 생성 - 새로 추가된 함수
   */
  async createSchedule(scheduleData, userId) {
    console.log('예약 생성 요청 데이터:', scheduleData);
    console.log('사용자 ID:', userId);

    // 방 멤버인지 확인
    const room = await Room.findById(scheduleData.room);
    if (!room) {
      throw new ReservationError('방을 찾을 수 없습니다.', 404);
    }

    const roomMember = await RoomMember.findOne({
      roomId: room._id,
      userId: userId
    });

    if (!roomMember) {
      throw new ReservationError('방 멤버만 예약을 생성할 수 있습니다.', 403);
    }

    // 카테고리 정보 조회
    const category = await ReservationCategory.findById(scheduleData.category);
    if (!category) {
      throw new ReservationError('카테고리를 찾을 수 없습니다.', 404);
    }

    let newSchedule;

    if (category.isVisitor) {
      // 방문객 예약 처리
      if (!scheduleData.specificDate) {
        throw new ReservationError('방문객 예약은 특정 날짜가 필요합니다.', 400);
      }

      // 과거 날짜 예약 방지
      const reservationDate = new Date(scheduleData.specificDate);
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      if (reservationDate < today) {
        throw new ReservationError('과거 날짜는 예약할 수 없습니다.', 400);
      }

      // 방문객 예약 시간 겹침 확인
      const conflictingReservation = await ReservationSchedule.findOne({
        room: scheduleData.room,
        specificDate: reservationDate,
        status: 'approved', // 승인된 예약만 체크
        $or: [
          {
            startHour: { $lt: scheduleData.endHour },
            endHour: { $gt: scheduleData.startHour }
          }
        ]
      });

      if (conflictingReservation) {
        throw new ReservationError('해당 날짜 시간에 이미 예약이 있습니다.', 409);
      }

      newSchedule = new ReservationSchedule({
        room: scheduleData.room,
        category: scheduleData.category,
        reservedBy: userId,
        specificDate: reservationDate,
        startHour: scheduleData.startHour,
        endHour: scheduleData.endHour,
        status: 'pending' // 방문객은 항상 승인 필요
      });

    } else {
      // 일반 예약 처리
      if (scheduleData.dayOfWeek === undefined) {
        throw new ReservationError('일반 예약은 요일이 필요합니다.', 400);
      }

      const weekStartDate = ReservationSchedule.getWeekStartDate(new Date());

      // 시간 겹침 확인 (승인된 예약만 체크)
      const conflictingReservation = await ReservationSchedule.findOne({
        room: scheduleData.room,
        category: scheduleData.category,
        dayOfWeek: scheduleData.dayOfWeek,
        weekStartDate: weekStartDate,
        status: 'approved',
        $or: [
          {
            startHour: { $lt: scheduleData.endHour },
            endHour: { $gt: scheduleData.startHour }
          }
        ]
      });

      if (conflictingReservation) {
        throw new ReservationError('해당 시간에 이미 승인된 예약이 있습니다.', 409);
      }

      newSchedule = new ReservationSchedule({
        room: scheduleData.room,
        category: scheduleData.category,
        reservedBy: userId,
        dayOfWeek: scheduleData.dayOfWeek,
        startHour: scheduleData.startHour,
        endHour: scheduleData.endHour,
        weekStartDate: weekStartDate,
        isRecurring: scheduleData.isRecurring || false,
        status: 'approved' // 일반 카테고리는 즉시 승인
      });
    }

    const savedSchedule = await newSchedule.save();

    // 방문객 예약인 경우 승인 정보 생성
    if (category.isVisitor) {
      const totalMembers = await RoomMember.countDocuments({ roomId: room._id });

      await ReservationApproval.create({
        reservation: savedSchedule._id,
        totalMembersCount: totalMembers,
        approvedBy: []
      });
    }

    // 매주 반복 예약인 경우 다음 주 예약도 생성
    if (!category.isVisitor && scheduleData.isRecurring) {
      await this.createRecurringReservations(savedSchedule);
    }

    return savedSchedule;
  },

  /**
   * 매주 반복 예약 생성
   */
  async createRecurringReservations(originalSchedule) {
    // 최대 12주(3개월) 미리 생성
    const maxWeeks = 12;
    const createdReservations = [];

    for (let i = 1; i <= maxWeeks; i++) {
      const nextWeekStart = new Date(originalSchedule.weekStartDate);
      nextWeekStart.setDate(nextWeekStart.getDate() + (7 * i));

      // 이미 해당 주에 예약이 있는지 확인
      const existingReservation = await ReservationSchedule.findOne({
        room: originalSchedule.room,
        category: originalSchedule.category,
        reservedBy: originalSchedule.reservedBy,
        dayOfWeek: originalSchedule.dayOfWeek,
        weekStartDate: nextWeekStart,
        startHour: originalSchedule.startHour,
        endHour: originalSchedule.endHour
      });

      if (existingReservation) {
        continue; // 이미 예약이 있으면 스킵
      }

      // 시간 겹침 확인
      const conflictingReservation = await ReservationSchedule.findOne({
        room: originalSchedule.room,
        category: originalSchedule.category,
        dayOfWeek: originalSchedule.dayOfWeek,
        weekStartDate: nextWeekStart,
        status: 'approved',
        $or: [
          {
            startHour: { $lt: originalSchedule.endHour },
            endHour: { $gt: originalSchedule.startHour }
          }
        ]
      });

      if (conflictingReservation) {
        continue; // 겹치는 예약이 있으면 스킵
      }

      // 새로운 반복 예약 생성
      const recurringReservation = new ReservationSchedule({
        room: originalSchedule.room,
        category: originalSchedule.category,
        reservedBy: originalSchedule.reservedBy,
        dayOfWeek: originalSchedule.dayOfWeek,
        startHour: originalSchedule.startHour,
        endHour: originalSchedule.endHour,
        weekStartDate: nextWeekStart,
        isRecurring: true,
        status: 'approved'
      });

      const saved = await recurringReservation.save();
      createdReservations.push(saved);
    }

    return createdReservations;
  },

  /**
   * 예약 승인
   */
  async approveReservation(reservationId, userId) {
    const reservation = await ReservationSchedule.findById(reservationId)
      .populate('category');

    if (!reservation) {
      throw new ReservationError('예약을 찾을 수 없습니다.', 404);
    }

    // 방문객 예약만 승인 가능
    if (!reservation.category.isVisitor) {
      throw new ReservationError('방문객 예약만 승인할 수 있습니다.', 400);
    }

    // 방 멤버인지 확인
    const roomMember = await RoomMember.findOne({
      roomId: reservation.room,
      userId: userId
    });

    if (!roomMember) {
      throw new ReservationError('방 멤버만 승인할 수 있습니다.', 403);
    }

    // 예약자 본인은 승인할 수 없음
    if (reservation.reservedBy.toString() === userId.toString()) {
      throw new ReservationError('본인의 예약은 승인할 수 없습니다.', 400);
    }

    // 이미 승인된 예약인지 확인
    if (reservation.status === 'approved') {
      throw new ReservationError('이미 승인된 예약입니다.', 400);
    }

    let approval = await ReservationApproval.findOne({
      reservation: reservationId
    });

    if (!approval) {
      // 승인 정보가 없으면 생성
      const totalMembers = await RoomMember.countDocuments({ roomId: reservation.room });
      approval = await ReservationApproval.create({
        reservation: reservationId,
        totalMembersCount: totalMembers,
        approvedBy: []
      });
    }

    // 이미 승인했는지 확인
    const hasApproved = approval.approvedBy.some(
      app => app.user.toString() === userId.toString()
    );

    if (hasApproved) {
      throw new ReservationError('이미 승인한 예약입니다.', 400);
    }

    // 승인 추가
    approval.approvedBy.push({ user: userId });

    // 모든 멤버(예약자 제외)가 승인했는지 확인
    const requiredApprovals = approval.totalMembersCount - 1; // 예약자 제외
    const currentApprovals = approval.approvedBy.length;

    if (currentApprovals >= requiredApprovals) {
      // 모든 멤버가 승인했으면 최종 승인

      // 시간 겹침 재확인 (최종 승인 시점에서)
      const conflictingReservation = await ReservationSchedule.findOne({
        _id: { $ne: reservationId },
        room: reservation.room,
        specificDate: reservation.specificDate,
        status: 'approved',
        $or: [
          {
            startHour: { $lt: reservation.endHour },
            endHour: { $gt: reservation.startHour }
          }
        ]
      });

      if (conflictingReservation) {
        throw new ReservationError('승인 시점에 해당 시간에 이미 다른 예약이 있습니다.', 409);
      }

      // 예약 상태를 승인으로 변경
      reservation.status = 'approved';
      await reservation.save();

      approval.isFullyApproved = true;
    }

    await approval.save();

    return {
      reservation,
      approval,
      isFullyApproved: approval.isFullyApproved,
      currentApprovals,
      requiredApprovals,
      remainingApprovals: requiredApprovals - currentApprovals
    };
  },

  /**
   * 예약 삭제
   */
  async deleteSchedule(scheduleId, userId) {
    const schedule = await ReservationSchedule.findById(scheduleId)
      .populate('category');

    if (!schedule) {
      throw new ReservationError('예약을 찾을 수 없습니다.', 404);
    }

    // 예약자만 삭제 가능
    if (schedule.reservedBy.toString() !== userId.toString()) {
      throw new ReservationError('예약자만 삭제할 수 있습니다.', 403);
    }

    // 방문객 예약은 당일 이후만 삭제 가능, 일반 예약은 현재 주만 삭제 가능
    if (schedule.category.isVisitor) {
      const today = new Date();
      const reservationDate = new Date(schedule.specificDate);
      if (reservationDate < today) {
        throw new ReservationError('과거 날짜의 예약은 삭제할 수 없습니다.', 400);
      }
    } else {
      if (!schedule.isCurrentWeek()) {
        throw new ReservationError('현재 주의 예약만 삭제할 수 있습니다.', 400);
      }
    }

    // 매주 반복 예약인 경우 미래 예약들도 함께 삭제할지 확인
    if (schedule.isRecurring && !schedule.category.isVisitor) {
      // 현재 및 미래 반복 예약들 삭제
      await ReservationSchedule.deleteMany({
        room: schedule.room,
        category: schedule.category,
        reservedBy: schedule.reservedBy,
        dayOfWeek: schedule.dayOfWeek,
        startHour: schedule.startHour,
        endHour: schedule.endHour,
        weekStartDate: { $gte: schedule.weekStartDate },
        isRecurring: true
      });
    }

    // 승인 정보도 함께 삭제
    await ReservationApproval.deleteOne({ reservation: scheduleId });
    await schedule.deleteOne();
  },

  /**
   * 지난 주 예약들 자동 정리 (스케줄러에서 호출)
   */
  async cleanupOldReservations() {
    const today = new Date();
    const currentWeekStart = ReservationSchedule.getWeekStartDate(today);

    // 일반 예약: 지난 주 예약 삭제
    const oldWeeklyReservations = await ReservationSchedule.find({
      weekStartDate: { $lt: currentWeekStart },
      specificDate: { $exists: false }
    }, '_id');

    // 방문객 예약: 지난 날짜 예약 삭제
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(23, 59, 59, 999);

    const oldVisitorReservations = await ReservationSchedule.find({
      specificDate: { $lt: yesterday }
    }, '_id');

    const allOldReservationIds = [
      ...oldWeeklyReservations.map(r => r._id),
      ...oldVisitorReservations.map(r => r._id)
    ];

    // 승인 정보 먼저 삭제
    await ReservationApproval.deleteMany({
      reservation: { $in: allOldReservationIds }
    });

    // 예약 삭제
    await ReservationSchedule.deleteMany({
      _id: { $in: allOldReservationIds }
    });

    console.log(`정리된 지난 예약: ${allOldReservationIds.length}개`);
    return allOldReservationIds.length;
  },

  /**
   * 반복 예약 자동 생성 (스케줄러에서 호출)
   */
  async createNextWeekRecurringReservations() {
    const today = new Date();
    const currentWeekStart = ReservationSchedule.getWeekStartDate(today);
    const nextWeekStart = new Date(currentWeekStart);
    nextWeekStart.setDate(nextWeekStart.getDate() + 7);

    // 현재 주의 반복 예약들 조회
    const recurringReservations = await ReservationSchedule.find({
      weekStartDate: currentWeekStart,
      isRecurring: true,
      status: 'approved',
      specificDate: { $exists: false }
    });

    let createdCount = 0;

    for (const reservation of recurringReservations) {
      // 다음 주에 이미 예약이 있는지 확인
      const existingReservation = await ReservationSchedule.findOne({
        room: reservation.room,
        category: reservation.category,
        reservedBy: reservation.reservedBy,
        dayOfWeek: reservation.dayOfWeek,
        weekStartDate: nextWeekStart,
        startHour: reservation.startHour,
        endHour: reservation.endHour
      });

      if (existingReservation) {
        continue;
      }

      // 시간 겹침 확인
      const conflictingReservation = await ReservationSchedule.findOne({
        room: reservation.room,
        category: reservation.category,
        dayOfWeek: reservation.dayOfWeek,
        weekStartDate: nextWeekStart,
        status: 'approved',
        $or: [
          {
            startHour: { $lt: reservation.endHour },
            endHour: { $gt: reservation.startHour }
          }
        ]
      });

      if (conflictingReservation) {
        continue;
      }

      // 다음 주 예약 생성
      const nextWeekReservation = new ReservationSchedule({
        room: reservation.room,
        category: reservation.category,
        reservedBy: reservation.reservedBy,
        dayOfWeek: reservation.dayOfWeek,
        startHour: reservation.startHour,
        endHour: reservation.endHour,
        weekStartDate: nextWeekStart,
        isRecurring: true,
        status: 'approved'
      });

      await nextWeekReservation.save();
      createdCount++;
    }

    console.log(`생성된 다음 주 반복 예약: ${createdCount}개`);
    return createdCount;
  }
};

module.exports = reservationScheduleService;
