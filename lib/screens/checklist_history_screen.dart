import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_checklist.dart';
import '../providers/checklist_providers.dart';
import '../providers/todo_set_providers.dart';
import '../utils/date_key.dart';
import '../utils/schedule_format.dart';

/// Month-by-month calendar of one TodoSet's completion history: each day is
/// marked green if [DailyChecklist.isCompleted] for that date, based on
/// [checklistHistoryProvider].
class ChecklistHistoryScreen extends ConsumerStatefulWidget {
  const ChecklistHistoryScreen({super.key, required this.todoSetId});

  final String todoSetId;

  @override
  ConsumerState<ChecklistHistoryScreen> createState() => _ChecklistHistoryScreenState();
}

class _ChecklistHistoryScreenState extends ConsumerState<ChecklistHistoryScreen> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _visibleMonth.year == now.year && _visibleMonth.month == now.month;
  }

  void _changeMonth(int delta) {
    setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta));
  }

  void _showDayStatus(DateTime day, DailyChecklist? checklist) {
    final dateLabel = formatJapaneseDate(day);
    final message = checklist == null
        ? '$dateLabel: 記録なし'
        : '$dateLabel: ${checklist.isCompleted ? '完了' : '未完了'}（${checklist.checkedItemIds.length}件チェック）';

    final messenger = ScaffoldMessenger.of(context);
    // Drop any SnackBar still showing (and its queued successor) so a new
    // tap always shows its own message immediately, rather than waiting
    // for the previous one's duration to finish.
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final todoSet = ref.watch(todoSetProvider(widget.todoSetId));
    final historyAsync = ref.watch(checklistHistoryProvider(widget.todoSetId));

    return Scaffold(
      appBar: AppBar(title: Text(todoSet == null ? '完了履歴' : '${todoSet.name}の完了履歴')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('読み込みに失敗しました: $error')),
        data: (history) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: '前の月',
                      onPressed: () => _changeMonth(-1),
                    ),
                    Text(
                      '${_visibleMonth.year}年${_visibleMonth.month}月',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: '次の月',
                      onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  for (final weekday in [1, 2, 3, 4, 5, 6, 7])
                    Expanded(
                      child: Center(
                        child: Text(
                          weekdayLabels[weekday]!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(height: 1),
              Expanded(child: _MonthGrid(month: _visibleMonth, history: history, onTapDay: _showDayStatus)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: _Legend(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.history, required this.onTapDay});

  final DateTime month;
  final Map<String, DailyChecklist> history;
  final void Function(DateTime day, DailyChecklist? checklist) onTapDay;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday; // 1=Mon..7=Sun
    final leadingBlanks = firstWeekday - 1;
    final today = DateTime.now();
    final todayKeyValue = todayKey();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
      itemCount: leadingBlanks + daysInMonth,
      itemBuilder: (context, index) {
        if (index < leadingBlanks) return const SizedBox.shrink();

        final day = index - leadingBlanks + 1;
        final date = DateTime(month.year, month.month, day);
        final dateKey = dateKeyFor(date);
        final checklist = history[dateKey];
        final isToday = dateKey == todayKeyValue;
        final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));

        return _DayCell(
          day: day,
          isToday: isToday,
          isFuture: isFuture,
          isCompleted: checklist?.isCompleted ?? false,
          hasRecord: checklist != null,
          onTap: isFuture ? null : () => onTapDay(date, checklist),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isFuture,
    required this.isCompleted,
    required this.hasRecord,
    required this.onTap,
  });

  final int day;
  final bool isToday;
  final bool isFuture;
  final bool isCompleted;
  final bool hasRecord;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? Colors.green : (hasRecord ? colorScheme.surfaceContainerHighest : null),
            border: isToday ? Border.all(color: colorScheme.primary, width: 2) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              color: isCompleted
                  ? Colors.white
                  : isFuture
                      ? colorScheme.onSurface.withValues(alpha: 0.35)
                      : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(Colors.green),
        const SizedBox(width: 4),
        const Text('完了'),
        const SizedBox(width: 16),
        _legendDot(Theme.of(context).colorScheme.surfaceContainerHighest),
        const SizedBox(width: 4),
        const Text('記録あり（未完了）'),
      ],
    );
  }

  Widget _legendDot(Color color) {
    return Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }
}
