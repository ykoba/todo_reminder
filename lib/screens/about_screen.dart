import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Static "about this app" info, reached the same way as
/// PrivacyPolicyScreen — a full screen rather than a dialog, so both
/// app-info entries in SettingsScreen behave consistently.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('このアプリについて')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final version = snapshot.data?.version;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      child: const Icon(
                        Icons.checklist_rtl_rounded,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('持ち物アラーム', style: textTheme.titleLarge),
                          if (version != null)
                            Text(
                              'バージョン $version',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '「今日、持っていくの忘れてた…」をなくすアプリです。',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '仕事の持ち物、ジムの荷物、毎日の薬など、"決まった時間に、決まった物を確認したい"'
                  'というシンプルなニーズのためのチェックリスト＆通知アプリです。'
                  'セットを作って通知時刻を決めておけば、あとは通知が来た時にチェックを'
                  '入れていくだけ。忘れ物や飲み忘れを、無理なく防ぐ習慣づくりをサポートします。',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                Text('主な機能', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                const _FeatureRow(
                  icon: Icons.checklist_rtl_rounded,
                  title: '持ち物セットを好きなだけ作成',
                  description: '名前・アイコン・持ち物リストを自由に設定。仕事用、ジム用、'
                      '常備薬用など、用途ごとに分けて管理できます。',
                ),
                const _FeatureRow(
                  icon: Icons.notifications_active_outlined,
                  title: '柔軟な通知スケジュール',
                  description: '曜日ごとの繰り返しはもちろん、1日に複数回の通知や、'
                      '隔週での通知にも対応。通知をタップすればその日のチェックリストが'
                      'すぐ開きます。',
                ),
                const _FeatureRow(
                  icon: Icons.celebration_outlined,
                  title: '達成をしっかり実感できる演出',
                  description: '全部チェックすると、紙吹雪が舞って軽い振動でお祝いします。'
                      'うっかり完了を取り消したくなっても、バナーからワンタップで'
                      '戻せます。',
                ),
                const _FeatureRow(
                  icon: Icons.swipe_outlined,
                  title: '直感的な操作',
                  description: 'ドラッグでセットの並び替え、スワイプで削除。削除しても'
                      '「元に戻す」でいつでも復元できるので安心です。',
                ),
                const _FeatureRow(
                  icon: Icons.dark_mode_outlined,
                  title: 'ライト/ダークテーマ',
                  description: '端末の設定に合わせる、または好みのテーマを選んで表示できます。',
                ),
                const _FeatureRow(
                  icon: Icons.save_alt_outlined,
                  title: 'バックアップ・復元',
                  description: '全データをファイルに書き出して保存したり、そこから'
                      '読み込んで元に戻したりできるので、機種変更やアプリの'
                      '再インストール時も安心です。',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        color: colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'プライバシーを大切にしています。本アプリはサーバー通信を一切'
                          '行わず、入力した内容はすべてお使いの端末内にのみ保存されます。'
                          '広告や解析トラッキングも含まれていません。',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '© 2026 持ち物アラーム',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
