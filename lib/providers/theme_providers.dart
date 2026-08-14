import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/hive_boxes.dart';

const String _themeModeKey = 'themeMode';

/// User-selected light/dark/system preference, persisted in Hive so it
/// survives app restarts.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  Box get _box => Hive.box(settingsBoxName);

  @override
  ThemeMode build() {
    final stored = _box.get(_themeModeKey) as int?;
    if (stored == null || stored < 0 || stored >= ThemeMode.values.length) {
      return ThemeMode.system;
    }
    return ThemeMode.values[stored];
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _box.put(_themeModeKey, mode.index);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
