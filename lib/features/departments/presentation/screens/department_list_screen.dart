import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/department_provider.dart';
import '../widgets/department_card.dart';

/// 부서 목록 화면
class DepartmentListScreen extends ConsumerWidget {
  const DepartmentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departmentsAsync = ref.watch(departmentListProvider);
    final canManage = ref.watch(isManagementProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('부서'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(departmentListProvider.notifier).refresh(),
          ),
        ],
      ),
      body: departmentsAsync.when(
        data: (departments) {
          if (departments.isEmpty) {
            return const Center(child: Text('등록된 부서가 없습니다'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSizes.md),
            itemCount: departments.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
            itemBuilder: (context, index) {
              final d = departments[index];
              return DepartmentCard(
                department: d,
                onTap: () => context.push('/departments/${d.id}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/departments/create'),
              icon: const Icon(Icons.add),
              label: const Text('부서 추가'),
            )
          : null,
    );
  }
}
