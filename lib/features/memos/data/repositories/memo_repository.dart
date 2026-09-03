import '../../../../app/supabase_config.dart';
import '../../domain/models/memo.dart';

/// 메모 Repository
class MemoRepository {
  final _client = SupabaseConfig.client;

  String get _userId {
    final id = SupabaseConfig.auth.currentUser?.id;
    if (id == null) throw Exception('로그인이 필요합니다');
    return id;
  }

  /// 내 메모 목록 (고정 메모 상단, 최신순)
  Future<List<Memo>> getMyMemos({
    MemoStatus? status,
  }) async {
    var query = _client
        .from('memos')
        .select()
        .eq('user_id', _userId);

    if (status != null) {
      query = query.eq('status', status.name);
    }

    final data = await query
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);

    return (data as List)
        .map((j) => Memo.fromJson(j))
        .toList();
  }

  /// 최근 메모 (대시보드용 — 고정 우선, 최대 N건)
  Future<List<Memo>> getRecentMemos({
    int limit = 3,
  }) async {
    final data = await _client
        .from('memos')
        .select()
        .eq('user_id', _userId)
        .eq('status', 'active')
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List)
        .map((j) => Memo.fromJson(j))
        .toList();
  }

  /// 메모 상세 조회
  Future<Memo> getMemo(String id) async {
    final data = await _client
        .from('memos')
        .select()
        .eq('id', id)
        .single();
    return Memo.fromJson(data);
  }

  /// 빠른 메모 생성 (제목만)
  Future<Memo> quickCreate(String title) async {
    final data = await _client
        .from('memos')
        .insert({
          'user_id': _userId,
          'title': title,
        })
        .select()
        .single();
    return Memo.fromJson(data);
  }

  /// 메모 생성
  Future<Memo> createMemo(Memo memo) async {
    final data = await _client
        .from('memos')
        .insert(memo.toInsertJson())
        .select()
        .single();
    return Memo.fromJson(data);
  }

  /// 메모 수정
  Future<Memo> updateMemo(
      String id, Memo memo) async {
    final data = await _client
        .from('memos')
        .update(memo.toUpdateJson())
        .eq('id', id)
        .select()
        .single();
    return Memo.fromJson(data);
  }

  /// 고정 토글
  Future<void> togglePin(
      String id, bool currentPin) async {
    await _client
        .from('memos')
        .update({'is_pinned': !currentPin})
        .eq('id', id);
  }

  /// 보관 처리
  Future<void> archiveMemo(String id) async {
    await _client
        .from('memos')
        .update({'status': 'archived'})
        .eq('id', id);
  }

  /// 보관 해제
  Future<void> unarchiveMemo(String id) async {
    await _client
        .from('memos')
        .update({'status': 'active'})
        .eq('id', id);
  }

  /// 메모 삭제
  Future<void> deleteMemo(String id) async {
    await _client
        .from('memos')
        .delete()
        .eq('id', id);
  }
}
