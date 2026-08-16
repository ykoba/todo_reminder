import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/data/backup_service.dart';
import 'package:todo_reminder/data/checklist_repository.dart';
import 'package:todo_reminder/data/todo_set_repository.dart';

import '../support/fixtures.dart';
import '../support/hive_test_harness.dart';

void main() {
  final harness = HiveTestHarness();
  late BackupService backupService;
  late TodoSetRepository todoSetRepository;
  late ChecklistRepository checklistRepository;

  setUp(() async {
    await harness.setUp();
    todoSetRepository = TodoSetRepository();
    checklistRepository = ChecklistRepository();
    backupService = BackupService(
      todoSetRepository: todoSetRepository,
      checklistRepository: checklistRepository,
    );
  });

  tearDown(() => harness.tearDown());

  group('exportToJson', () {
    test('includes a format version and export timestamp', () {
      final json = jsonDecode(backupService.exportToJson()) as Map;

      expect(json['version'], 1);
      expect(json['exportedAt'], isA<String>());
      expect(DateTime.tryParse(json['exportedAt'] as String), isNotNull);
    });

    test('is empty but well-formed when nothing has been saved', () {
      final json = jsonDecode(backupService.exportToJson()) as Map;

      expect(json['todoSets'], isEmpty);
      expect(json['dailyChecklists'], isEmpty);
    });

    test('includes every TodoSet and every TodoSet\'s checklists', () async {
      final setA = buildTodoSet(id: 'a', name: 'A');
      final setB = buildTodoSet(id: 'b', name: 'B');
      await todoSetRepository.save(setA);
      await todoSetRepository.save(setB);
      checklistRepository.getOrCreate(setA, '2026-01-01');
      checklistRepository.getOrCreate(setB, '2026-01-02');

      final json = jsonDecode(backupService.exportToJson()) as Map;

      expect((json['todoSets'] as List).length, 2);
      expect((json['dailyChecklists'] as List).length, 2);
    });
  });

  group('importFromJson', () {
    test('round-trips a full TodoSet (items, schedule, icon, etc.)', () async {
      final original = buildTodoSet(
        id: 'a',
        name: '保育園',
        items: [
          buildTodoItem(id: 'item-1', label: '連絡帳', sortOrder: 0),
          buildTodoItem(id: 'item-2', label: '水筒', sortOrder: 1),
        ],
        schedule: buildSchedule(hour: 7, minute: 30, repeatDays: [1, 3, 5]),
        isEnabled: false,
        sortOrder: 2,
        icon: 'school',
      );
      await todoSetRepository.save(original);

      final json = backupService.exportToJson();
      await backupService.importFromJson(json);

      final restored = todoSetRepository.getById('a')!;
      expect(restored.name, '保育園');
      expect(restored.items.map((item) => item.label), ['連絡帳', '水筒']);
      expect(restored.schedule.hour, 7);
      expect(restored.schedule.minute, 30);
      expect(restored.schedule.repeatDays, [1, 3, 5]);
      expect(restored.isEnabled, isFalse);
      expect(restored.sortOrder, 2);
      expect(restored.icon, 'school');
    });

    test(
      'round-trips a full DailyChecklist (checks, completedAt, memo)',
      () async {
        final set = buildTodoSet(
          id: 'a',
          items: [buildTodoItem(id: 'item-1', sortOrder: 0)],
        );
        await todoSetRepository.save(set);
        final checklist = checklistRepository.getOrCreate(set, '2026-01-01');
        await checklistRepository.toggleItem(checklist, 'item-1');
        await checklistRepository.setCompleted(checklist, true);
        await checklistRepository.setMemo(checklist, '発熱のため早退');

        final json = backupService.exportToJson();
        await backupService.importFromJson(json);

        final restored = checklistRepository.get('a', '2026-01-01')!;
        expect(restored.isChecked('item-1'), isTrue);
        expect(restored.isCompleted, isTrue);
        expect(restored.memo, '発熱のため早退');
      },
    );

    test('replaces (not merges) existing data', () async {
      await todoSetRepository.save(buildTodoSet(id: 'old', name: '旧'));
      final backup = backupService
          .exportToJson(); // captured while only "旧" exists

      await todoSetRepository.save(buildTodoSet(id: 'new', name: '新'));
      await backupService.importFromJson(backup);

      final ids = todoSetRepository.getAll().map((set) => set.id);
      expect(ids, ['old']);
    });

    test('throws a FormatException for text that isn\'t JSON', () async {
      await expectLater(
        backupService.importFromJson('not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'throws a FormatException for JSON missing the expected shape',
      () async {
        await expectLater(
          backupService.importFromJson('{"unexpected": true}'),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('throws a FormatException without touching existing data when a todoSet entry is malformed', () async {
      await todoSetRepository.save(buildTodoSet(id: 'kept', name: '保持'));

      await expectLater(
        backupService.importFromJson(
          '{"version": 1, "todoSets": [{"name": "no id"}], "dailyChecklists": []}',
        ),
        throwsA(isA<FormatException>()),
      );

      expect(todoSetRepository.getAll().map((set) => set.id), ['kept']);
    });
  });
}
