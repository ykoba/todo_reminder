import 'package:flutter/material.dart';

/// Static, local-only privacy policy — kept in-app (rather than fetched)
/// since the app itself has no network access at all. See the "収集する情報"
/// section below for what that means in practice.
const String _privacyPolicyBody = '''
最終更新日: 2026年8月15日

「持ち物リマインダー」（以下「本アプリ」）は、ユーザーのプライバシーを尊重し、以下の方針に基づいて運営されています。

1. 収集する情報
本アプリは、サーバーへの通信を一切行いません。ユーザーが入力したセット名・持ち物リスト・チェック状態・メモなどのデータは、お使いの端末内にのみ保存され、開発者を含む第三者に送信・共有されることはありません。

2. 端末の権限について
本アプリは、設定した時刻にリマインド通知を届けるために、以下の権限を利用します。

・通知の送信権限
・正確なアラームのスケジュール権限（Android 12以降）

これらの権限は通知機能の実現のみに使用され、広告配信や行動追跡など他の目的には使用しません。

3. 第三者への提供
本アプリは、広告SDK・アクセス解析（アナリティクス）・トラッキングツールなどの第三者ライブラリを組み込んでいません。ユーザーの情報が第三者に提供されることはありません。

4. お子様に関する情報について
本アプリは保育園などの持ち物確認を主な用途としていますが、氏名・写真など特定の個人（お子様を含む）を識別する情報の入力・収集を前提とした機能はありません。入力される内容はすべて端末内にのみ保存されます。

5. データの削除
本アプリのデータはすべて端末内にのみ保存されているため、アプリをアンインストールすることで、保存されていたすべてのデータが端末から削除されます。

6. 本ポリシーの変更
本ポリシーの内容は、必要に応じて改定することがあります。重要な変更がある場合は、本アプリ内での表示を通じてお知らせします。

7. お問い合わせ
本アプリに関するご質問・お問い合わせは、以下までご連絡ください。

kozakura.lovebird16@gmail.com
''';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プライバシーポリシー')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          _privacyPolicyBody.trim(),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
