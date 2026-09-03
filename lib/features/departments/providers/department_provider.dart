import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/supabase_config.dart';
import '../data/repositories/department_repository.dart';
import '../domain/models/department.dart';

final departmentRepositoryProvider = Provider<DepartmentRepository>((ref) {
  return DepartmentRepository();
});

/// 부서 목록 Provider (Realtime 구독)
final departmentListProvider =
    AsyncNotifierProvider<DepartmentListNotifier, List<Department>>(
  DepartmentListNotifier.new,
);

class DepartmentListNotifier extends AsyncNotifier<List<Department>> {
  @override
  FutureOr<List<Department>> build() async {
    _subscribeToChanges();
    return ref.read(departmentRepositoryProvider).getAll();
  }

  void _subscribeToChanges() {
    final channel = SupabaseConfig.client.channel('departments_realtime');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'departments',
          callback: (_) => _refresh(),
        )
        .subscribe();

    ref.onDispose(() {
      SupabaseConfig.client.removeChannel(channel);
    });
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(departmentRepositoryProvider).getAll(),
    );
  }

  Future<void> refresh() => _refresh();

  Future<void> create(Department d) async {
    await ref.read(departmentRepositoryProvider).create(d);
    await _refresh();
  }

  Future<void> updateDepartment(String id, Department d) async {
    await ref.read(departmentRepositoryProvider).update(id, d);
    await _refresh();
  }

  Future<void> deleteDepartment(String id) async {
    await ref.read(departmentRepositoryProvider).delete(id);
    await _refresh();
  }
}

/// 부서 상세 Provider
final departmentDetailProvider =
    FutureProvider.family<Department, String>((ref, id) async {
  return ref.read(departmentRepositoryProvider).get(id);
});

/// 부서별 업무 통계
final departmentTaskStatsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, deptId) async {
  return ref.read(departmentRepositoryProvider).getTaskStats(deptId);
});

/// 부서 소속 직원 목록
final departmentMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, deptId) async {
  return ref.read(departmentRepositoryProvider).getMembers(deptId);
});
