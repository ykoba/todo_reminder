# 仕様書 — 持ち物アラーム

## 1. 概要

指定した時刻・曜日に繰り返し通知を送り、その通知から日々のチェックリスト（持ち物確認など）を
記録できるFlutterアプリ。ユーザーは複数の「Todoセット」を作成でき、セットごとに独立した
通知スケジュールとチェック履歴を持つ。

## 2. 用語

| 用語 | 説明 |
|---|---|
| Todoセット (`TodoSet`) | 名前・持ち物リスト・通知スケジュールをまとめたチェックリストのテンプレート |
| 持ち物 (`TodoItem`) | Todoセットを構成する1件のチェック対象（例:「ハンカチ」） |
| スケジュール (`Schedule`) | 通知を発火させる時刻と曜日の組 |
| 日次チェックリスト (`DailyChecklist`) | あるTodoセットの、ある1日分のチェック状態の記録 |
| 日付キー (`dateKey`) | `yyyy-MM-dd` 形式のローカル日付文字列。`DailyChecklist` を日に紐づけるキー |

## 3. 機能要件

### 3.1 Todoセットの管理
- 一覧画面でTodoセットを作成・編集・削除できる。一覧の各行は名前・アイコン・通知スケジュール
  概要のみを表示するシンプルな見た目で、日付ヘッダー・完了チェックマーク・持ち物数・
  有効/無効スイッチは表示しない（詳細は 8.2 `TodoSetListScreen`）。
- 一覧画面のAppBarにある並び替えボタンから並び替えモードに切り替え、Todoセットをドラッグして
  表示順を変更できる（`sortOrder` に永続化）。通常時は誤操作を避けるためドラッグハンドルは
  非表示で、並び替えモード中のみ表示される。「完了」ボタンで通常表示に戻る。
- 一覧画面のAppBarにある編集ボタンから編集モードに切り替えると、各行に編集アイコンが現れ、
  行そのものをタップしても編集画面が開くようになる（通常モードでは行タップでチェックリスト
  画面が開く）。「完了」ボタンで通常表示に戻る。
- 1セットは「名前」「アイコン」「持ち物リスト（並び替え可）」「通知時刻」「通知する曜日（複数選択）」
  「通知の有効/無効」を持つ。有効/無効はセット編集画面でのみ切り替える。
- 名前は最大20文字（半角・全角を区別せず文字数でカウント）。空文字では保存不可。
- アイコンは、モダンなアウトライン様式のMaterialアイコン20種類（学校・家・買い物・掃除・薬など、
  Todoの用途を想起させるもの）から選択する。未選択時（新規作成直後、または追加前に保存された
  既存データ）は「チェックリスト」アイコンが既定値となる。一覧画面の各行に丸いバッジとして表示される。
- 持ち物のうち、ラベルが空のものは保存時に除外される。除外した結果、持ち物が1件も残らない場合は
  保存できない（最低1件の持ち物が必須）。
- 削除時は確認ダイアログを表示し、削除と同時に該当セットの予約通知もすべて解除する。

### 3.2 通知
- Todoセットごとに、選択された曜日の数だけ「毎週同じ曜日・同じ時刻」の繰り返し通知を予約する。
- 通知の本文には「{セット名}の持ち物を確認しましょう！」（例:「仕事の持ち物を確認しましょう！」）
  を表示し、前向きにチェックを促す。タイトルは引き続きセット名のみ。
- 次のいずれかが起きた場合、そのセットの予約済み通知はすべて解除され、現在の内容で再作成される
  （= 常に最新の持ち物・時刻・曜日・有効状態を反映する）。
  - Todoセットの保存（新規作成・編集。有効/無効の切り替えもここに含まれる）
  - Todoセットの削除（この場合は解除のみで再作成しない）
- 無効化されているセット、通知曜日が0件のセット、持ち物が0件のセットは通知を予約しない。
- 通知をタップすると、対応するTodoセットのチェックリスト画面が開く。
  - アプリがフォアグラウンド/バックグラウンドで動作中の場合は即座に遷移する。
  - アプリが終了した状態から通知タップで起動された場合は、起動直後に同じ画面へ遷移する。
- 初回起動時（正確にはアプリ起動ごと）に通知権限を要求する。Android 12以降では正確な時刻に
  通知するための「正確なアラーム」権限もあわせて要求する。

### 3.3 チェックリスト
- Todoセットをタップする、または通知をタップすると、そのセットの「今日」のチェックリスト画面が開く。
- 画面初回表示時に、当日分の `DailyChecklist` が存在しなければ空の状態で自動作成される。
- 各持ち物はチェックボックスで表示され、タップすると即座に保存される（明示的な保存操作は不要）。
  全持ち物がチェック済みになると自動的に完了状態になる。完了済みの状態でいずれかのチェックを
  外すと、自動的に完了が取り消される（チェック状態自体はそのまま、`completedAt` のみ
  クリアされる）。
- チェック済み件数 / 全件数と進捗バーを画面上部に表示する。
- AppBarの「すべてチェック」ボタンで、全持ち物を一括でチェック済みにできる（併せて完了状態にもなる）。
  持ち物が0件の場合は無効化される。
- 「完了する」ボタンで当日のチェックリストを完了状態にできる。全持ち物のチェックは完了の必須条件では
  ない（チェック漏れがあっても、ユーザーの判断で完了にできる）。完了後は「完了を取り消す」ボタンで
  取り消せる。取り消すと、完了状態の解除と同時に全持ち物のチェックも外れる
  （チェック済みのまま「未完了」に見える状態を避けるため）。
- チェックリスト画面には、その日の自由記述メモ欄（ラベル「メモ」）があり、入力するたびに
  即座に保存される。
- チェックリスト画面から、そのセットの過去の完了状況を月カレンダーで確認できる
  （詳細は 8.6 `ChecklistHistoryScreen`）。

### 3.4 データの独立性
- Todoセットの持ち物編集は、過去に記録済みの `DailyChecklist`（各日のチェック状態）に影響しない。
  `DailyChecklist` はチェック時点の持ち物IDの集合のみを保持し、テンプレートである
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
| `times` | `List<ScheduleTime>` | 通知時刻のリスト（1日に複数時刻を設定可能。各要素は `hour`/`minute` を持つ） |
| `repeatDays` | `List<int>` | 通知する曜日。`DateTime.weekday` 準拠（1=月 〜 7=日） |
| `intervalWeeks` | `int` | 通知の間隔（週）。`1`=毎週（既定）、`2`=隔週。編集画面が公開しているのはこの2択のみ |
| `anchorDate` | `DateTime` | `intervalWeeks > 1` のときに、どの週が「オン」かを決める基準日（内部的には `anchorDateMillis`（エポックミリ秒、`int`）として保存。`DateTime` のコンストラクタが `const` ではなく Hiveの`defaultValue`に使えないための実装上の都合）。`intervalWeeks` が `1` のときは未使用 |

`isActiveOnWeekOf(DateTime)`（メソッド）は、指定した日を含む週（月曜始まり）がこのスケジュールの「オンの週」かどうかを返す。`intervalWeeks` が `1` のときは常に `true`。`anchorDate` の週からの経過週数を `intervalWeeks` で割った余りが `0` の週がオンになる。

### `ScheduleTime`
| フィールド | 型 | 説明 |
|---|---|---|
| `hour` | `int` | 時 |
| `minute` | `int` | 分 |

### 4.3 `TodoSet`
| フィールド | 型 | 説明 |
|---|---|---|
| `id` | `String` | UUID |
| `name` | `String` | セット名 |
| `items` | `List<TodoItem>` | 持ち物リスト（テンプレート） |
| `schedule` | `Schedule` | 通知スケジュール |
| `isEnabled` | `bool` | 通知の有効/無効 |
| `createdAt` | `DateTime` | 作成日時 |
| `updatedAt` | `DateTime` | 更新日時 |
| `sortOrder` | `int` | 一覧画面での表示順（昇順）。フィールド追加前に保存された既存データは読み込み時に `0` として扱われる |
| `icon` | `String` | 一覧画面に表示するアイコンのキー（`lib/utils/todo_set_icons.dart` の `todoSetIcons` のキー）。フィールド追加前に保存された既存データ、および未知のキーは読み込み時に既定値（`checklist`）として扱われる |

`sortedItems`（getter）は `TodoItem.sortOrder` 昇順にソートした `items` を返す（`TodoSet.sortOrder` とは別物）。

### 4.4 `DailyChecklist`
| フィールド | 型 | 説明 |
|---|---|---|
| `id` | `String` | UUID |
| `todoSetId` | `String` | 対象の `TodoSet.id` |
| `dateKey` | `String` | `yyyy-MM-dd`（ローカル日付） |
| `checkedItemIds` | `List<String>` | チェック済み持ち物のID一覧 |
| `completedAt` | `DateTime?` | 完了操作を行った日時。`null` なら未完了 |
| `memo` | `String` | その日の自由記述メモ。フィールド追加前に保存された既存データは読み込み時に空文字として扱われる |

`isCompleted`（getter） = `completedAt != null`。
`isChecked(itemId)`（メソッド） = `checkedItemIds` に含まれるか。

## 5. 永続化層 (`lib/data/`)

- `hive_boxes.dart`: `Hive.initFlutter()` の実行、4つの `TypeAdapter` の登録、
  `todo_sets` ボックス（`Box<TodoSet>`）・`daily_checklists` ボックス（`Box<DailyChecklist>`）・
  `settings` ボックス（型なし、アプリ全体の設定値用）のオープンを行う
  （`initHive()`、`main()` から起動時に1回呼ばれる）。
- `todo_set_repository.dart` (`TodoSetRepository`): `todo_sets` ボックスへのCRUD。
  一覧は `sortOrder` 昇順で返す。`reorder(orderedSets)` は与えられた順序に合わせて各セットの
  `sortOrder` を振り直して保存する（一覧画面のドラッグ並び替えから呼ばれる）。
  `replaceAll(todoSets)` はボックスの中身をすべて破棄して `todoSets` に置き換える
  （バックアップ復元専用。詳細は `BackupService`）。
- `checklist_repository.dart` (`ChecklistRepository`): `daily_checklists` ボックスへのCRUD。
  キーは `"{todoSetId}_{dateKey}"`。`getOrCreate` は当日分が無ければ空の `DailyChecklist` を
  作成して保存する。`toggleItem` / `setCompleted` / `setAllChecked` / `setMemo` は即座に
  該当レコードを保存する。`setAllChecked(checklist, itemIds, checked)` は `checked: true` なら
  `itemIds` すべてをチェック済みに、`false` なら（`itemIds` を無視して）全チェックを解除する。
  `getAllForTodoSet(todoSetId)` は指定セットの全期間分の `DailyChecklist` を返す
  （完了履歴カレンダーで使用）。`getAll()` は全セット分の `DailyChecklist` を返す
  （バックアップ書き出し用）。`replaceAll(checklists)` は `TodoSetRepository.replaceAll` と同様、
  ボックスの中身をすべて置き換える。
- `backup_service.dart` (`BackupService`): 全TodoSet・全DailyChecklistを1つのJSONドキュメントに
  書き出す/読み込む。本アプリはサーバーを持たないため、機種変更・再インストール時にデータを
  引き継ぐ唯一の手段。
  - `exportToJson()`: `{version, exportedAt, todoSets, dailyChecklists}` の形をした、
    インデント付きJSON文字列を返す（同期メソッド。ファイルI/Oは呼び出し側が行う）。
  - `importFromJson(jsonString)`: 渡されたJSONの内容で、`TodoSetRepository.replaceAll` /
    `ChecklistRepository.replaceAll` を呼び、既存データを完全に置き換える（マージではない）。
    JSONとして解析できない、または期待する形（`todoSets`/`dailyChecklists` が配列でない、
    各要素に必須フィールドが欠けている等）でない場合は `FormatException` を投げ、
    どちらのボックスも変更しない（一部だけ壊れた状態で上書きされることを防ぐため、
    両リポジトリへの書き込みより前に全件のパースを完了させてから反映する）。
  - `screens/settings_screen.dart`（バックアップの操作ボトムシート）が唯一の呼び出し元:
    「バックアップを作成」は `exportToJson()` の結果を一時ファイルへ書き出し、
    `share_plus` のOS標準共有シートに渡す（保存先はユーザーが選ぶ）。「バックアップから復元」は
    `file_picker` でJSONファイルを選ばせ、上書き確認ダイアログを経てから `importFromJson()` を
    呼ぶ。

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
- `checklistHistoryProvider(todoSetId)`: 指定セットの全 `DailyChecklist` を
  `Stream<Map<String, DailyChecklist>>`（キーは `dateKey`）として公開。
  `ChecklistHistoryScreen` のカレンダー表示に使用。
- `todoSetRepositoryProvider` / `checklistRepositoryProvider` / `notificationServiceProvider` /
  `backupServiceProvider`: 各サービス・リポジトリのシングルトン提供。
- `themeModeProvider`（`lib/providers/theme_providers.dart`）: ユーザーが選択した表示テーマ
  （`ThemeMode.system` / `light` / `dark`）を保持する `NotifierProvider`。`settings` ボックスの
  キー `themeMode` にインデックス値として永続化し、アプリ再起動後も選択が復元される。
- `onboardingProvider`（`lib/providers/onboarding_providers.dart`）: 初回オンボーディングを
  完了済みかどうか（`bool`）を保持する `NotifierProvider`。`settings` ボックスのキー
  `hasSeenOnboarding` に永続化する。詳細は 8.8 `OnboardingScreen`。

## 7. 通知実装 (`lib/notifications/notification_service.dart`)

`NotificationService`（シングルトン）が `flutter_local_notifications` をラップする。

- **初期化 (`init`)**: タイムゾーンDBの初期化とローカルタイムゾーンの設定、Android通知
  チャンネル（`todo_reminder_channel`）の作成、通知タップ時のコールバック登録を行う。
- **スケジューリング (`scheduleForTodoSet`)**: 対象セットの通知をいったんすべて解除した上で、
  `schedule.repeatDays × schedule.times`（曜日 × 時刻）の組み合わせごとに通知を組み立てる。
  通知の `payload` にはTodoセットのIDを設定し、タップ時にどのセットを開くか判別する。
  Android側は `androidScheduleMode: exactAllowWhileIdle`（正確なアラーム、低電力モードでも発火）。
  組み立て方は `schedule.intervalWeeks` によって2通りに分かれる。
  - **`intervalWeeks == 1`（毎週、既定）**: 1件の `zonedSchedule` を
    `matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime` 付きで呼ぶ。OS側が
    「毎週その曜日・時刻」に無期限で繰り返してくれるため、アプリを開かなくても鳴り続ける。
  - **`intervalWeeks > 1`（隔週など）**: OS標準のトリガーには「N週間ごと」に対応する
    繰り返し指定が存在しないため、`Schedule.isActiveOnWeekOf` で「オンの週」に該当する
    今後の発火日時を `_biweeklyWindowCount`（8件）分だけ計算し、それぞれ
    `matchDateTimeComponents` を付けない単発の `zonedSchedule` として個別に予約する
    （1件ごとに `intervalWeeks * 7` 日ずつ先の日時になる）。8件はおよそ数か月分の予約に
    相当し、アプリを開くたびに（`lib/app.dart` の起動処理から）`scheduleForTodoSet` を
    呼び直して予約分を継ぎ足す（詳細は8.が続く前の本文）。長期間アプリを開かないと、
    この予約分を使い切った時点で通知が止まる可能性がある。
- **解除 (`cancelForTodoSet`)**: 直前のスケジュールが何曜日・何時刻・何件の予約を持っていたかは
  分からないため、想定しうる全ID空間（曜日1〜7 × `maxTimesPerDay`（6）× 隔週用の
  occurrenceIndex（8）＝ 336通り）に対して `cancel` を呼ぶ。存在しないIDへの `cancel` は
  無害（何もしない）。
- **通知ID (`_notificationId`)**: `todoSetId` 文字列からの簡易ハッシュ（31進の畳み込み、
  `0x7FFFFFFF` でマスク）・曜日・時刻のインデックス（`schedule.times`内の何番目か）・
  隔週スケジュールにおける発火回のインデックスから、一意なID
  `(hash % 1_000_000) * 1000 + weekday * 100 + timeIndex * 10 + occurrenceIndex` を生成する。
  `intervalWeeks == 1` のときは `occurrenceIndex` は常に `0`（OS側が繰り返すため1件のみ）。
  Dartの `String.hashCode` はSDKバージョン間で安定性が保証されないため使用しない。
- **タップ検知**:
  - アプリ実行中: `onDidReceiveNotificationResponse` → `onTodoSetSelected`
    （`Stream<String>`）経由で `payload`（= todoSetId）を通知。
  - 終端状態からの起動: `getLaunchTodoSetId()` が `getNotificationAppLaunchDetails()` を
    参照し、通知起動であればその `payload` を返す。
- **権限要求 (`requestPermissions`)**: Androidは通知権限＋正確なアラーム権限、iOSは
  alert/badge/soundの許可を要求する。

`lib/app.dart` の `_MyAppState` が、初回フレーム後に権限要求 →
`getLaunchTodoSetId()` の確認（起動遷移）→ `onTodoSetSelected` の購読（実行中の遷移）→
保存済み全Todoセットの `scheduleForTodoSet` 再実行、の順で初期化し、いずれの通知タップ
経路でも `ChecklistScreen(todoSetId: ...)` を `rootNavigatorKey` 経由でプッシュする。
最後の全件再スケジュールは、隔週スケジュールの予約分（ローリングウィンドウ）を
アプリを開くたびに継ぎ足すためのもの（上記参照）。同じフレームで
`ReviewPromptService.recordAppOpenAndMaybePromptReview()` も呼ばれる（詳細は 9. レビュー依頼）。

## 8. 画面仕様 (`lib/screens/`)

### 8.1 画面遷移

```
TodoSetListScreen（一覧・起点）
  ├─ [+]（通常モードのみ） → TodoSetEditScreen(todoSetId: null)       … 新規作成
  ├─ [設定アイコン]（通常モードのみ） → SettingsScreen
  │    ├─ [このアプリについて] → AboutScreen
  │    ├─ [プライバシーポリシー] → PrivacyPolicyScreen
  │    ├─ [表示テーマ] → テーマ選択ボトムシート（端末の設定に従う/ライト/ダーク）
  │    └─ [バックアップ] → バックアップ操作ボトムシート（作成/復元）
  ├─ 編集モード中: [行タップ] / [編集アイコン] → TodoSetEditScreen(todoSetId: id) … 編集
  └─ 通常モード中: [行タップ] / 通知タップ → ChecklistScreen(todoSetId: id)
                                  └─ [カレンダーアイコン] → ChecklistHistoryScreen(todoSetId: id)
```

### 8.2 `TodoSetListScreen`
- `todoSetListProvider` を購読し、Todoセットが0件なら空状態のイラスト（アイコンを重ねた
  丸いバッジ・見出し・案内文）を表示し、それ以外は `ListTile` のリストを表示。画面には
  「通常」「並び替え」「編集」の3モードがあり、通常モードのみで行ウィジェットが異なる。
  3モードは同時に併用できず、AppBarの「完了」ボタンで通常モードに戻る。
- **通常モード**（起動時の既定）: 各行に「セットのアイコン（丸いバッジ）」「名前」
  「スケジュール概要」のみを表示する（完了チェックマーク・持ち物数・有効/無効スイッチは
  表示しない）。行タップでチェックリスト画面へ。右下に、並び替え用・編集用の小さいFABと
  新規作成用の通常サイズFAB（`+`）を縦に並べて表示する（詳細は下記）。新規セットは常に
  一覧の末尾に追加される（`sortOrder` = 作成時点のセット数）。
- **並び替えモード**: 右下の並び替えFABをタップすると切り替わる。誤操作を防ぐため、
  各行はアイコン・名前・ドラッグハンドルのみの簡略表示になり、行タップでの画面遷移・FABは
  表示されない。ドラッグハンドルを掴んで並び替えると `TodoSetRepository.reorder` により
  表示順が即座に永続化される。
- **編集モード**: 右下の編集FABをタップすると切り替わる。各行の右端に編集アイコンが
  現れ、そのアイコンをタップしても、行そのものをタップしても
  `TodoSetEditScreen(todoSetId: id)` が開く。FAB群・AppBarの設定アイコンは表示されない。
- 並び替え・編集モードは、AppBarの「完了」ボタンで通常モードに戻る。
- 右下のFAB群（通常モードのみ表示）: 上から「並び替え」「編集」（いずれも
  `FloatingActionButton.small`）、一番下に新規作成用の通常サイズ `FloatingActionButton`
  （`+`）。並び替え・編集はリスト操作の頻度が低い補助アクションのため、画面の主動線である
  新規作成ボタンより小さいサイズで、その直上にまとめて配置している。
- AppBarには固定の歯車アイコン（`Icons.settings_outlined`。通常モードのみ表示）のみを置き、
  タップすると `SettingsScreen` へ遷移する。以前はこのアイコン自体が現在のテーマに応じて
  表示を変え、テーマ・バックアップ・プライバシーポリシー・このアプリについてをすべて1つの
  オーバーフローメニューに並べていたが、リスト操作と無関係な項目が並ぶうえアイコンの意味が
  分かりにくかったため、一般的な「設定は専用画面」というパターンに合わせて分離した
  （詳細は 8.3）。

### 8.3 `SettingsScreen`
- `TodoSetListScreen`（通常モード）のAppBarにある設定アイコンから遷移する、アプリ全体の
  設定・情報をまとめた画面。上から「このアプリについて」「プライバシーポリシー」
  「表示テーマ」「バックアップ」の順に `ListTile` を並べる（利用頻度ではなく、アプリの
  素性を知る／変更しない情報から、実際に挙動を変える設定という順）。
- 「このアプリについて」: `AboutScreen` へ遷移する（詳細は 8.9）。ダイアログではなく、
  プライバシーポリシーと同じ画面遷移形式で表示する。
- 「プライバシーポリシー」: `PrivacyPolicyScreen` へ遷移する（詳細は 8.7）。
- 「表示テーマ」: 現在の設定（「端末の設定に従う」「ライト」「ダーク」）をsubtitleに表示し、
  タップするとその3択のボトムシートが開く。選択すると `themeModeProvider` を通じて即時に
  アプリ全体へ反映され、Hiveに永続化される。
- 「バックアップ」: タップすると「バックアップを作成」「バックアップから復元」の2択の
  ボトムシートが開く。
  - 「バックアップを作成」: `BackupService.exportToJson()` の結果を一時ファイルへ書き出し、
    `share_plus` のOS標準共有シートで送る（保存先はユーザーが選ぶ）。
  - 「バックアップから復元」: `file_picker` でJSONファイルを選択させ、「現在保存されている
    すべてのセットとチェック履歴が上書きされます」という確認ダイアログ（キャンセル/復元）を
    経てから `BackupService.importFromJson()` を呼ぶ。ファイル形式が不正な場合は
    `FormatException` のメッセージをSnackBarで表示し、既存データはそのまま残る。

### 8.4 `TodoSetEditScreen`
- `todoSetId == null` なら新規作成、それ以外は既存データを読み込んで編集。
- 入力項目: セット名（最大20文字、`TextField.maxLength` で強制。半角・全角を区別せず
  文字数でカウント）、アイコン（20種類から選択する `Wrap` 表示のボタン群。選択中のものは
  強調表示される）、通知時刻（`showTimePicker`）、通知曜日（`FilterChip` の複数選択）、
  通知の有効/無効（`SwitchListTile`）、持ち物リスト（`ReorderableListView` でドラッグ並び替え・
  追加・削除）。
- 保存時にバリデーション（名前必須、ラベルが空でない持ち物が1件以上必須）を行い、
  `TodoSetRepository.save` → `NotificationService.scheduleForTodoSet` の順で実行してから
  画面を閉じる。
- 編集時のみ削除アイコンを表示。削除は確認ダイアログの後、通知解除 → データ削除の順で実行。

### 8.5 `ChecklistScreen`
- 初期化時に当日分の `DailyChecklist` を `getOrCreate` する。
- タイトルにセット名と `M/d（曜）` 形式の日本語日付を表示。AppBarに「すべてチェック」
  ボタン（`Icons.done_all`。全持ち物を一括チェックし完了状態にする。持ち物が0件なら無効化）と
  カレンダーアイコン（`ChecklistHistoryScreen(todoSetId: ...)` へ遷移）を表示。
- チェック済み件数と進捗バーを表示。進捗バーは値が変わるたびに `TweenAnimationBuilder` で
  滑らかに（300ms）アニメーションする。
- 完了済みの場合は「本日は完了しました」というバナーを `AnimatedSize` でアニメーションしながら
  表示・非表示する。
- 各持ち物を `CheckboxListTile` で表示し、タップで即座にトグル・保存。全持ち物がチェック済みに
  なった時点で自動的に完了状態にする。
- 持ち物リストの下に、その日のメモを入力する `TextFormField`（ラベル「メモ」、3行）を表示。
  入力するたびに `ChecklistRepository.setMemo` で即座に保存する。
- 画面下部に「完了する」/「完了を取り消す」ボタン（完了状態に応じて切り替え）。
  「完了を取り消す」は完了状態の解除と同時に全持ち物のチェックも解除する
  （`setCompleted(false)` と `setAllChecked(..., false)` を両方呼ぶ）。
- **完了時の演出**: チェック状態が未完了→完了へ遷移した瞬間（チェックで全部揃った時、
  「すべてチェック」ボタン、「完了する」ボタンのいずれでも）、紙吹雪の演出と中央にバウンドする
  チェックマークを1.4秒間表示し、あわせて軽いハプティックフィードバック
  （`HapticFeedback.mediumImpact()`）を発生させる。紙吹雪・チェックマークともに
  `AnimationController` と `CustomPainter` による自作の実装で、外部パッケージには依存しない。
  完了→未完了の遷移（チェックを外す、「完了を取り消す」）では演出しない。

### 8.6 `ChecklistHistoryScreen`
- 対象Todoセットの完了履歴を月単位のカレンダーで表示する。`checklistHistoryProvider(todoSetId)`
  （`ChecklistRepository.getAllForTodoSet` を `dateKey` でMap化したもの）を購読。
- 各日を丸いセルで表示し、完了済み（`isCompleted`）の日は緑色、記録はあるが未完了の日は
  グレー、今日は枠線で強調する。未来の日付はタップ不可（薄いグレー表示）。
- 上部の「<」「>」で表示月を移動できる（未来の月へは移動不可）。
- 日付セルをタップすると、その日の状態（記録なし／未完了／完了）とチェック件数を
  `SnackBar`（表示時間2秒）で表示する。表示中に別の日をタップした場合は、残り時間を待たず
  直前の `SnackBar` を即座に閉じて新しい内容をすぐに表示する
  （`ScaffoldMessenger.clearSnackBars()` の後に `showSnackBar` を呼ぶ）。
- 下部に凡例（緑=完了、グレー=記録あり・未完了）を表示する。

### 8.7 `PrivacyPolicyScreen`
- `SettingsScreen` の「プライバシーポリシー」から遷移する。
- 静的なプライバシーポリシー本文を `SingleChildScrollView` でスクロール表示するだけの画面。
  本アプリはサーバー通信を一切行わない（データはすべて端末内のHiveに保存）ことと、通知関連の
  権限の用途、第三者への提供がないことなどを説明する。本文は `lib/screens/privacy_policy_screen.dart`
  内の定数として保持しており、外部通信や外部ファイルの読み込みは行わない。

### 8.8 `OnboardingScreen`
- アプリのルートウィジェット（`lib/app.dart` の `_AppHome`）が `onboardingProvider`
  （`lib/providers/onboarding_providers.dart`。`settings` ボックスのキー
  `hasSeenOnboarding` に永続化）を購読し、まだ完了していなければ `TodoSetListScreen` の
  代わりにこの画面を表示する。インストール後の初回起動時のみ表示され、以降は表示されない。
- 3枚の `PageView`（アプリの概要／セット作成と通知設定／チェックと達成感、の順）と、
  現在のページを示すインジケーター（ドット）を表示する。
- 最後のページ以外は右上に「スキップ」ボタンを表示し、いつでもオンボーディングを完了できる。
  下部のボタンは最後のページ以外は「次へ」（次ページへ）、最後のページでは「はじめる」
  （オンボーディング完了）になる。
- 「スキップ」「はじめる」はどちらも `onboardingProvider` の `markSeen()` を呼び、
  `hasSeenOnboarding` を `true` として永続化する。`_AppHome` がこの状態変化を検知して
  `TodoSetListScreen` に切り替わる（`MaterialApp.home` 自体を差し替えるのではなく、
  `_AppHome` という固定のウィジェット自身が内部で表示を切り替える設計。`MaterialApp.home`
  は初回ルート生成時にしか参照されないため、後から値を変えても既存のルートには反映されない）。

### 8.9 `AboutScreen`
- `SettingsScreen` の「このアプリについて」から遷移する。以前はFlutter標準の
  `showAboutDialog`（ダイアログ）を使っていたが、プライバシーポリシーと挙動を揃えるため、
  画面遷移形式に変更した。
- アプリ名・`package_info_plus` で取得したバージョン番号・アプリの概要説明・著作権表示を
  `SingleChildScrollView` で表示する静的な画面。`PackageInfo.fromPlatform()` は非同期のため
  `FutureBuilder` で待ち、取得できるまでバージョン行は表示しない。

## 9. レビュー依頼 (`lib/data/usage_tracker.dart`, `lib/data/review_prompt_service.dart`)

継続してアプリを使ってくれているユーザーに、適切なタイミングでストアレビューを促す仕組み。
「連続達成日数」ではなく「連続してアプリを開いた日数」を条件にしている（達成の有無に関わらず
毎日の起動そのものを継続利用のシグナルとして扱う、シンプルで実装が堅牢な設計）。

- **`UsageStreakTracker`**: `recordOpenToday()` が呼ばれるたびに、`settings` ボックスに
  保存された「最後に開いた日」と比較する。前日に開いていれば連続日数を+1、当日すでに
  記録済みなら変更なし、それ以外（間が空いた・初回）なら連続日数を1にリセットして、
  結果の連続日数を返す。
- **`ReviewPromptService`**: `recordAppOpenAndMaybePromptReview()` が `UsageStreakTracker`
  を呼んで連続日数を更新し、その値が `reviewPromptStreakThreshold`（7日）に達していて、
  かつまだ一度もレビュー依頼をしていなければ、`in_app_review` パッケージ経由でOS標準の
  ストアレビューダイアログ（iOS: `SKStoreReviewController`、Android: Play In-App Review
  API）を表示する。一度リクエストしたら `settings` ボックスにフラグを保存し、以降は
  （連続日数が途切れて再度伸びても）二度と表示しない。`InAppReview.isAvailable()` が
  `false` を返した場合は依頼済みフラグを立てず、次回起動時に再試行する。
- 実際の `InAppReview` プラグイン呼び出しは `ReviewRequester`（抽象クラス）越しに行う
  ことで、プラグイン自体にテスト用のモックAPIが無くても `ReviewPromptService` 単体を
  プラットフォームチャンネルなしでテストできるようにしている。
- `lib/app.dart` の `_MyAppState` が、起動処理の一部として毎回
  `recordAppOpenAndMaybePromptReview()` を呼ぶ。

## 10. ユーティリティ (`lib/utils/`)

- `date_key.dart`: `dateKeyFor(DateTime)` / `todayKey()` — ローカル日付を `yyyy-MM-dd`
  文字列に変換する。時刻・タイムゾーンの影響を受けず「暦日」を一意に識別するために使う。
- `schedule_format.dart`: `weekdayLabels`（1〜7→月〜日の1文字ラベル）、
  `formatTime(hour, minute)`（`HH:mm`）、`scheduleSummary(Schedule)`（例:「毎日 07:00」
  「月水金 07:00・18:30」「隔週 毎日 07:00」「未設定 07:00」）、
  `formatJapaneseDate(DateTime)`（例:「8/14（金）」）。
- `todo_set_icons.dart`: `todoSetIcons`（キー→`IconData` の20件のMap）、
  `defaultTodoSetIconKey`（`'checklist'`）、`todoSetIcon(key)`（未知のキーなら既定値の
  アイコンを返すフォールバック付きゲッター）。

## 11. 非機能・既知の制約

- ローカル完結のアプリであり、サーバー同期・複数端末間の共有機能はない。機種変更や再インストールに
  備えるには、設定画面の「バックアップ」→「バックアップを作成」でJSONファイルを書き出して
  おく必要がある
  （詳細は 5. `BackupService`）。
- 通知本文はスケジュール時点の持ち物内容で固定される。持ち物編集後は `scheduleForTodoSet`
  による再スケジュールで最新化されるが、それ以前に発火済みの通知の表示内容は変わらない。
- 通知は1日に複数時刻・隔週での繰り返しに対応する（月次などさらに長い間隔は非対応）。ただし
  隔週以上の間隔にはOS標準の無期限リピートが使えないため、直近8回分だけを予約する
  ローリングウィンドウ方式になっている（詳細は 7. 通知実装）。長期間（おおよそ数か月以上）
  アプリを一度も開かないと、その間はこの予約分を使い切り、通知が止まる可能性がある。
- タイムゾーンは端末のローカルタイムゾーンを起動時に一度取得して使用する。

## 12. テスト

- `test/widget_test.dart`: 一時ディレクトリにHiveを初期化し、Todoセットが0件のときに
  一覧画面が案内文を表示することを確認するウィジェットテスト。
