import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme.dart';
import '../../../../shared/widgets/async_views.dart';
import '../../../../shared/widgets/bottom_actions.dart';
import '../../data/queue_repository.dart';
import 'my_status_controller.dart';

/// People currently waiting, shown before taking a number.
final waitingCountProvider = FutureProvider.autoDispose<int>(
  (ref) async =>
      (await ref.watch(queueRepositoryProvider).getActiveSession())
          ?.waitingCount ??
      0,
);

/// "Ambil nomor" screen: name field with the action pinned at the bottom.
class TakeTicketView extends ConsumerStatefulWidget {
  const TakeTicketView({super.key, this.onTaken});

  final VoidCallback? onTaken;

  @override
  ConsumerState<TakeTicketView> createState() => _TakeTicketViewState();
}

class _TakeTicketViewState extends ConsumerState<TakeTicketView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(myStatusProvider.notifier).takeTicket(_name.text);
      widget.onTaken?.call();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ambil nomor')),
    body: Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: kScreenPadding,
                vertical: 16,
              ),
              children: [
                const _QueueInfo(),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _name,
                  enabled: !_submitting,
                  autofocus: true,
                  maxLength: 50,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  style: context.text.bodyLarge,
                  decoration: const InputDecoration(
                    labelText: 'Nama Anda',
                    helperText: 'Dipakai kapster untuk memanggil Anda',
                    counterText: '',
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Nama wajib diisi'
                      : null,
                ),
              ],
            ),
          ),
        ),
        BottomActions(
          children: [
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const ButtonSpinner()
                  : const Text('Ambil nomor'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _QueueInfo extends ConsumerWidget {
  const _QueueInfo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = ref.watch(waitingCountProvider).value;
    if (waiting == null) return const SizedBox(height: 40);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.tokens.card,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.groups_outlined, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            waiting == 0
                ? 'Belum ada yang menunggu'
                : 'Saat ini $waiting orang menunggu',
            style: context.text.bodyLarge,
          ),
        ),
      ],
    );
  }
}
