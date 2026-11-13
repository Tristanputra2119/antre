import 'package:material_ui/material_ui.dart';

import '../../core/errors.dart';
import '../../core/theme.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 48, color: context.tokens.inkMuted),
          const SizedBox(height: 16),
          Text(
            friendlyError(error),
            textAlign: TextAlign.center,
            style: context.text.bodyLarge,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    ),
  );
}

/// Shown above stale data when a background refresh failed.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.tokens.cancelledTint,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kScreenPadding,
        vertical: 8,
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 18, color: context.tokens.ink),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Gagal memperbarui data. Menampilkan data terakhir.',
              style: context.text.bodySmall!.copyWith(
                color: context.tokens.ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void showErrorSnackBar(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(friendlyError(error))));
}
