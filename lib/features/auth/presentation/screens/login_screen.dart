import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoggingIn = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoggingIn) return;

    setState(() => _isLoggingIn = true);
    try {
      await ref
          .read(currentUserProvider.notifier)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  void _showResetPasswordDialog() {
    final resetEmailCtrl = TextEditingController(
      text: _emailController.text.trim(),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('비밀번호 찾기'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '가입한 이메일 주소를 입력하면\n'
                '비밀번호 재설정 링크를 보내드립니다.',
              ),
              const SizedBox(height: AppSizes.md),
              TextFormField(
                controller: resetEmailCtrl,
                keyboardType:
                    TextInputType.emailAddress,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  prefixIcon:
                      Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null ||
                      !v.contains('@')) {
                    return '올바른 이메일을 입력해주세요';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!
                  .validate()) {
                return;
              }
              Navigator.pop(ctx);
              await _sendResetEmail(
                resetEmailCtrl.text.trim(),
              );
            },
            child: const Text('전송'),
          ),
        ],
      ),
    ).then((_) => resetEmailCtrl.dispose());
  }

  Future<void> _sendResetEmail(
    String email,
  ) async {
    try {
      final repo =
          ref.read(authRepositoryProvider);
      await repo.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                '비밀번호 재설정 링크를 이메일로 '
                '발송했습니다. 메일함을 확인해주세요.',
              ),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 5),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                translateAuthError(e),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    ref.listen(currentUserProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                translateAuthError(
                  next.error!,
                ),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
      if (next.hasValue && next.value != null) {
        context.go('/dashboard');
      }
    });

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Title
                  Icon(
                    Icons.science_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppSizes.md),
                  Text(
                    AppStrings.appName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    AppStrings.appDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.xxl),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: AppStrings.email,
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppStrings.errorInvalidEmail;
                      }
                      if (!value.contains('@')) {
                        return AppStrings.errorInvalidEmail;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSizes.md),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      labelText: AppStrings.password,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return AppStrings.errorPasswordShort;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSizes.sm),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed:
                          _showResetPasswordDialog,
                      child: const Text(
                        AppStrings.forgotPassword,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),

                  // Login Button
                  ElevatedButton(
                    onPressed: (_isLoggingIn ||
                            userAsync.isLoading)
                        ? null
                        : _handleLogin,
                    child: (_isLoggingIn ||
                            userAsync.isLoading)
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(AppStrings.login),
                  ),
                  const SizedBox(height: AppSizes.md),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppStrings.noAccount,
                        style: theme.textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text(AppStrings.register),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
