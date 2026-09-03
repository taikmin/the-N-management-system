import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/user_role.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _departmentController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  UserRole _selectedRole = UserRole.researcher;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(currentUserProvider.notifier).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
            department: _departmentController.text.trim().isNotEmpty
                ? _departmentController.text.trim()
                : null,
            role: _selectedRole,
          );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.register,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    'R&D Task Manager 계정을 생성합니다',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xl),

                  // Name
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: AppStrings.fullName,
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '이름을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSizes.md),

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
                      if (value == null || !value.contains('@')) {
                        return AppStrings.errorInvalidEmail;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSizes.md),

                  // Department
                  TextFormField(
                    controller: _departmentController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '${AppStrings.department} (선택)',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),

                  // Role
                  DropdownButtonFormField<UserRole>(
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: '역할',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: UserRole.values.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(role.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedRole = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSizes.md),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
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
                  const SizedBox(height: AppSizes.md),

                  // Confirm Password
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleRegister(),
                    decoration: const InputDecoration(
                      labelText: AppStrings.confirmPassword,
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return AppStrings.errorPasswordMismatch;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSizes.lg),

                  // Register Button
                  ElevatedButton(
                    onPressed: (_isSubmitting || userAsync.isLoading)
                        ? null
                        : _handleRegister,
                    child: (_isSubmitting || userAsync.isLoading)
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(AppStrings.register),
                  ),
                  const SizedBox(height: AppSizes.md),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppStrings.hasAccount,
                        style: theme.textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text(AppStrings.login),
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
