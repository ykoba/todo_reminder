import 'package:intl/intl.dart';

final DateFormat _dateKeyFormat = DateFormat('yyyy-MM-dd');

/// Local-calendar-day identifier used to key a [DailyChecklist] to a date,
/// independent of time-of-day or timezone shifts during the day.
String dateKeyFor(DateTime date) => _dateKeyFormat.format(date);

String todayKey() => dateKeyFor(DateTime.now());
