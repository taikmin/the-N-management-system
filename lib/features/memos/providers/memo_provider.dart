import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/supabase_config.dart';
import '../data/repositories/memo_repository.dart';
import '../domain/models/memo.dart';

final memoRepositoryProvider =
    Provider<MemoRepository>((ref) => MemoRepository());

/// 메모 필터
final memoFilterProvider =
    StateProvider<MemoFilter>((ref) => MemoFilter.all);

/// 메모 검색어
final memoSearchQueryProvider =
    StateProvider<String>((ref) => '');

/// 내 모든 메모 Provider (Realtime)
final myMemosProvider =
    AsyncNotifierProvider<MyMemosNotifier, List<Memo>>(
  MyMemosNotifier.new,
);

class MyMemosNotifier extends AsyncNotifier<List<Memo>> {
  @override
  FutureOr<List<Memo>> build() async {
    _subscribe();
    return ref
        .read(memoRepositoryProvider)
        .getMyMemos();
  }

  void _subscribe() {
    final userId =
        SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return;

    final channel =
        SupabaseConfig.client.channel('my_memos');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'memos',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _refresh(),
        )
        .subscribe();

    ref.onDispose(() {
      SupabaseConfig.client.removeChannel(channel);
    });
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(
      () => ref
          .read(memoRepositoryProvider)
          .getMyMemos(),
    );
  }

  Future<void> refresh() => _refresh();

  Future<Memo> quickCreate(String title) async {
    final memo = await ref
        .read(memoRepositoryProvider)
        .quickCreate(title);
    await _refresh();
    return memo;
  }

  Future<void> togglePin(
      String id, bool currentPin) async {
    await ref
        .read(memoRepositoryProvider)
        .togglePin(id, currentPin);
    await _refresh();
  }

  Future<void> archiveMemo(String id) async {
    await ref
        .read(memoRepositoryProvider)
        .archiveMemo(id);
    await _refresh();
  }

  Future<void> unarchiveMemo(String id) async {
    await ref
        .read(memoRepositoryProvider)
        .unarchiveMemo(id);
    await _refresh();
  }

  Future<void> deleteMemo(String id) async {
    await ref
        .read(memoRepositoryProvider)
        .deleteMemo(id);
    await _refresh();
  }

  Future<Memo> createMemo(Memo memo) async {
    final created = await ref
        .read(memoRepositoryProvider)
        .createMemo(memo);
    await _refresh();
    return created;
  }

  Future<Memo> updateMemo(
      String id, Memo memo) async {
    final updated = await ref
        .read(memoRepositoryProvider)
        .updateMemo(id, memo);
    await _refresh();
    return updated;
  }
}

/// 필터 적용된 메모 목록
final filteredMemosProvider =
    Provider<AsyncValue<List<Memo>>>((ref) {
  final memosAsync = ref.watch(myMemosProvider);
  final filter = ref.watch(memoFilterProvider);
  final searchQuery =
      ref.watch(memoSearchQueryProvider).toLowerCase();

  return memosAsync.whenData((memos) {
    List<Memo> filtered;
    switch (filter) {
      case MemoFilter.all:
        filtered = memos
            .where(
                (m) => m.status == MemoStatus.active)
            .toList();
      case MemoFilter.idea:
        filtered = memos
            .where((m) =>
                m.status == MemoStatus.active &&
                m.category == '아이디어')
            .toList();
      case MemoFilter.memo:
        filtered = memos
            .where((m) =>
                m.status == MemoStatus.active &&
                m.category == '메모')
            .toList();
      case MemoFilter.todo:
        filtered = memos
            .where((m) =>
                m.status == MemoStatus.active &&
                m.category == '할일')
            .toList();
      case MemoFilter.archived:
        filtered = memos
            .where(
                (m) => m.status == MemoStatus.archived)
            .toList();
    }

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((m) {
        return m.title
                .toLowerCase()
                .contains(searchQuery) ||
            m.content
                .toLowerCase()
                .contains(searchQuery) ||
            (m.category
                    ?.toLowerCase()
                    .contains(searchQuery) ??
                false);
      }).toList();
    }

    return filtered;
  });
});

/// 대시보드용 최근 메모
final recentMemosProvider =
    FutureProvider<List<Memo>>((ref) async {
  try {
    return await ref
        .read(memoRepositoryProvider)
        .getRecentMemos(limit: 3);
  } catch (_) {
    // memos 테이블 미생성 또는 미인증 시 빈 목록 반환
    return [];
  }
});

/// 메모 상세
final memoDetailProvider =
    FutureProvider.family<Memo, String>(
  (ref, id) async {
    return ref
        .read(memoRepositoryProvider)
        .getMemo(id);
  },
);
