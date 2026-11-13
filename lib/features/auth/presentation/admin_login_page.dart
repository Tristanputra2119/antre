import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/async_views.dart';
import '../../../shared/widgets/bottom_actions.dart';
import '../data/auth_repository.dart';

class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});

  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signInAdmin(email: _email.text, password: _password.text);
      if (mounted) context.go(Routes.admin);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _required(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Wajib diisi' : null;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Masuk kapster')),
    body: SafeArea(
      top: false,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: kScreenPadding,
              vertical: 16,
            ),
            children: [
              TextFormField(
                controller: _email,
                enabled: !_submitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                style: context.text.bodyLarge,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: _required,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _password,
                enabled: !_submitting,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                style: context.text.bodyLarge,
                decoration: InputDecoration(
                  labelText: 'Kata sandi',
                  suffixIcon: IconButton(
                    tooltip: _obscure
                        ? 'Tampilkan kata sandi'
                        : 'Sembunyikan kata sandi',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: context.tokens.inkMuted,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: _required,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const ButtonSpinner()
                    : const Text('Masuk'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
