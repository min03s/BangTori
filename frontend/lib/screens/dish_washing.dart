import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_state.dart';

class dishwashing extends StatefulWidget {
  const dishwashing({super.key});

  @override
  State<dishwashing> createState() => _DishwashingScreenState();
}

class _DishwashingScreenState extends State<dishwashing> {
  DateTime selectedDate = DateTime.now();
  String? selectedPersonId;
  String? dishCategoryId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.loadRoomMembers();
    await appState.loadChoreSchedules();

    // 설거지 카테고리 찾기
    final categories = appState.choreCategories;
    final dishCategory = categories.firstWhere(
          (cat) => cat['name'] == '설거지',
      orElse: () => categories.isNotEmpty ? categories.first : {},
    );

    if (dishCategory.isNotEmpty) {
      dishCategoryId = dishCategory['_id'];
    }
  }

  Future<void> _addDuty() async {
    if (selectedPersonId == null || dishCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('담당자를 선택해주세요.')),
      );
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);

    try {
      await appState.createChoreSchedule(
        categoryId: dishCategoryId!,
        assignedTo: selectedPersonId!,
        date: selectedDate,
      );

      setState(() {
        selectedPersonId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설거지 일정이 등록되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정 등록 실패: $e')),
      );
    }
  }

  Future<void> _deleteDuty(Map<String, dynamic> schedule) async {
    final appState = Provider.of<AppState>(context, listen: false);

    try {
      await appState.deleteChoreSchedule(schedule['_id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정이 삭제되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정 삭제 실패: $e')),
      );
    }
  }

  Future<void> _completeDuty(Map<String, dynamic> schedule) async {
    final appState = Provider.of<AppState>(context, listen: false);

    try {
      await appState.completeChoreSchedule(schedule['_id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정이 완료되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정 완료 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설거지 당번')),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          // 설거지 카테고리 일정만 필터링
          final dishSchedules = appState.choreSchedules
              .where((schedule) =>
          schedule['category'] != null &&
              schedule['category']['name'] == '설거지')
              .toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 등록된 일정 리스트
                Expanded(
                  child: ListView.builder(
                    itemCount: dishSchedules.length,
                    itemBuilder: (context, index) {
                      final schedule = dishSchedules[index];
                      final date = DateTime.parse(schedule['date']);
                      final assignedPerson = schedule['assignedTo'];
                      final isCompleted = schedule['isCompleted'] ?? false;

                      return Card(
                        child: ListTile(
                          title: Text(
                            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} - ${assignedPerson['nickname']}",
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                                  color: isCompleted ? Colors.green : Colors.grey,
                                ),
                                onPressed: isCompleted ? null : () => _completeDuty(schedule),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
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
                    final isSelected = selectedPersonId == member['userId'];
                    return ChoiceChip(
                      label: Text(member['nickname']),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          selectedPersonId = member['userId'];
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
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