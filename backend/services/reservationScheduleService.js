// backend/services/reservationScheduleService.js
const ReservationSchedule = require('../models/ReservationSchedule');
const ReservationCategory = require('../models/ReservationCategory');
const ReservationApproval = require('../models/ReservationApproval');
const Room = require('../models/Room');
const RoomMember = require('../models/RoomMember');
const { ReservationError } = require('../utils/errors');
const notificationService = require('./notificationService');

const reservationScheduleService = {
  /**
   * 예약 데이터에 RoomMember 정보 추가하는 헬퍼 함수
   */
  async addMemberInfoToReservations(roomId, reservations) {
    return await Promise.all(
      reservations.map(async (reservation) => {
        const roomMember = await RoomMember.findOne({
          roomId: roomId,
          userId: reservation.reservedBy._id
        }).select('nickname profileImageUrl');

        return {
          ...reservation.toObject(),
          reservedBy: {
            _id: reservation.reservedBy._id,
            name: reservation.reservedBy.name,
            nickname: roomMember?.nickname || reservation.reservedBy.name,
            profileImageUrl: roomMember?.profileImageUrl || '/images/profile1.png'
          }
        };
      })
    );
  },

  /**
   * 특정 방의 주간 예약 일정 조회 (승인된 예약, 방문객 제외)
   */
  async getWeeklySchedules(roomId, weekStartDate, categoryId) {
    const query = {
      room: roomId,
      status: 'approved',
      specificDate: { $exists: false }
    };

    if (weekStartDate) {
      query.weekStartDate = new Date(weekStartDate);
    }

    if (categoryId) {
      query.category = categoryId;
    }

    const schedules = await ReservationSchedule.find(query)
      .populate({
        path: 'category',
        select: 'name icon isVisitor',
        match: { isVisitor: false }
      })
      .populate('reservedBy', 'name')
      .sort({ dayOfWeek: 1, startHour: 1 });

    const filteredSchedules = schedules.filter(schedule => schedule.category);
    return await this.addMemberInfoToReservations(roomId, filteredSchedules);
  },

  /**
   * 현재 주의 예약 일정 조회
   */
  async getCurrentWeekSchedules(roomId, categoryId) {
    const today = new Date();
    const weekStartDate = ReservationSchedule.getWeekStartDate(today);

    return await this.getWeeklySchedules(roomId, weekStartDate, categoryId);
  },

  /**
   * 특정 카테고리의 현재 주 예약만 조회
   */
  async getCategoryWeeklySchedules(roomId, categoryId) {
    try {
      console.log('getCategoryWeeklySchedules 호출:', { roomId, categoryId });

      const today = new Date();
      const weekStartDate = ReservationSchedule.getWeekStartDate(today);

      const query = {
        room: roomId,
        category: categoryId,
        weekStartDate: weekStartDate,
        status: 'approved',
        specificDate: { $exists: false }
      };

      const schedules = await ReservationSchedule.find(query)
        .populate('category', 'name icon isVisitor')
        .populate('reservedBy', 'name')
        .sort({ dayOfWeek: 1, startHour: 1 });

      return await this.addMemberInfoToReservations(roomId, schedules);
    } catch (error) {
      console.error('getCategoryWeeklySchedules 오류:', error);
      throw error;
    }
  },

  /**
     * 방문객 예약 조회 - 실시간 멤버 수 기반 승인 상태 계산 (수정됨)
     */
    async getVisitorReservations(roomId) {
      const query = {
        room: roomId,
        specificDate: { $exists: true }
      };

      const schedules = await ReservationSchedule.find(query)
        .populate({
          path: 'category',
          select: 'name icon isVisitor',
          match: { isVisitor: true }
        })
        .populate('reservedBy', 'name')
        .sort({ specificDate: 1, startHour: 1 });

      const visitorReservations = schedules.filter(schedule => schedule.category);
      const reservationsWithMemberInfo = await this.addMemberInfoToReservations(roomId, visitorReservations);

      // 실시간 멤버 수 조회
      const totalMembers = await RoomMember.countDocuments({ roomId: roomId });

      const reservationsWithApproval = await Promise.all(
        reservationsWithMemberInfo.map(async (reservation) => {
          let approvalInfo = null;
          let approvalStatus = 'approved';

          if (reservation.status === 'pending') {
            approvalInfo = await ReservationApproval.findOne({
              reservation: reservation._id
            }).populate({
              path: 'approvedBy.user',
              select: '_id'  // 기본적으로 _id만 가져옴
            });

            if (approvalInfo) {
              // 실시간 멤버 수로 승인 정보 업데이트
              approvalInfo.totalMembersCount = totalMembers;
              await approvalInfo.save();

              // 승인자들의 RoomMember 정보를 별도로 조회
              const approvedByWithMemberInfo = await Promise.all(
                approvalInfo.approvedBy.map(async (approval) => {
                  const roomMember = await RoomMember.findOne({
                    roomId: roomId,
                    userId: approval.user._id
                  }).select('nickname profileImageUrl');

                  return {
                    user: {
                      _id: approval.user._id,
                      nickname: roomMember?.nickname || '알 수 없음',
                      profileImageUrl: roomMember?.profileImageUrl || '/images/profile1.png'
                    },
                    approvedAt: approval.approvedAt
                  };
                })
              );

              // approvalInfo 객체에 업데이트된 정보 설정
              approvalInfo.approvedBy = approvedByWithMemberInfo;

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
            ...reservation,
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
     * 승인 대기 중인 예약 목록 조회 - 실시간 멤버 수 반영 (수정됨)
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
      .populate('reservedBy', 'name')
      .populate({
        path: 'room',
        select: 'name'
      })
      .sort({ createdAt: -1 });

      const visitorReservations = pendingReservations.filter(reservation => reservation.category);
      const reservationsWithMemberInfo = await this.addMemberInfoToReservations(roomId, visitorReservations);

      // 실시간 멤버 수 조회
      const totalMembers = await RoomMember.countDocuments({ roomId: roomId });

      const reservationsWithApproval = await Promise.all(
        reservationsWithMemberInfo.map(async (reservation) => {
          const approval = await ReservationApproval.findOne({
            reservation: reservation._id
          }).populate({
            path: 'approvedBy.user',
            select: '_id'  // 기본적으로 _id만 가져옴
          });

          // 승인 정보가 있으면 실시간 멤버 수로 업데이트
          if (approval) {
            approval.totalMembersCount = totalMembers;
            await approval.save();

            // 승인자들의 RoomMember 정보를 별도로 조회
            const approvedByWithMemberInfo = await Promise.all(
              approval.approvedBy.map(async (approvalItem) => {
                const roomMember = await RoomMember.findOne({
                  roomId: roomId,
                  userId: approvalItem.user._id
                }).select('nickname profileImageUrl');

                return {
                  user: {
                    _id: approvalItem.user._id,
                    nickname: roomMember?.nickname || '알 수 없음',
                    profileImageUrl: roomMember?.profileImageUrl || '/images/profile1.png'
                  },
                  approvedAt: approvalItem.approvedAt
                };
              })
            );

            // approval 객체에 업데이트된 정보 설정
            approval.approvedBy = approvedByWithMemberInfo;
          }

          const hasUserApproved = approval?.approvedBy.some(
            app => app.user._id.toString() === userId.toString()
          ) || false;

          return {
            ...reservation,
            approval: approval || null,
            hasUserApproved,
            totalMembers,
            requiredApprovals: totalMembers - 1,
            currentApprovals: approval?.approvedBy.length || 0
          };
        })
      );

      return reservationsWithApproval;
    },

  /**
   * 승인 대기 중인 예약 목록 조회 - 실시간 멤버 수 반영
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
    .populate('reservedBy', 'name')
    .populate({
      path: 'room',
      select: 'name'
    })
    .sort({ createdAt: -1 });

    const visitorReservations = pendingReservations.filter(reservation => reservation.category);
    const reservationsWithMemberInfo = await this.addMemberInfoToReservations(roomId, visitorReservations);

    // 실시간 멤버 수 조회
    const totalMembers = await RoomMember.countDocuments({ roomId: roomId });

    const reservationsWithApproval = await Promise.all(
      reservationsWithMemberInfo.map(async (reservation) => {
        const approval = await ReservationApproval.findOne({
          reservation: reservation._id
        }).populate('approvedBy.user', 'nickname');

        // 승인 정보가 있으면 실시간 멤버 수로 업데이트
        if (approval) {
          approval.totalMembersCount = totalMembers;
          await approval.save();
        }

        const hasUserApproved = approval?.approvedBy.some(
          app => app.user._id.toString() === userId.toString()
        ) || false;

        return {
          ...reservation,
          approval: approval || null,
          hasUserApproved,
          totalMembers,
          requiredApprovals: totalMembers - 1,
          currentApprovals: approval?.approvedBy.length || 0
        };
      })
    );

    return reservationsWithApproval;
  },

  /**
   * 예약 일정 생성
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

      const reservationDate = new Date(scheduleData.specificDate);
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      if (reservationDate < today) {
        throw new ReservationError('과거 날짜는 예약할 수 없습니다.', 400);
      }

      // 시간 겹침 확인
      const conflictingReservation = await ReservationSchedule.findOne({
        room: scheduleData.room,
        specificDate: reservationDate,
        status: 'approved',
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
        reservedBy: userId, // userId를 직접 저장
        specificDate: reservationDate,
        startHour: scheduleData.startHour,
        endHour: scheduleData.endHour,
        status: 'pending'
      });

    } else {
      // 일반 예약 처리
      if (scheduleData.dayOfWeek === undefined) {
        throw new ReservationError('일반 예약은 요일이 필요합니다.', 400);
      }

      const weekStartDate = ReservationSchedule.getWeekStartDate(new Date());

      // 시간 겹침 확인
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
        reservedBy: userId, // userId를 직접 저장
        dayOfWeek: scheduleData.dayOfWeek,
        startHour: scheduleData.startHour,
        endHour: scheduleData.endHour,
        weekStartDate: weekStartDate,
        isRecurring: scheduleData.isRecurring || false,
        status: 'approved'
      });
    }

    const savedSchedule = await newSchedule.save();

    // 방문객 예약인 경우 승인 정보 생성 (실시간 멤버 수 기반)
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

    try {
        const createdBy = await RoomMember.findOne({
          roomId: room._id,
          userId: userId
        });

        if (category.isVisitor) {
          // 방문객 예약 생성 시 방의 모든 멤버들에게 승인 요청 알림
          await notificationService.notifyRoomMembers({
            roomId: room._id,
            fromUserId: userId,
            type: 'visitor_request',
            title: '방문객 예약 승인 요청',
            message: `${createdBy?.nickname || '멤버'}님이 방문객 예약을 요청했습니다. 승인이 필요합니다.`,
            relatedData: {
              reservationId: savedSchedule._id,
              specificDate: savedSchedule.specificDate,
              startHour: savedSchedule.startHour,
              endHour: savedSchedule.endHour
            }
          });
        } else {
          // 일반 예약 생성 시 알림
          await notificationService.notifyRoomMembers({
            roomId: room._id,
            fromUserId: userId,
            type: 'reservation_created',
            title: '새로운 예약',
            message: `${createdBy?.nickname || '멤버'}님이 ${category.name} 예약을 등록했습니다.`,
            relatedData: {
              reservationId: savedSchedule._id,
              categoryName: category.name,
              dayOfWeek: savedSchedule.dayOfWeek,
              startHour: savedSchedule.startHour,
              endHour: savedSchedule.endHour,
              isRecurring: savedSchedule.isRecurring
            }
          });
        }
      } catch (notificationError) {
        console.error('예약 생성 알림 전송 실패:', notificationError);
      }

      return savedSchedule;
  },

  /**
   * 매주 반복 예약 생성
   */
  async createRecurringReservations(originalSchedule) {
    const maxWeeks = 12;
    const createdReservations = [];

    for (let i = 1; i <= maxWeeks; i++) {
      const nextWeekStart = new Date(originalSchedule.weekStartDate);
      nextWeekStart.setDate(nextWeekStart.getDate() + (7 * i));

      const existingReservation = await ReservationSchedule.findOne({
        room: originalSchedule.room,
        category: originalSchedule.category,
        reservedBy: originalSchedule.reservedBy,
        dayOfWeek: originalSchedule.dayOfWeek,
        weekStartDate: nextWeekStart,
        startHour: originalSchedule.startHour,
        endHour: originalSchedule.endHour
      });

      if (existingReservation) continue;

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

      if (conflictingReservation) continue;

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
     * 예약 승인 - 실시간 멤버 수 기반 승인 처리 (수정됨)
     */
    async approveReservation(reservationId, userId) {
      const reservation = await ReservationSchedule.findById(reservationId)
        .populate('category');

      if (!reservation) {
        throw new ReservationError('예약을 찾을 수 없습니다.', 404);
      }

      if (!reservation.category.isVisitor) {
        throw new ReservationError('방문객 예약만 승인할 수 있습니다.', 400);
      }

      const roomMember = await RoomMember.findOne({
        roomId: reservation.room,
        userId: userId
      });

      if (!roomMember) {
        throw new ReservationError('방 멤버만 승인할 수 있습니다.', 403);
      }

      // 예약자 본인은 승인할 수 없음 - userId로 직접 비교
      if (reservation.reservedBy.toString() === userId.toString()) {
        throw new ReservationError('본인의 예약은 승인할 수 없습니다.', 400);
      }

      if (reservation.status === 'approved') {
        throw new ReservationError('이미 승인된 예약입니다.', 400);
      }

      let approval = await ReservationApproval.findOne({
        reservation: reservationId
      });

      // 실시간 멤버 수 조회
      const totalMembers = await RoomMember.countDocuments({ roomId: reservation.room });

      if (!approval) {
        approval = await ReservationApproval.create({
          reservation: reservationId,
          totalMembersCount: totalMembers,
          approvedBy: []
        });
      } else {
        // 기존 승인 정보의 멤버 수 업데이트
        approval.totalMembersCount = totalMembers;
      }

      // 이미 승인했는지 확인
      const hasApproved = approval.approvedBy.some(
        app => app.user.toString() === userId.toString()
      );

      if (hasApproved) {
        throw new ReservationError('이미 승인한 예약입니다.', 400);
      }

      approval.approvedBy.push({ user: userId });

      const requiredApprovals = totalMembers - 1; // 예약자 제외
      const currentApprovals = approval.approvedBy.length;

      if (currentApprovals >= requiredApprovals) {
        // 시간 겹침 재확인
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
        remainingApprovals: requiredApprovals - currentApprovals,
        totalMembers
      };

    try {
        const approvedBy = await RoomMember.findOne({
          roomId: reservation.room,
          userId: userId
        });

        const reservedBy = await RoomMember.findOne({
          roomId: reservation.room,
          userId: reservation.reservedBy
        });

        if (result.isFullyApproved) {
          // 모든 승인이 완료된 경우 예약자에게 알림
          await notificationService.notifyUser({
            userId: reservation.reservedBy.toString(),
            fromUserId: userId,
            roomId: reservation.room,
            type: 'reservation_approved',
            title: '방문객 예약 최종 승인',
            message: '방문객 예약이 모든 멤버의 승인을 받아 최종 승인되었습니다.',
            relatedData: {
              reservationId: reservation._id,
              specificDate: reservation.specificDate,
              startHour: reservation.startHour,
              endHour: reservation.endHour
            }
          });

          // 다른 멤버들에게도 최종 승인 알림
          await notificationService.notifyRoomMembers({
            roomId: reservation.room,
            fromUserId: userId,
            type: 'reservation_approved',
            title: '방문객 예약 최종 승인',
            message: `${reservedBy?.nickname || '멤버'}님의 방문객 예약이 최종 승인되었습니다.`,
            relatedData: {
              reservationId: reservation._id,
              requesterNickname: reservedBy?.nickname,
              specificDate: reservation.specificDate,
              startHour: reservation.startHour,
              endHour: reservation.endHour
            },
            excludeUserIds: [reservation.reservedBy.toString()]
          });
        } else {
          // 부분 승인인 경우 예약자에게 진행 상황 알림
          await notificationService.notifyUser({
            userId: reservation.reservedBy.toString(),
            fromUserId: userId,
            roomId: reservation.room,
            type: 'reservation_approved',
            title: '방문객 예약 부분 승인',
            message: `${approvedBy?.nickname || '멤버'}님이 승인했습니다. ${result.remainingApprovals}명의 승인이 더 필요합니다.`,
            relatedData: {
              reservationId: reservation._id,
              currentApprovals: result.currentApprovals,
              requiredApprovals: result.requiredApprovals,
              remainingApprovals: result.remainingApprovals
            }
          });
        }
      } catch (notificationError) {
        console.error('예약 승인 알림 전송 실패:', notificationError);
      }

      return result;
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

    // 예약자 확인 - userId로 직접 비교
    if (schedule.reservedBy.toString() !== userId.toString()) {
      throw new ReservationError('예약자만 삭제할 수 있습니다.', 403);
    }

    // 시간 제한 확인
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

    // 매주 반복 예약인 경우 미래 예약들도 함께 삭제
    if (schedule.isRecurring && !schedule.category.isVisitor) {
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