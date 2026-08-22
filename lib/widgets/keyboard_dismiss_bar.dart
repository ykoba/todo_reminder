import 'package:flutter/material.dart';

/// A bar that sits directly above the on-screen keyboard (mirroring the
/// "Done" accessory bar iOS text fields commonly show), so the keyboard can
/// be closed without tapping outside a field or submitting via the return
/// key. Callers should only build this while the keyboard is actually open,
/// e.g. `if (MediaQuery.of(context).viewInsets.bottom > 0) ...`.
class KeyboardDismissBar extends StatelessWidget {
  const KeyboardDismissBar({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onDismiss,
            icon: const Icon(Icons.keyboard_hide_outlined),
            label: const Text('閉じる'),
          ),
        ),
      ),
    );
  }
}
