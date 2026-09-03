import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/activity_log.dart';

class ActivityRepository {
  ActivityRepository(this._client);
  final SupabaseClient _client;

  /// 최근 활동 조회
  Future<List<ActivityLog>> getRecentActivities({
    Duration period = const Duration(hours: 24),
    String? entityType,
    int limit = 50,
  }) async {
    final since = DateTime.now()
        .subtract(period)
        .toUtc()
        .toIso8601String();

    var query = _client
        .from('activity_logs')
        .select()
        .gte('created_at', since);

    if (entityType != null) {
      query = query.eq('entity_type', entityType);
    }

    final data = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List)
        .map((json) => ActivityLog.fromJson(
            json as Map<String, dynamic>))
        .toList();
  }

  /// 전체 활동 로그 (페이지네이션)
  Future<List<ActivityLog>> getActivities({
    String? entityType,
    int offset = 0,
    int limit = 30,
  }) async {
    var query = _client.from('activity_logs').select();

    if (entityType != null) {
      query = query.eq('entity_type', entityType);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List)
        .map((json) => ActivityLog.fromJson(
            json as Map<String, dynamic>))
        .toList();
  }

  /// 대시보드용 최근 활동 (10건)
  Future<List<ActivityLog>> getDashboardActivities() {
    return getRecentActivities(
      period: const Duration(hours: 24),
      limit: 10,
    );
  }

  /// Realtime 구독
  RealtimeChannel subscribeToActivities(
    void Function(List<ActivityLog>) onData,
  ) {
    return _client
        .from('activity_logs')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(10)
        .listen((data) {
          final logs = data
              .map((json) => ActivityLog.fromJson(json))
              .toList();
          onData(logs);
        })
        .cancel as RealtimeChannel;
  }
}
