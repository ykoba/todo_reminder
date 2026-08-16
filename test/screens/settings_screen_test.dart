import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:todo_reminder/screens/about_screen.dart';
import 'package:todo_reminder/screens/privacy_policy_screen.dart';
import 'package:todo_reminder/screens/settings_screen.dart';

import '../support/hive_test_harness.dart';
import '../support/pump_helpers.dart';

void main() {
  final harness = HiveTestHarness();

  setUp(() async {
    await harness.setUp();
    // このアプリについて calls PackageInfo.fromPlatform(), which needs a
    // mock value in tests — there's no real platform to answer it.
    PackageInfo.setMockInitialValues(
      appName: '持ち物アラーム',
      packageName: 'com.example.todoReminder',
      version: '1.2.3',
      buildNumber: '4',
      buildSignature: '',
    );
  });

  tearDown(() async {
    await harness.tearDown();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await settle(tester);
  }

  testWidgets('lists このアプリについて, プライバシーポリシー, 表示テーマ, バックアップ in that order', (
    tester,
  ) async {
    await pumpScreen(tester);

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data)
        .toList();

    expect(titles, ['このアプリについて', 'プライバシーポリシー', '表示テーマ', 'バックアップ']);
  });

  testWidgets('表示テーマ defaults to following the system setting', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('端末の設定に従う'), findsOneWidget);
  });

  testWidgets('tapping このアプリについて opens the about screen with app name and version', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tapAndSettle(tester, find.text('このアプリについて'));

    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.text('持ち物アラーム'), findsWidgets);
    expect(find.textContaining('1.2.3'), findsOneWidget);
  });

  testWidgets('tapping プライバシーポリシー opens the privacy policy screen', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tapAndSettle(tester, find.text('プライバシーポリシー'));

    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
  });

  testWidgets('tapping 表示テーマ opens a picker with all three options', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tapAndSettle(tester, find.text('表示テーマ'));

    expect(find.text('端末の設定に従う'), findsNWidgets(2));
    expect(find.text('ライト'), findsOneWidget);
    expect(find.text('ダーク'), findsOneWidget);
  });

  testWidgets('tapping バックアップ opens a picker with create and restore options', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tapAndSettle(tester, find.text('バックアップ'));

    expect(find.text('バックアップを作成'), findsOneWidget);
    expect(find.text('バックアップから復元'), findsOneWidget);
  });
}
