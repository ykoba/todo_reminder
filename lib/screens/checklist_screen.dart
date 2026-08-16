import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_checklist.dart';
import '../models/todo_set.dart';
import '../providers/checklist_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/todo_set_providers.dart';
import '../utils/date_key.dart';
import '../utils/schedule_format.dart';
import 'checklist_history_screen.dart';

/// Opened either from a notification tap or from the TodoSet list. Shows
/// today's checklist for one TodoSet; checking items saves immediately.
/// Checking every item automatically marks the day completed; a "完了"
/// button also lets the user mark it done with items left unchecked.
/// Unchecking any item while already completed automatically un-completes
/// it — "done" shouldn't be able to silently drift out of sync with what's
/// actually checked. "完了を取り消す" goes further: it clears the completed
/// state *and* every item's checked state, so the day starts fresh rather
/// than being left "completed-looking" with checks still in place.
class ChecklistScreen extends ConsumerStatefulWidget {
  const ChecklistScreen({super.key, required this.todoSetId});

  final String todoSetId;

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  late final String _dateKey;

  @override
  void initState() {
    super.initState();
    _dateKey = todayKey();
    final todoSet = ref
        .read(todoSetRepositoryProvider)
        .getById(widget.todoSetId);
    if (todoSet != null) {
      ref.read(checklistRepositoryProvider).getOrCreate(todoSet, _dateKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todoSet = ref.watch(todoSetProvider(widget.todoSetId));
    if (todoSet == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final checklistAsync = ref.watch(
      dailyChecklistProvider(
        ChecklistKey(todoSetId: widget.todoSetId, dateKey: _dateKey),
      ),
    );

    return checklistAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('エラー: $error'))),
      data: (checklist) {
        if (checklist == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _ChecklistBody(todoSet: todoSet, checklist: checklist);
      },
    );
  }
}

class _ChecklistBody extends ConsumerStatefulWidget {
  const _ChecklistBody({required this.todoSet, required this.checklist});

  final TodoSet todoSet;
  final DailyChecklist checklist;

  @override
  ConsumerState<_ChecklistBody> createState() => _ChecklistBodyState();
}

class _ChecklistBodyState extends ConsumerState<_ChecklistBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _celebrationController;
  late final List<_ConfettiParticle> _confetti;
  late bool _wasCompleted;

  @override
  void initState() {
    super.initState();
    _wasCompleted = widget.checklist.isCompleted;
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _confetti = List.generate(18, (_) => _ConfettiParticle.random());
  }

  @override
  void didUpdateWidget(covariant _ChecklistBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isCompletedNow = widget.checklist.isCompleted;
    if (!_wasCompleted && isCompletedNow) {
      // Newly completed (via checking the last item, "すべてチェック", or
      // "完了する") — celebrate the moment rather than just silently
      // flipping a flag.
      HapticFeedback.mediumImpact();
      _celebrationController.forward(from: 0);
    }
    _wasCompleted = isCompletedNow;
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todoSet = widget.todoSet;
    final checklist = widget.checklist;
    final items = todoSet.sortedItems;
    final checkedCount = items
        .where((item) => checklist.isChecked(item.id))
        .length;
    final repo = ref.read(checklistRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(todoSet.name),
            Text(
              formatJapaneseDate(DateTime.now()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'すべてチェック',
            onPressed: items.isEmpty
                ? null
                : () async {
                    await repo.setAllChecked(
                      checklist,
                      items.map((item) => item.id).toList(),
                      true,
                    );
                    await repo.setCompleted(checklist, true);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: '完了履歴',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChecklistHistoryScreen(todoSetId: todoSet.id),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$checkedCount/${items.length} チェック済み'),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        end: items.isEmpty ? 0 : checkedCount / items.length,
                      ),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      builder: (context, value, _) =>
                          LinearProgressIndicator(value: value),
                    ),
                  ],
                ),
              ),
              if (checklist.isCompleted)
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    width: double.infinity,
                    color: Colors.green.withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('本日は完了しました'),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('持ち物がありません'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return CheckboxListTile(
                            title: Text(item.label),
                            value: checklist.isChecked(item.id),
                            onChanged: (_) async {
                              final wasChecked = checklist.isChecked(item.id);
                              await repo.toggleItem(checklist, item.id);
                              if (wasChecked && checklist.isCompleted) {
                                // Unchecking an item while already completed
                                // means it's no longer truly done.
                                await repo.setCompleted(checklist, false);
                                return;
                              }
                              final allChecked = items.every(
                                (item) => checklist.isChecked(item.id),
                              );
                              if (allChecked) {
                                await repo.setCompleted(checklist, true);
                              }
                            },
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextFormField(
                  initialValue: checklist.memo,
                  decoration: const InputDecoration(
                    labelText: 'メモ',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (value) => repo.setMemo(checklist, value),
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: checklist.isCompleted
                      ? OutlinedButton(
                          onPressed: () async {
                            await repo.setCompleted(checklist, false);
                            await repo.setAllChecked(
                              checklist,
                              items.map((item) => item.id).toList(),
                              false,
                            );
                          },
                          child: const Text('完了を取り消す'),
                        )
                      : FilledButton(
                          onPressed: () => repo.setCompleted(checklist, true),
                          child: const Text('完了する'),
                        ),
                ),
              ),
            ],
          ),
          IgnorePointer(
            child: _CelebrationOverlay(
              animation: _celebrationController,
              particles: _confetti,
            ),
          ),
        ],
      ),
    );
  }
}

/// Confetti burst + a bouncing checkmark, played once whenever [animation]
/// runs from 0 to 1. Built from Flutter's own animation/canvas APIs (no
/// extra package) to keep this a lightweight, one-off flourish.
class _CelebrationOverlay extends StatelessWidget {
  const _CelebrationOverlay({required this.animation, required this.particles});

  final Animation<double> animation;
  final List<_ConfettiParticle> particles;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progress = animation.value;
        if (progress <= 0 || progress >= 1) return const SizedBox.shrink();
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ConfettiPainter(
                  particles: particles,
                  progress: progress,
                ),
              ),
            ),
            Center(child: _BouncingCheck(progress: progress)),
          ],
        );
      },
    );
  }
}

class _BouncingCheck extends StatelessWidget {
  const _BouncingCheck({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final scaleT = (progress / 0.4).clamp(0.0, 1.0);
    final scale = Curves.elasticOut.transform(scaleT);
    final opacity = progress < 0.6
        ? 1.0
        : (1 - (progress - 0.6) / 0.4).clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: const Icon(Icons.check_circle, color: Colors.green, size: 120),
      ),
    );
  }
}

class _ConfettiParticle {
  const _ConfettiParticle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
  });

  final double angle;
  final double speed;
  final Color color;
  final double size;

  static final math.Random _random = math.Random();
  static const List<Color> _palette = [
    Colors.pinkAccent,
    Colors.amber,
    Colors.lightBlueAccent,
    Colors.green,
    Colors.deepPurpleAccent,
    Colors.orangeAccent,
  ];

  factory _ConfettiParticle.random() {
    return _ConfettiParticle(
      angle: _random.nextDouble() * 2 * math.pi,
      speed: 0.6 + _random.nextDouble() * 0.4,
      color: _palette[_random.nextInt(_palette.length)],
      size: 5 + _random.nextDouble() * 5,
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.progress});

  final List<_ConfettiParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.3);
    final maxDistance = size.shortestSide * 0.6;
    final opacity = (1 - progress).clamp(0.0, 1.0);

    for (final particle in particles) {
      final distance = particle.speed * maxDistance * progress;
      final dx = center.dx + math.cos(particle.angle) * distance;
      final dy =
          center.dy +
          math.sin(particle.angle) * distance +
          80 * progress * progress;
      final paint = Paint()..color = particle.color.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(dx, dy),
        particle.size * (1 - progress * 0.3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
