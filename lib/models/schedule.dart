import 'package:hive/hive.dart';

part 'schedule.g.dart';

/// A single reminder time within a [Schedule]. Its own Hive type so a
/// Schedule can hold more than one time per day.
@HiveType(typeId: 4)
class ScheduleTime extends HiveObject {
  ScheduleTime({required this.hour, required this.minute});

  @HiveField(0)
  int hour;

  @HiveField(1)
  int minute;
}

/// Days of week use Dart's [DateTime.weekday] convention: 1 = Monday ... 7 = Sunday.
@HiveType(typeId: 1)
class Schedule extends HiveObject {
  Schedule({
    required this.times,
    required this.repeatDays,
    this.intervalWeeks = 1,
    DateTime? anchorDate,
  }) : anchorDateMillis =
           (anchorDate ?? DateTime.now()).millisecondsSinceEpoch;

  factory Schedule.everyDay({required int hour, required int minute}) {
    return Schedule(
      times: [ScheduleTime(hour: hour, minute: minute)],
      repeatDays: const [1, 2, 3, 4, 5, 6, 7],
    );
  }

  @HiveField(0)
  List<ScheduleTime> times;

  @HiveField(1)
  List<int> repeatDays;

  /// 1 = 毎週, 2 = 隔週. The edit screen only exposes those two choices, but
  /// the scheduling math below works for any positive interval.
  @HiveField(2, defaultValue: 1)
  int intervalWeeks;

  /// Backing storage for [anchorDate]. Stored as epoch milliseconds because
  /// a Hive field's `defaultValue` must be a compile-time constant, which a
  /// `DateTime` can't be (its constructor isn't `const`).
  @HiveField(3, defaultValue: 0)
  int anchorDateMillis;

  /// The Monday of the first "on" week when [intervalWeeks] > 1 — see
  /// [isActiveOnWeekOf]. Unused (and irrelevant) when [intervalWeeks] is 1.
  DateTime get anchorDate => DateTime.fromMillisecondsSinceEpoch(anchorDateMillis);
  set anchorDate(DateTime value) => anchorDateMillis = value.millisecondsSinceEpoch;

  Schedule copyWith({
    List<ScheduleTime>? times,
    List<int>? repeatDays,
    int? intervalWeeks,
    DateTime? anchorDate,
  }) {
    return Schedule(
      times: times ?? List<ScheduleTime>.from(this.times),
      repeatDays: repeatDays ?? List<int>.from(this.repeatDays),
      intervalWeeks: intervalWeeks ?? this.intervalWeeks,
      anchorDate: anchorDate ?? this.anchorDate,
    );
  }

  /// Whether the calendar week (Monday-start) containing [date] is one where
  /// this schedule fires. Always true when [intervalWeeks] is 1 ("毎週").
  bool isActiveOnWeekOf(DateTime date) {
    if (intervalWeeks <= 1) return true;
    final weeksBetween =
        _mondayOf(date).difference(_mondayOf(anchorDate)).inDays ~/ 7;
    final mod = weeksBetween % intervalWeeks;
    return (mod + intervalWeeks) % intervalWeeks == 0;
  }

  static DateTime _mondayOf(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
  }
}
