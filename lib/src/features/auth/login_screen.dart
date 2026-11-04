import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/backend_client.dart';
import '../dashboard/application/dashboard_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    try {
      final hasSession = await ref.read(backendClientProvider).hasSession();
      if (hasSession && mounted) context.go('/dashboard');
    } catch (_) {
      if (mounted) {
        setState(() => error = 'No se pudo acceder al almacenamiento seguro.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (loading) return;
    if (!emailPattern.hasMatch(email.text.trim())) {
      setState(() => error = 'Escribe un correo válido.');
      return;
    }
    if (password.text.trim().isEmpty) {
      setState(() => error = 'Escribe tu contraseña.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await ref.read(backendClientProvider).login(email.text, password.text);
      password.clear();
      ref.invalidate(financeStateProvider);
      if (mounted) context.go('/dashboard');
    } on ApiFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'No se pudo guardar la sesión de forma segura.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Finanzas Móvil',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 24),
                  TextField(
                      key: const ValueKey('email'),
                      controller: email,
                      enabled: !loading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(
                          labelText: 'Correo electrónico')),
                  const SizedBox(height: 16),
                  TextField(
                      key: const ValueKey('password'),
                      controller: password,
                      obscureText: true,
                      enabled: !loading,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration:
                          const InputDecoration(labelText: 'Contraseña'),
                      onSubmitted: (_) => submit()),
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(error!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)))),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: loading ? null : submit,
                      child: Text(loading ? 'Cargando…' : 'Ingresar')),
                ],
              )),
        ))),
      );
}
