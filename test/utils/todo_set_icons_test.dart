import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/utils/todo_set_icons.dart';

void main() {
  test('offers exactly 20 icon choices', () {
    expect(todoSetIcons.length, 20);
  });

  test('all keys and icons are unique', () {
    expect(todoSetIcons.keys.toSet().length, todoSetIcons.length);
    expect(todoSetIcons.values.toSet().length, todoSetIcons.length);
  });

  test('defaultTodoSetIconKey is one of the offered choices', () {
    expect(todoSetIcons.containsKey(defaultTodoSetIconKey), isTrue);
  });

  group('todoSetIcon', () {
    test('returns the icon for a known key', () {
      expect(todoSetIcon('school'), todoSetIcons['school']);
    });

    test('falls back to the default icon for an unrecognized key', () {
      expect(
        todoSetIcon('not-a-real-key'),
        todoSetIcons[defaultTodoSetIconKey],
      );
    });
  });
}
