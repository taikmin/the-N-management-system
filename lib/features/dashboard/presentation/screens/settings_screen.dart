import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // 설정 화면 진입 시 최신 프로필(is_admin 포함) 다시 로드
    Future.microtask(() {
      ref.read(currentUserProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSizes.lg),
      children: [
        Text(
          AppStrings.settings,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSizes.lg),

        // Profile Section
        Card(
          child: userAsync.when(
            data: (user) {
              if (user == null) return const SizedBox.shrink();
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0] : '?',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.fullName,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ADMIN',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(user.email),
                trailing: Chip(label: Text(user.role.label)),
              );
            },
            loading: () => const ListTile(
              title: Text('로딩 중...'),
            ),
            error: (e, _) => ListTile(
              title: Text('오류: $e'),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.lg),

        // Admin Panel
        if (userAsync.valueOrNull?.isAdmin == true) ...[
          _AdminPanel(),
          const SizedBox(height: AppSizes.lg),
        ],

        // App Info
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text(AppStrings.appName),
                subtitle: const Text('v0.1.0'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('기술 스택'),
                subtitle: const Text('Flutter + Supabase'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.lg),

        // Logout
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(currentUserProvider.notifier).signOut();
          },
          icon: const Icon(Icons.logout),
          label: const Text(AppStrings.logout),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(color: theme.colorScheme.error),
          ),
        ),
      ],
    );
  }
}

/// Admin 전용 사용자 관리 패널
class _AdminPanel extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends ConsumerState<_AdminPanel> {
  List<Map<String, dynamic>>? _users;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final users = await repo.getAllUsers();
      setState(() => _users = users);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 목록 로딩 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeRole(String userId, UserRole newRole) async {
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.updateUserRole(userId, newRole);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('역할이 변경되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('역할 변경 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.xs),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings,
                    color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  '관리자 패널',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadUsers,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppSizes.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_users == null || _users!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSizes.md),
              child: Text('사용자 없음'),
            )
          else
            ...(_users!.map((u) {
              final role = UserRole.fromString(u['role'] as String? ?? 'staff');
              final isAdmin = u['is_admin'] as bool? ?? false;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    ((u['full_name'] as String?) ?? '?')[0],
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Text(u['full_name'] as String? ?? '이름 없음'),
                    if (isAdmin) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.shield, size: 14, color: AppColors.error),
                    ],
                  ],
                ),
                subtitle: Text(u['email'] as String? ?? ''),
                trailing: PopupMenuButton<UserRole>(
                  tooltip: '역할 변경',
                  child: Chip(
                    label: Text(role.label),
                    visualDensity: VisualDensity.compact,
                  ),
                  onSelected: (newRole) =>
                      _changeRole(u['id'] as String, newRole),
                  itemBuilder: (context) => UserRole.values
                      .map((r) => PopupMenuItem(
                            value: r,
                            child: Row(
                              children: [
                                if (r == role)
                                  const Icon(Icons.check, size: 16)
                                else
                                  const SizedBox(width: 16),
                                const SizedBox(width: 8),
                                Text(r.label),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              );
            })),
        ],
      ),
    );
  }
}
