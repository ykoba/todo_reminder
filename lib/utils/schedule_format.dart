import '../models/schedule.dart';

/// Keyed by [DateTime.weekday] (1 = Monday ... 7 = Sunday).
const Map<int, String> weekdayLabels = {1: '月', 2: '火', 3: '水', 4: '木', 5: '金', 6: '土', 7: '日'};

String formatTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

String scheduleSummary(Schedule schedule) {
  final timeStr = formatTime(schedule.hour, schedule.minute);
  if (schedule.repeatDays.length == 7) return '毎日 $timeStr';
  if (schedule.repeatDays.isEmpty) return '未設定 $timeStr';

  final days = List<int>.from(schedule.repeatDays)..sort();
  final dayStr = days.map((d) => weekdayLabels[d]).join('');
  return '$dayStr $timeStr';
}

String formatJapaneseDate(DateTime date) => '${date.month}/${date.day}（${weekdayLabels[date.weekday]}）';
