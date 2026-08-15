import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_reminder/screens/privacy_policy_screen.dart';

void main() {
  testWidgets('shows the title and the key privacy commitments', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));

    expect(find.text('プライバシーポリシー'), findsOneWidget);
    expect(find.textContaining('サーバーへの通信を一切行いません'), findsOneWidget);
    expect(find.textContaining('第三者に送信・共有されることはありません'), findsOneWidget);
  });
}
