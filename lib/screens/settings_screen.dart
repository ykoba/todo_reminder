import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/repository_providers.dart';
import '../providers/theme_providers.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';

/// App-level settings, reached from TodoSetListScreen's AppBar. Rows are
/// ordered roughly by how often a user needs them: what the app is, its
/// legal info, then the two settings that actually change its behavior.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

/// The double-tap guards below are State instance fields rather than a
/// module-level flag: a module-level bool stays true for the lifetime of the
/// isolate whenever the guarded Future doesn't resolve promptly (e.g.
/// Navigator.push's Future only resolves once the pushed route is popped),
/// which could strand it stuck true well beyond this one screen visit.
/// Scoping it to the State means a fresh SettingsScreen visit always starts
/// unguarded.
class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isNavigating = false;
  bool _isThemeSheetOpen = false;
  bool _isBackupSheetOpen = false;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('このアプリについて'),
            onTap: () => _navigateOnce((_) => const AboutScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            onTap: () => _navigateOnce((_) => const PrivacyPolicyScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('表示テーマ'),
            subtitle: Text(_themeModeLabel(themeMode)),
            onTap: _pickThemeMode,
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('バックアップ'),
            subtitle: const Text('作成・復元'),
            onTap: _showBackupOptions,
          ),
        ],
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => '端末の設定に従う',
    ThemeMode.light => 'ライト',
    ThemeMode.dark => 'ダーク',
  };

  Future<void> _navigateOnce(WidgetBuilder builder) async {
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute(builder: builder));
    } finally {
      if (mounted) _isNavigating = false;
    }
  }

  Future<void> _pickThemeMode() async {
    if (_isThemeSheetOpen) return;
    _isThemeSheetOpen = true;
    final current = ref.read(themeModeProvider);
    try {
      await showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in ThemeMode.values)
                ListTile(
                  title: Text(_themeModeLabel(mode)),
                  trailing: mode == current ? const Icon(Icons.check) : null,
                  onTap: () {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) _isThemeSheetOpen = false;
    }
  }

  Future<void> _showBackupOptions() async {
    if (_isBackupSheetOpen) return;
    _isBackupSheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.ios_share_outlined),
                title: const Text('バックアップを作成'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _exportBackup();
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('バックアップから復元'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _importBackup();
                },
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) _isBackupSheetOpen = false;
    }
  }

  /// Writes the current backup JSON to a temp file and hands it to the OS
  /// share sheet, so the user picks where it ends up (Files, Drive,
  /// AirDrop, ...) — this app has no server of its own to upload to.
  Future<void> _exportBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = ref.read(backupServiceProvider).exportToJson();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(
        RegExp('[:.]'),
        '-',
      );
      final file = File('${tempDir.path}/持ち物アラーム_backup_$timestamp.json');
      await file.writeAsString(json);

      if (!mounted) return;
      // sharePositionOrigin anchors the share sheet's popover on iPad;
      // required there, harmless elsewhere.
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: '持ち物アラーム バックアップ',
          sharePositionOrigin: box != null
              ? box.localToGlobal(Offset.zero) & box.size
              : null,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('バックアップの作成に失敗しました: $error')),
      );
    }
  }

  /// Lets the user pick a previously exported JSON file, confirms that
  /// restoring it will overwrite everything currently stored, and — if
  /// confirmed — replaces all local data with its contents.
  Future<void> _importBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null) return; // user cancelled the picker

    final Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (error) {
      messenger.showSnackBar(const SnackBar(content: Text('ファイルを読み込めませんでした')));
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データを復元しますか？'),
        content: const Text(
          '現在保存されているすべてのセットとチェック履歴が、選択したバックアップの内容で'
          '上書きされます。この操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('復元'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final jsonString = utf8.decode(bytes);
      await ref.read(backupServiceProvider).importFromJson(jsonString);
      messenger.showSnackBar(const SnackBar(content: Text('復元しました')));
    } on FormatException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('復元に失敗しました: $error')));
    }
  }
}
