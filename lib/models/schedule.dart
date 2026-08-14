import 'package:hive/hive.dart';

part 'schedule.g.dart';

/// Days of week use Dart's [DateTime.weekday] convention: 1 = Monday ... 7 = Sunday.
@HiveType(typeId: 1)
class Schedule extends HiveObject {
  Schedule({
    required this.hour,
    required this.minute,
    required this.repeatDays,
  });

  factory Schedule.everyDay({required int hour, required int minute}) {
    return Schedule(hour: hour, minute: minute, repeatDays: [1, 2, 3, 4, 5, 6, 7]);
  }

  @HiveField(0)
  int hour;

  @HiveField(1)
  int minute;

  @HiveField(2)
  List<int> repeatDays;

  Schedule copyWith({int? hour, int? minute, List<int>? repeatDays}) {
    return Schedule(
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDays: repeatDays ?? List<int>.from(this.repeatDays),
    );
  }
}
