import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class ActiveHoursScreen extends StatefulWidget {
  final Restaurant restaurant;

  const ActiveHoursScreen({super.key, required this.restaurant});

  @override
  State<ActiveHoursScreen> createState() => _ActiveHoursScreenState();
}

class _ActiveHoursScreenState extends State<ActiveHoursScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _hours = [];

  @override
  void initState() {
    super.initState();
    _loadHours();
  }

  Future<void> _loadHours() async {
    try {
      final data = await SupabaseService.fetchActiveHours(widget.restaurant.id);
      setState(() {
        _hours = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading hours: $e')),
        );
      }
    }
  }

  Future<void> _saveHours() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.updateBranchHours(widget.restaurant.id, _hours);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hours updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving hours: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getDayName(int day) {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[day];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Active Hours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface1,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveHours,
              child: const Text('Save', style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final dayData = _hours.firstWhere(
                  (h) => h['day_of_week'] == index,
                  orElse: () => {
                    'day_of_week': index,
                    'open_time': '09:00:00',
                    'close_time': '22:00:00',
                    'is_open': true,
                  },
                );

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getDayName(index),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          Switch(
                            value: dayData['is_open'],
                            activeColor: AppColors.lime,
                            onChanged: (val) {
                              setState(() {
                                final idx = _hours.indexWhere((h) => h['day_of_week'] == index);
                                if (idx != -1) {
                                  _hours[idx]['is_open'] = val;
                                } else {
                                  _hours.add({...dayData, 'is_open': val});
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      if (dayData['is_open']) ...[
                        const Divider(color: AppColors.border, height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _TimePickerField(
                                label: 'Open',
                                time: dayData['open_time'],
                                onChanged: (time) {
                                  setState(() {
                                    final idx = _hours.indexWhere((h) => h['day_of_week'] == index);
                                    if (idx != -1) {
                                      _hours[idx]['open_time'] = time;
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _TimePickerField(
                                label: 'Close',
                                time: dayData['close_time'],
                                onChanged: (time) {
                                  setState(() {
                                    final idx = _hours.indexWhere((h) => h['day_of_week'] == index);
                                    if (idx != -1) {
                                      _hours[idx]['close_time'] = time;
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  final String label;
  final String time;
  final ValueChanged<String> onChanged;

  const _TimePickerField({required this.label, required this.time, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final parts = time.split(':');
            final initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
            final picked = await showTimePicker(
              context: context,
              initialTime: initialTime,
            );
            if (picked != null) {
              onChanged('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00');
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time.substring(0, 5), style: const TextStyle(color: Colors.white)),
                const Icon(Icons.access_time, size: 16, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
