import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/async_views.dart';
import '../data/auth_repository.dart';

/// Creates an anonymous session if needed; the router leaves this page once
/// a user exists.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(sessionBootstrapProvider);
    return Scaffold(
      body: SafeArea(
        child: bootstrap.hasError
            ? ErrorView(
                error: bootstrap.error!,
                onRetry: () => ref.invalidate(sessionBootstrapProvider),
              )
            : const LoadingView(),
      ),
    );
  }
}
