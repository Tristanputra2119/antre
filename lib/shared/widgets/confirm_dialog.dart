import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';

/// Confirmation for destructive actions. Resolves to true only on confirm.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String dismissLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      insetPadding: const EdgeInsets.all(24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      title: Text(title),
      // Fills the width between the 24dp insets, as in the design.
      content: SizedBox(width: double.maxFinite, child: Text(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(dismissLabel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: context.tokens.cancelled,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
