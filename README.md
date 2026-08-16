# 持ち物アラーム

保育園の持ち物確認など、「毎日同じ時刻に同じチェックリストを確認したい」というニーズ向けの
Flutterアプリです。複数の**Todoセット**（＝チェックリスト）を作成し、それぞれに通知時刻と
曜日を設定できます。通知をタップするとそのセットのチェックリストが開き、当日分の
チェック状態をつけて完了を記録できます。

詳細な仕様は [docs/SPEC.md](docs/SPEC.md) を参照してください。

## 主な機能

- Todoセット（名前・アイコン・持ち物リスト・通知スケジュール）の作成／編集／削除
- 一覧はシンプルな名前・アイコン・スケジュールのみの表示。並び替え・編集は右下の
  小さいFAB（新規作成ボタンの上）で切り替える専用モードで行う（誤操作防止）
- セットごとにモダンなアイコン20種類から選んで一覧に表示できる
- 曜日ごとの繰り返し通知（例: 平日の7:00に通知、「〜を確認しましょう！」と前向きな文面）
- 通知タップでそのセットのチェックリスト画面を直接開く
- 日毎に独立したチェック状態の保存（テンプレート編集は過去分に影響しない）
- 全持ち物チェックで自動完了、または「完了する」ボタンで明示的に完了扱いにできる。
  「すべてチェック」ボタンや、その日のメモ欄も用意
- 完了の瞬間は紙吹雪＋バウンドするチェックマークの演出とハプティックフィードバックで祝う
- 完了履歴を月カレンダーで可視化（日付タップで完了/未完了・チェック件数を表示）
- ライト/ダーク/端末設定に従う、から選べる表示テーマ（ナイトモード）
- アプリ内で確認できるプライバシーポリシー画面（本アプリはサーバー通信を行わず、
  データはすべて端末内に保存される旨などを記載）
- 初回起動時のみのオンボーディング（3枚のスライドでアプリの使い方を紹介）と、
  イラスト付きの空状態表示
- ローカルバックアップの書き出し／復元（JSON形式。共有シートで保存先を選べる書き出しと、
  ファイル選択＋上書き確認ダイアログを経ての復元）
- 設定画面から確認できる「このアプリについて」（アプリ名・バージョン・概要を表示）

## 技術スタック

- [Flutter](https://flutter.dev/) / Dart
- 状態管理: [flutter_riverpod](https://pub.dev/packages/flutter_riverpod)
- ローカル永続化: [hive](https://pub.dev/packages/hive) / [hive_flutter](https://pub.dev/packages/hive_flutter)
- ローカル通知: [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) +
  [timezone](https://pub.dev/packages/timezone) / [flutter_timezone](https://pub.dev/packages/flutter_timezone)

対応プラットフォーム: Android, iOS, macOS, Windows, Linux（`android/` `ios/` `macos/` `windows/`
`linux/` 各ディレクトリを参照）。

## プロジェクト構成

```
lib/
  main.dart                     エントリーポイント（Hive初期化・通知初期化）
  app.dart                      MaterialApp / 通知タップ時のナビゲーション制御
  models/                       Hiveモデル（TodoItem, Schedule, TodoSet, DailyChecklist）
  data/                         Hiveボックス定義とリポジトリ（永続化層）
  providers/                    Riverpodプロバイダ（Hiveの変更をStreamで公開）
  notifications/                flutter_local_notificationsのラッパー
  screens/                      画面（一覧・編集・チェックリスト・完了履歴カレンダー）
  utils/                        日付キー・スケジュール表示・アイコン一覧のフォーマッタ/定数
```

## セットアップ

前提: Flutter SDK（`pubspec.yaml` の `environment.sdk` が指す Dart SDK を含む）がインストール済みであること。

```bash
# 依存パッケージの取得
flutter pub get

# HiveのTypeAdapter（*.g.dart）を生成する場合
dart run build_runner build --delete-conflicting-outputs
```

## 実行

```bash
flutter run
```

## テスト

```bash
flutter test
```

## 静的解析

```bash
flutter analyze
```
