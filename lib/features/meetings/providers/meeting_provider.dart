import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/supabase_config.dart';
import '../data/repositories/meeting_repository.dart';
import '../domain/models/meeting.dart';
import '../domain/models/meeting_agenda.dart';
import '../domain/models/meeting_document.dart';
import '../domain/models/meeting_participant.dart';
import '../domain/models/meeting_timeline.dart';

final meetingRepositoryProvider = Provider<MeetingRepository>((ref) {
  return MeetingRepository();
});

// ─── Meeting List ───

/// 전체 회의 목록 Provider (Realtime)
final meetingListProvider =
    AsyncNotifierProvider<MeetingListNotifier, List<Meeting>>(
  MeetingListNotifier.new,
);

class MeetingListNotifier extends AsyncNotifier<List<Meeting>> {
  @override
  FutureOr<List<Meeting>> build() async {
    _subscribeToChanges();
    return ref.read(meetingRepositoryProvider).getAllMeetings();
  }

  void _subscribeToChanges() {
    final channel = SupabaseConfig.client.channel('meetings_realtime');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'meetings',
          callback: (_) => _refresh(),
        )
        .subscribe();

    ref.onDispose(() {
      SupabaseConfig.client.removeChannel(channel);
    });
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(meetingRepositoryProvider).getAllMeetings(),
    );
  }

  Future<void> refresh() => _refresh();

  Future<Meeting> createMeeting(Meeting meeting) async {
    final created =
        await ref.read(meetingRepositoryProvider).createMeeting(meeting);
    await _refresh();
    return created;
  }

  Future<void> updateMeeting(String id, Meeting meeting) async {
    await ref.read(meetingRepositoryProvider).updateMeeting(id, meeting);
    await _refresh();
  }

  Future<void> deleteMeeting(String id) async {
    await ref.read(meetingRepositoryProvider).deleteMeeting(id);
    await _refresh();
  }
}

/// 과제별 회의 목록
final projectMeetingsProvider =
    FutureProvider.family<List<Meeting>, String>((ref, projectId) async {
  return ref.read(meetingRepositoryProvider).getMeetingsByProject(projectId);
});

/// 다가오는 회의 (대시보드용)
final upcomingMeetingsProvider = FutureProvider<List<Meeting>>((ref) async {
  return ref.read(meetingRepositoryProvider).getUpcomingMeetings();
});

/// 회의록이 있는 회의 목록 (불러오기용)
final meetingsWithNotesProvider =
    FutureProvider<List<Meeting>>((ref) async {
  return ref
      .read(meetingRepositoryProvider)
      .getMeetingsWithNotes();
});

/// 회의 상세
final meetingDetailProvider =
    FutureProvider.family<Meeting, String>((ref, id) async {
  return ref.read(meetingRepositoryProvider).getMeeting(id);
});

// ─── Participants ───

/// 회의 참석자 목록
final meetingParticipantsProvider =
    AsyncNotifierProvider.family<MeetingParticipantsNotifier,
        List<MeetingParticipant>, String>(
  MeetingParticipantsNotifier.new,
);

class MeetingParticipantsNotifier
    extends FamilyAsyncNotifier<List<MeetingParticipant>, String> {
  @override
  FutureOr<List<MeetingParticipant>> build(String arg) async {
    return ref.read(meetingRepositoryProvider).getParticipants(arg);
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(meetingRepositoryProvider).getParticipants(arg),
    );
  }

  Future<void> addParticipant(MeetingParticipant p) async {
    await ref.read(meetingRepositoryProvider).addParticipant(p);
    await _refresh();
  }

  Future<void> addParticipants(List<MeetingParticipant> participants) async {
    await ref.read(meetingRepositoryProvider).addParticipants(participants);
    await _refresh();
  }

  Future<void> updateAttendance(String id, AttendanceStatus status) async {
    await ref.read(meetingRepositoryProvider).updateAttendance(id, status);
    await _refresh();
  }

  Future<void> removeParticipant(String id) async {
    await ref.read(meetingRepositoryProvider).removeParticipant(id);
    await _refresh();
  }
}

// ─── Documents ───

/// 회의 문서 목록
final meetingDocumentsProvider = AsyncNotifierProvider.family<
    MeetingDocumentsNotifier, List<MeetingDocument>, String>(
  MeetingDocumentsNotifier.new,
);

class MeetingDocumentsNotifier
    extends FamilyAsyncNotifier<List<MeetingDocument>, String> {
  @override
  FutureOr<List<MeetingDocument>> build(String arg) async {
    return ref.read(meetingRepositoryProvider).getDocuments(arg);
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(meetingRepositoryProvider).getDocuments(arg),
    );
  }

  Future<void> createDocument(MeetingDocument doc) async {
    await ref.read(meetingRepositoryProvider).createDocument(doc);
    await _refresh();
  }

  Future<void> updateDocumentStatus(String id, SubmitStatus status) async {
    await ref.read(meetingRepositoryProvider).updateDocumentStatus(id, status);
    await _refresh();
  }

  Future<void> deleteDocument(String id) async {
    await ref.read(meetingRepositoryProvider).deleteDocument(id);
    await _refresh();
  }
}

// ─── Agenda ───

/// 회의 안건 목록
final meetingAgendaProvider = AsyncNotifierProvider.family<
    MeetingAgendaNotifier, List<MeetingAgenda>, String>(
  MeetingAgendaNotifier.new,
);

class MeetingAgendaNotifier
    extends FamilyAsyncNotifier<List<MeetingAgenda>, String> {
  @override
  FutureOr<List<MeetingAgenda>> build(String arg) async {
    return ref.read(meetingRepositoryProvider).getAgenda(arg);
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(meetingRepositoryProvider).getAgenda(arg),
    );
  }

  Future<void> createAgendaItem(MeetingAgenda item) async {
    await ref.read(meetingRepositoryProvider).createAgendaItem(item);
    await _refresh();
  }

  Future<void> updateOrder(List<Map<String, dynamic>> updates) async {
    await ref.read(meetingRepositoryProvider).updateAgendaOrder(updates);
    await _refresh();
  }

  Future<void> deleteAgendaItem(String id) async {
    await ref.read(meetingRepositoryProvider).deleteAgendaItem(id);
    await _refresh();
  }
}

// ─── Timeline ───

/// 회의 타임라인 목록
final meetingTimelineProvider = AsyncNotifierProvider.family<
    MeetingTimelineNotifier, List<MeetingTimeline>, String>(
  MeetingTimelineNotifier.new,
);

class MeetingTimelineNotifier
    extends FamilyAsyncNotifier<List<MeetingTimeline>, String> {
  @override
  FutureOr<List<MeetingTimeline>> build(String arg) async {
    return ref.read(meetingRepositoryProvider).getTimeline(arg);
  }

  Future<void> _refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(meetingRepositoryProvider).getTimeline(arg),
    );
  }

  Future<void> createTimeline(List<MeetingTimeline> milestones) async {
    await ref.read(meetingRepositoryProvider).createTimeline(milestones);
    await _refresh();
  }

  Future<void> completeMilestone(String id) async {
    await ref.read(meetingRepositoryProvider).completeMilestone(id);
    await _refresh();
  }

  Future<void> toggleMilestone(
    String id, {
    required bool isCompleted,
  }) async {
    await ref
        .read(meetingRepositoryProvider)
        .toggleMilestone(id, isCompleted: isCompleted);
    await _refresh();
  }

  Future<void> updateMilestone(
    String id, {
    required String label,
    required DateTime dueDate,
  }) async {
    await ref
        .read(meetingRepositoryProvider)
        .updateMilestone(id, label: label, dueDate: dueDate);
    await _refresh();
  }

  Future<void> deleteMilestone(String id) async {
    await ref.read(meetingRepositoryProvider).deleteMilestone(id);
    await _refresh();
  }

  Future<void> addMilestone(MeetingTimeline m) async {
    await ref.read(meetingRepositoryProvider).addMilestone(m);
    await _refresh();
  }

  Future<void> reorderTimeline(
    List<String> orderedIds,
  ) async {
    await ref
        .read(meetingRepositoryProvider)
        .reorderTimeline(orderedIds);
    await _refresh();
  }
}

// ─── Filters & Sort ───

/// 회의 정렬 종류
enum MeetingSort {
  byMeetingDate('회의일순'),
  newest('최신등록순'),
  oldest('오래된순'),
  byCreator('게시자별'),
  byType('유형별');

  const MeetingSort(this.label);
  final String label;
}

/// 회의 상태 필터
final meetingStatusFilterProvider =
    StateProvider<MeetingStatus?>((ref) => null);

/// 회의 검색어
final meetingSearchQueryProvider = StateProvider<String>((ref) => '');

/// 회의 정렬
final meetingSortProvider =
    StateProvider<MeetingSort>((ref) => MeetingSort.byMeetingDate);

/// 필터링된 회의 목록
final filteredMeetingListProvider =
    Provider<AsyncValue<List<Meeting>>>((ref) {
  final meetingsAsync = ref.watch(meetingListProvider);
  final statusFilter = ref.watch(meetingStatusFilterProvider);
  final searchQuery = ref.watch(meetingSearchQueryProvider).toLowerCase();
  final sort = ref.watch(meetingSortProvider);

  return meetingsAsync.whenData((meetings) {
    var filtered = meetings;

    if (statusFilter != null) {
      filtered = filtered.where((m) => m.status == statusFilter).toList();
    }

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((m) {
        return m.title.toLowerCase().contains(searchQuery) ||
            (m.projectTitle?.toLowerCase().contains(searchQuery) ?? false) ||
            (m.location?.toLowerCase().contains(searchQuery) ?? false) ||
            (m.creatorName?.toLowerCase().contains(searchQuery) ?? false);
      }).toList();
    }

    // 정렬 적용
    switch (sort) {
      case MeetingSort.byMeetingDate:
        filtered.sort((a, b) => a.meetingDate.compareTo(b.meetingDate));
      case MeetingSort.newest:
        filtered.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
      case MeetingSort.oldest:
        filtered.sort((a, b) => (a.createdAt ?? DateTime(0))
            .compareTo(b.createdAt ?? DateTime(0)));
      case MeetingSort.byCreator:
        filtered.sort((a, b) =>
            (a.creatorName ?? '').compareTo(b.creatorName ?? ''));
      case MeetingSort.byType:
        filtered.sort((a, b) =>
            a.meetingType.label.compareTo(b.meetingType.label));
    }

    return filtered;
  });
});
