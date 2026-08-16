import '../models/schedule.dart';

/// Keyed by [DateTime.weekday] (1 = Monday ... 7 = Sunday).
const Map<int, String> weekdayLabels = {1: '月', 2: '火', 3: '水', 4: '木', 5: '金', 6: '土', 7: '日'};

String formatTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

String scheduleSummary(Schedule schedule) {
  final timesStr = schedule.times
      .map((time) => formatTime(time.hour, time.minute))
      .join('・');

  if (schedule.repeatDays.isEmpty) return '未設定 $timesStr';

  final days = List<int>.from(schedule.repeatDays)..sort();
  final dayStr = days.length == 7
      ? '毎日'
      : days.map((d) => weekdayLabels[d]).join();
  final parts = [
    if (schedule.intervalWeeks > 1) '隔週',
    dayStr,
    timesStr,
  ];
  return parts.join(' ');
}

String formatJapaneseDate(DateTime date) => '${date.month}/${date.day}（${weekdayLabels[date.weekday]}）';
