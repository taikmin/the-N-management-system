import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/repositories/activity_repository.dart';
import '../domain/models/activity_log.dart';

/// Repository provider
final activityRepositoryProvider =
    Provider<ActivityRepository>((ref) {
  return ActivityRepository(
    Supabase.instance.client,
  );
});

/// 대시보드용 최근 활동 (24시간, 10건)
final dashboardActivitiesProvider =
    FutureProvider<List<ActivityLog>>((ref) async {
  final repo = ref.watch(activityRepositoryProvider);
  return repo.getDashboardActivities();
});

/// 활동 필터
final activityFilterProvider =
    StateProvider<ActivityFilter>(
  (ref) => ActivityFilter.all,
);

/// 전체 활동 로그 (필터 적용)
final activityListProvider =
    FutureProvider<List<ActivityLog>>((ref) async {
  final repo = ref.watch(activityRepositoryProvider);
  final filter = ref.watch(activityFilterProvider);
  return repo.getActivities(
    entityType: filter.entityType,
    limit: 100,
  );
});

/// Realtime 활동 스트림 (대시보드, 24시간 이내만)
final activityStreamProvider =
    StreamProvider<List<ActivityLog>>((ref) {
  final client = Supabase.instance.client;
  return client
      .from('activity_logs')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(30)
      .map((data) {
    final cutoff =
        DateTime.now().subtract(const Duration(hours: 24));
    return data
        .map((json) => ActivityLog.fromJson(json))
        .where((log) => log.createdAt.isAfter(cutoff))
        .take(10)
        .toList();
  });
});
