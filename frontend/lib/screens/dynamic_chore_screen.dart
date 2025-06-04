import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';
import '../utils/dialog_utils.dart';

class DynamicChoreScreen extends StatefulWidget {
  final Map<String, dynamic> category;

  const DynamicChoreScreen({
    super.key,
    required this.category,
  });

  @override
  State<DynamicChoreScreen> createState() => _DynamicChoreScreenState();
}

class _DynamicChoreScreenState extends State<DynamicChoreScreen> {
  DateTime selectedDate = DateTime.now();
  String? selectedPersonId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.loadRoomMembers();
    await appState.loadChoreSchedules(); // 전체 일정 로드
  }

  Future<void> _addDuty() async {
    if (selectedPersonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('담당자를 선택해주세요.')),
      );
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);

    try {
      // selectedPersonId를 그대로 전달 (이미 올바른 사용자 ID)
      await appState.createChoreSchedule(
        categoryId: widget.category['_id'],
        assignedTo: selectedPersonId!,
        date: selectedDate,
      );

      // 성공 후 알림 개수 업데이트
      await appState.loadUnreadNotificationCount();

      setState(() {
        selectedPersonId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.category['name']} 일정이 등록되었습니다.')),
      );

      // 데이터 새로고침
      await _loadData();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정 등록 실패: $e')),
      );
    }
  }

  Future<void> _deleteDuty(Map<String, dynamic> schedule) async {
    final shouldDelete = await DialogUtils.showDeleteConfirmDialog(
      context,
      title: '일정 삭제',
      content: '${widget.category['name']} 일정을 삭제하시겠습니까?',
    );

    if (shouldDelete) {
      final appState = Provider.of<AppState>(context, listen: false);
      try {
        await appState.deleteChoreSchedule(schedule['_id']);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정이 삭제되었습니다.')),
        );
        await _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('일정 삭제 실패: $e')),
        );
      }
    }
  }

  // 완료/완료 해제 토글 함수
  Future<void> _toggleCompleteDuty(Map<String, dynamic> schedule) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final isCompleted = schedule['isCompleted'] ?? false;

    try {
      if (isCompleted) {
        await appState.uncompleteChoreSchedule(schedule['_id']);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정 완료가 해제되었습니다.')),
        );
      } else {
        await appState.completeChoreSchedule(schedule['_id']);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정이 완료되었습니다.')),
        );
      }

      // 성공 후 알림 개수 업데이트
      await appState.loadUnreadNotificationCount();

      await _loadData();
    } catch (e) {
      final action = isCompleted ? '완료 해제' : '완료 처리';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정 $action 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.category['name']} 당번')),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          // 해당 카테고리 일정만 필터링 - 안전한 비교
          final categorySchedules = appState.choreSchedules.where((schedule) {
            // null 체크 먼저 수행
            if (schedule['category'] == null) return false;

            // 카테고리 ID 비교 - 둘 다 String으로 변환하여 비교
            final scheduleCategory = schedule['category'];
            if (scheduleCategory is Map<String, dynamic>) {
              final scheduleCategoryId = scheduleCategory['_id']?.toString();
              final targetCategoryId = widget.category['_id']?.toString();
              return scheduleCategoryId == targetCategoryId;
            }
            return false;
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 등록된 일정 리스트
                Expanded(
                  child: ListView.builder(
                    itemCount: categorySchedules.length,
                    itemBuilder: (context, index) {
                      final schedule = categorySchedules[index];

                      // 안전한 데이터 접근
                      final dateStr = schedule['date']?.toString();
                      if (dateStr == null) return const SizedBox.shrink();

                      final date = DateTime.tryParse(dateStr);
                      if (date == null) return const SizedBox.shrink();

                      final assignedPerson = schedule['assignedTo'];
                      if (assignedPerson == null) return const SizedBox.shrink();

                      final isCompleted = schedule['isCompleted'] ?? false;
                      final nickname = assignedPerson['nickname'] ?? '알 수 없음';

                      return Card(
                        child: ListTile(
                          title: Text(
                            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} - $nickname",
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 완료/완료 해제 토글 버튼 (수정됨)
                              IconButton(
                                icon: Icon(
                                  isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                                  color: isCompleted ? Colors.green : Colors.grey,
                                ),
                                onPressed: () => _toggleCompleteDuty(schedule),
                                tooltip: isCompleted ? '완료 해제' : '완료 처리',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => _deleteDuty(schedule),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),

                // 날짜 선택
                Row(
                  children: [
                    const Text("날짜 선택: "),
                    TextButton(
                      onPressed: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Text("${selectedDate.toLocal()}".split(' ')[0]),
                    ),
                  ],
                ),

                // 담당자 선택
                const Text("담당자 선택:"),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  children: appState.roomMembers.map((member) {
                    // userId를 사용하여 선택 (백엔드에서 userId로 RoomMember를 찾음)
                    final userId = member['userId']?.toString();
                    final nickname = member['nickname']?.toString() ?? '알 수 없음';
                    final isSelected = selectedPersonId == userId;

                    return ChoiceChip(
                      label: Text(nickname),
                      selected: isSelected,
                      onSelected: userId != null ? (_) {
                        setState(() {
                          selectedPersonId = userId; // userId 사용
                        });
                      } : null,
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFA2E55),
                    ),
                    onPressed: appState.isLoading ? null : _addDuty,
                    child: appState.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('등록하기', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}