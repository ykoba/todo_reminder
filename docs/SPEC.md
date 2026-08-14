# 仕様書 — Todoリマインダー

## 1. 概要

指定した時刻・曜日に繰り返し通知を送り、その通知から日々のチェックリスト（持ち物確認など）を
記録できるFlutterアプリ。ユーザーは複数の「Todoセット」を作成でき、セットごとに独立した
通知スケジュールとチェック履歴を持つ。

## 2. 用語

| 用語 | 説明 |
|---|---|
| Todoセット (`TodoSet`) | 名前・項目リスト・通知スケジュールをまとめたチェックリストのテンプレート |
| 項目 (`TodoItem`) | Todoセットを構成する1行のチェック項目（例:「連絡帳」） |
| スケジュール (`Schedule`) | 通知を発火させる時刻と曜日の組 |
| 日次チェックリスト (`DailyChecklist`) | あるTodoセットの、ある1日分のチェック状態の記録 |
| 日付キー (`dateKey`) | `yyyy-MM-dd` 形式のローカル日付文字列。`DailyChecklist` を日に紐づけるキー |

## 3. 機能要件

### 3.1 Todoセットの管理
- 一覧画面でTodoセットを作成・編集・削除できる。
- 1セットは「名前」「項目リスト（並び替え可）」「通知時刻」「通知する曜日（複数選択）」
  「通知の有効/無効」を持つ。
- 名前は必須（空文字では保存不可）。項目のうち、ラベルが空のものは保存時に除外される。
- 削除時は確認ダイアログを表示し、削除と同時に該当セットの予約通知もすべて解除する。
- 一覧画面のスイッチから通知の有効/無効を素早く切り替えられる（保存後、通知が再スケジュールされる）。

### 3.2 通知
- Todoセットごとに、選択された曜日の数だけ「毎週同じ曜日・同じ時刻」の繰り返し通知を予約する。
- 通知の本文には、そのセットの項目ラベルを `・` で連結したものを表示する。
- 次のいずれかが起きた場合、そのセットの予約済み通知はすべて解除され、現在の内容で再作成される
  （= 常に最新の項目・時刻・曜日・有効状態を反映する）。
  - Todoセットの保存（新規作成・編集）
  - 一覧画面での有効/無効の切り替え
  - Todoセットの削除（この場合は解除のみで再作成しない）
- 無効化されているセット、通知曜日が0件のセット、項目が0件のセットは通知を予約しない。
- 通知をタップすると、対応するTodoセットのチェックリスト画面が開く。
  - アプリがフォアグラウンド/バックグラウンドで動作中の場合は即座に遷移する。
  - アプリが終了した状態から通知タップで起動された場合は、起動直後に同じ画面へ遷移する。
- 初回起動時（正確にはアプリ起動ごと）に通知権限を要求する。Android 12以降では正確な時刻に
  通知するための「正確なアラーム」権限もあわせて要求する。

### 3.3 チェックリスト
- Todoセットをタップする、または通知をタップすると、そのセットの「今日」のチェックリスト画面が開く。
- 画面初回表示時に、当日分の `DailyChecklist` が存在しなければ空の状態で自動作成される。
- 各項目はチェックボックスで表示され、タップすると即座に保存される（明示的な保存操作は不要）。
- チェック済み件数 / 全件数と進捗バーを画面上部に表示する。
- 「完了する」ボタンで当日のチェックリストを完了状態にできる。全項目のチェックは完了の条件ではない
  （チェック漏れがあっても、ユーザーの判断で完了にできる）。完了後は「完了を取り消す」ボタンで
  取り消せる。
- 一覧画面では、当日のチェックリストが完了済みかどうかをアイコンで表示する。

### 3.4 データの独立性
- Todoセットの項目編集は、過去に記録済みの `DailyChecklist`（各日のチェック状態）に影響しない。
  `DailyChecklist` はチェック時点の項目IDの集合のみを保持し、テンプレートである
  `TodoSet.items` とは独立して保存される。

## 4. データモデル

すべて [Hive](https://pub.dev/packages/hive) の `HiveObject` として `lib/models/` に定義され、
`lib/models/*.g.dart` に生成される `TypeAdapter` でシリアライズされる。`typeId` はマイグレーション
時の互換性維持のため固定されている。

| モデル | typeId | ファイル |
|---|---|---|
| `TodoItem` | 0 | `lib/models/todo_item.dart` |
| `Schedule` | 1 | `lib/models/schedule.dart` |
| `TodoSet` | 2 | `lib/models/todo_set.dart` |
| `DailyChecklist` | 3 | `lib/models/daily_checklist.dart` |

### 4.1 `TodoItem`
| フィールド | 型 | 説明 |
|---|---|---|
| `id` | `String` | UUID |
| `label` | `String` | 表示ラベル |
| `sortOrder` | `int` | 表示順（昇順） |

### 4.2 `Schedule`
| フィールド | 型 | 説明 |
|---|---|---|
| `hour` | `int` | 通知時刻（時） |
| `minute` | `int` | 通知時刻（分） |
| `repeatDays` | `List<int>` | 通知する曜日。`DateTime.weekday` 準拠（1=月 〜 7=日） |

### 4.3 `TodoSet`
| フィールド | 型 | 説明 |
|---|---|---|
| `id` | `String` | UUID |
| `name` | `String` | セット名 |
| `items` | `List<TodoItem>` | 項目リスト（テンプレート） |
| `schedule` | `Schedule` | 通知スケジュール |
| `isEnabled` | `bool` | 通知の有効/無効 |
| `createdAt` | `DateTime` | 作成日時 |
| `updatedAt` | `DateTime` | 更新日時 |

`sortedItems`（getter）は `sortOrder` 昇順にソートした `items` を返す。

### 4.4 `DailyChecklist`
| フィールド | 型 | 説明 |
|---|---|---|
| `id` | `String` | UUID |
| `todoSetId` | `String` | 対象の `TodoSet.id` |
| `dateKey` | `String` | `yyyy-MM-dd`（ローカル日付） |
| `checkedItemIds` | `List<String>` | チェック済み項目のID一覧 |
| `completedAt` | `DateTime?` | 完了操作を行った日時。`null` なら未完了 |

`isCompleted`（getter） = `completedAt != null`。
`isChecked(itemId)`（メソッド） = `checkedItemIds` に含まれるか。

## 5. 永続化層 (`lib/data/`)

- `hive_boxes.dart`: `Hive.initFlutter()` の実行、4つの `TypeAdapter` の登録、
  `todo_sets` ボックス（`Box<TodoSet>`）・`daily_checklists` ボックス（`Box<DailyChecklist>`）・
  `settings` ボックス（型なし、アプリ全体の設定値用）のオープンを行う
  （`initHive()`、`main()` から起動時に1回呼ばれる）。
- `todo_set_repository.dart` (`TodoSetRepository`): `todo_sets` ボックスへのCRUD。
  一覧は `createdAt` 昇順で返す。
- `checklist_repository.dart` (`ChecklistRepository`): `daily_checklists` ボックスへのCRUD。
  キーは `"{todoSetId}_{dateKey}"`。`getOrCreate` は当日分が無ければ空の `DailyChecklist` を
  作成して保存する。`toggleItem` / `setCompleted` は即座に該当レコードを保存する。

## 6. 状態管理 (`lib/providers/`)

Riverpodの `StreamProvider` でHiveボックスの変更を監視し、CRUD操作をした画面以外にも
変更がリアルタイムに反映される。

- `todoSetListProvider`: 全Todoセットの一覧を `Stream<List<TodoSet>>` として公開。
  `todo_sets` ボックスの変更を監視。
- `todoSetProvider(todoSetId)`: `todoSetListProvider` の結果から単一セットを導出する
  `Provider.family`（Hiveの追加購読はしない）。
- `dailyChecklistProvider(ChecklistKey(todoSetId, dateKey))`: 指定セット・指定日の
  `DailyChecklist` を `Stream<DailyChecklist?>` として公開。`daily_checklists` ボックスの
  変更を監視。呼び出し前に `ChecklistRepository.getOrCreate` でレコードが存在している必要がある。
- `todoSetRepositoryProvider` / `checklistRepositoryProvider` / `notificationServiceProvider`:
  各サービス・リポジトリのシングルトン提供。
- `themeModeProvider`（`lib/providers/theme_providers.dart`）: ユーザーが選択した表示テーマ
  （`ThemeMode.system` / `light` / `dark`）を保持する `NotifierProvider`。`settings` ボックスの
  キー `themeMode` にインデックス値として永続化し、アプリ再起動後も選択が復元される。

## 7. 通知実装 (`lib/notifications/notification_service.dart`)

`NotificationService`（シングルトン）が `flutter_local_notifications` をラップする。

- **初期化 (`init`)**: タイムゾーンDBの初期化とローカルタイムゾーンの設定、Android通知
  チャンネル（`todo_reminder_channel`）の作成、通知タップ時のコールバック登録を行う。
- **スケジューリング (`scheduleForTodoSet`)**: 対象セットの通知をいったんすべて解除した上で、
  `schedule.repeatDays` に含まれる各曜日について1件ずつ `zonedSchedule` を呼び出す
  （`matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime` により毎週繰り返す）。
  通知の `payload` にはTodoセットのIDを設定し、タップ時にどのセットを開くか判別する。
  Android側は `androidScheduleMode: exactAllowWhileIdle`（正確なアラーム、低電力モードでも発火）。
- **解除 (`cancelForTodoSet`)**: 曜日1〜7それぞれの通知IDに対して `cancel` を呼ぶ。
- **通知ID (`_notificationId`)**: `todoSetId` 文字列からの簡易ハッシュ（31進の畳み込み、
  `0x7FFFFFFF` でマスク）と曜日番号から一意なID `(hash % 1_000_000) * 10 + weekday` を生成する。
  Dartの `String.hashCode` はSDKバージョン間で安定性が保証されないため使用しない。
- **タップ検知**:
  - アプリ実行中: `onDidReceiveNotificationResponse` → `onTodoSetSelected`
    （`Stream<String>`）経由で `payload`（= todoSetId）を通知。
  - 終端状態からの起動: `getLaunchTodoSetId()` が `getNotificationAppLaunchDetails()` を
    参照し、通知起動であればその `payload` を返す。
- **権限要求 (`requestPermissions`)**: Androidは通知権限＋正確なアラーム権限、iOSは
  alert/badge/soundの許可を要求する。

`lib/app.dart` の `_MyAppState` が、初回フレーム後に権限要求 →
`getLaunchTodoSetId()` の確認（起動遷移）→ `onTodoSetSelected` の購読（実行中の遷移）
の順で初期化し、いずれの経路でも `ChecklistScreen(todoSetId: ...)` を
`rootNavigatorKey` 経由でプッシュする。

## 8. 画面仕様 (`lib/screens/`)

### 8.1 画面遷移

```
TodoSetListScreen（一覧・起点）
  ├─ [+] → TodoSetEditScreen(todoSetId: null)       … 新規作成
  ├─ [編集アイコン] → TodoSetEditScreen(todoSetId: id) … 編集
  └─ [行タップ] / 通知タップ → ChecklistScreen(todoSetId: id)
```

### 8.2 `TodoSetListScreen`
- `todoSetListProvider` を購読し、Todoセットが0件なら案内文、それ以外は `ListTile` の
  リストを表示。
- 各行に「本日完了済みか（アイコン）」「スケジュール概要 ・ 項目数」「有効/無効スイッチ」
  「編集ボタン」を表示。行タップでチェックリスト画面へ。
- 右下のFABから新規作成画面へ遷移。
- AppBarのアイコンボタン（現在のテーマに応じて表示が変わる）から表示テーマを選択できる
  （「端末の設定に従う」「ライト」「ダーク」）。選択は `themeModeProvider` を通じて即時に
  アプリ全体へ反映され、Hiveに永続化される。

### 8.3 `TodoSetEditScreen`
- `todoSetId == null` なら新規作成、それ以外は既存データを読み込んで編集。
- 入力項目: セット名、通知時刻（`showTimePicker`）、通知曜日（`FilterChip` の複数選択）、
  通知の有効/無効（`SwitchListTile`）、項目リスト（`ReorderableListView` でドラッグ並び替え・
  追加・削除）。
- 保存時にバリデーション（名前必須）を行い、`TodoSetRepository.save` →
  `NotificationService.scheduleForTodoSet` の順で実行してから画面を閉じる。
- 編集時のみ削除アイコンを表示。削除は確認ダイアログの後、通知解除 → データ削除の順で実行。

### 8.4 `ChecklistScreen`
- 初期化時に当日分の `DailyChecklist` を `getOrCreate` する。
- タイトルにセット名と `M/d（曜）` 形式の日本語日付を表示。
- チェック済み件数と進捗バーを表示。
- 完了済みの場合は「本日は完了しました」というバナーを表示。
- 各項目を `CheckboxListTile` で表示し、タップで即座にトグル・保存。
- 画面下部に「完了する」/「完了を取り消す」ボタン（完了状態に応じて切り替え）。

## 9. ユーティリティ (`lib/utils/`)

- `date_key.dart`: `dateKeyFor(DateTime)` / `todayKey()` — ローカル日付を `yyyy-MM-dd`
  文字列に変換する。時刻・タイムゾーンの影響を受けず「暦日」を一意に識別するために使う。
- `schedule_format.dart`: `weekdayLabels`（1〜7→月〜日の1文字ラベル）、
  `formatTime(hour, minute)`（`HH:mm`）、`scheduleSummary(Schedule)`（例:「毎日 07:00」
  「月水金 07:00」「未設定 07:00」）、`formatJapaneseDate(DateTime)`（例:「8/14（金）」）。

## 10. 非機能・既知の制約

- ローカル完結のアプリであり、サーバー同期・複数端末間の共有機能はない。
- 通知本文はスケジュール時点の項目内容で固定される。項目編集後は `scheduleForTodoSet`
  による再スケジュールで最新化されるが、それ以前に発火済みの通知の表示内容は変わらない。
- 通知の繰り返しは「毎週同じ曜日・時刻」に固定で、隔週・月次などの指定はできない。
- タイムゾーンは端末のローカルタイムゾーンを起動時に一度取得して使用する。

## 11. テスト

- `test/widget_test.dart`: 一時ディレクトリにHiveを初期化し、Todoセットが0件のときに
  一覧画面が案内文を表示することを確認するウィジェットテスト。
