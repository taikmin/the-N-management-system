import '../../../../app/supabase_config.dart';
import '../../domain/models/meeting.dart';
import '../../domain/models/meeting_agenda.dart';
import '../../domain/models/meeting_document.dart';
import '../../domain/models/meeting_participant.dart';
import '../../domain/models/meeting_timeline.dart';

/// 회의 관리 Repository
class MeetingRepository {
  final _client = SupabaseConfig.client;

  // ─── Meetings ───

  Future<List<Meeting>> getMeetingsByProject(String projectId) async {
    final data = await _client
        .from('meetings')
        .select('*, profiles!meetings_creator_id_fkey(full_name), projects!meetings_project_id_fkey(title)')
        .eq('project_id', projectId)
        .order('meeting_date', ascending: false);
    return (data as List).map((j) => Meeting.fromJson(j)).toList();
  }

  Future<List<Meeting>> getUpcomingMeetings() async {
    final now = DateTime.now().toIso8601String();
    final data = await _client
        .from('meetings')
        .select('*, profiles!meetings_creator_id_fkey(full_name), projects!meetings_project_id_fkey(title)')
        .gte('meeting_date', now)
        .order('meeting_date');
    return (data as List).map((j) => Meeting.fromJson(j)).toList();
  }

  Future<List<Meeting>> getAllMeetings() async {
    final data = await _client
        .from('meetings')
        .select('*, profiles!meetings_creator_id_fkey(full_name), projects!meetings_project_id_fkey(title)')
        .order('meeting_date', ascending: false);
    return (data as List).map((j) => Meeting.fromJson(j)).toList();
  }

  Future<Meeting> getMeeting(String id) async {
    final data = await _client
        .from('meetings')
        .select('*, profiles!meetings_creator_id_fkey(full_name), projects!meetings_project_id_fkey(title)')
        .eq('id', id)
        .single();
    return Meeting.fromJson(data);
  }

  Future<Meeting> createMeeting(Meeting meeting) async {
    final data = await _client
        .from('meetings')
        .insert(meeting.toInsertJson())
        .select('*, profiles!meetings_creator_id_fkey(full_name), projects!meetings_project_id_fkey(title)')
        .single();
    return Meeting.fromJson(data);
  }

  Future<Meeting> updateMeeting(String id, Meeting meeting) async {
    final data = await _client
        .from('meetings')
        .update(meeting.toUpdateJson())
        .eq('id', id)
        .select('*, profiles!meetings_creator_id_fkey(full_name), projects!meetings_project_id_fkey(title)')
        .single();
    return Meeting.fromJson(data);
  }

  Future<void> deleteMeeting(String id) async {
    await _client.from('meetings').delete().eq('id', id);
  }

  /// 회의록이 있는 회의 목록 (최신순)
  Future<List<Meeting>> getMeetingsWithNotes() async {
    final data = await _client
        .from('meetings')
        .select('*, profiles!meetings_creator_id_fkey(full_name), projects!meetings_project_id_fkey(title)')
        .not('meeting_notes', 'is', null)
        .neq('meeting_notes', '')
        .order('meeting_date', ascending: false)
        .limit(20);
    return (data as List)
        .map((j) => Meeting.fromJson(j))
        .toList();
  }

  /// 회의록 및 원문 저장
  Future<void> saveMeetingNotes(
    String meetingId, {
    required String meetingNotes,
    String? rawTranscript,
  }) async {
    final data = <String, dynamic>{
      'meeting_notes': meetingNotes,
    };
    if (rawTranscript != null) {
      data['raw_transcript'] = rawTranscript;
    }
    await _client
        .from('meetings')
        .update(data)
        .eq('id', meetingId);
  }

  // ─── Participants ───

  Future<List<MeetingParticipant>> getParticipants(String meetingId) async {
    final data = await _client
        .from('meeting_participants')
        .select('*, profiles!meeting_participants_user_id_fkey(full_name, email)')
        .eq('meeting_id', meetingId)
        .order('created_at');
    return (data as List).map((j) => MeetingParticipant.fromJson(j)).toList();
  }

  Future<void> addParticipant(MeetingParticipant p) async {
    await _client.from('meeting_participants').insert(p.toInsertJson());
  }

  Future<void> addParticipants(List<MeetingParticipant> participants) async {
    if (participants.isEmpty) return;
    await _client
        .from('meeting_participants')
        .insert(participants.map((p) => p.toInsertJson()).toList());
  }

  Future<void> updateAttendance(
      String id, AttendanceStatus attendance) async {
    await _client
        .from('meeting_participants')
        .update({'attendance': attendance.dbValue}).eq('id', id);
  }

  Future<void> removeParticipant(String id) async {
    await _client.from('meeting_participants').delete().eq('id', id);
  }

  // ─── Documents ───

  Future<List<MeetingDocument>> getDocuments(String meetingId) async {
    final data = await _client
        .from('meeting_documents')
        .select('*, profiles!meeting_documents_uploader_id_fkey(full_name)')
        .eq('meeting_id', meetingId)
        .order('created_at', ascending: false);
    return (data as List).map((j) => MeetingDocument.fromJson(j)).toList();
  }

  Future<MeetingDocument> createDocument(MeetingDocument doc) async {
    final data = await _client
        .from('meeting_documents')
        .insert(doc.toInsertJson())
        .select('*, profiles!meeting_documents_uploader_id_fkey(full_name)')
        .single();
    return MeetingDocument.fromJson(data);
  }

  Future<void> updateDocumentStatus(
      String id, SubmitStatus status) async {
    await _client
        .from('meeting_documents')
        .update({'submit_status': status.dbValue}).eq('id', id);
  }

  Future<void> deleteDocument(String id) async {
    await _client.from('meeting_documents').delete().eq('id', id);
  }

  // ─── Agenda ───

  Future<List<MeetingAgenda>> getAgenda(String meetingId) async {
    final data = await _client
        .from('meeting_agenda')
        .select('*, profiles!meeting_agenda_presenter_id_fkey(full_name)')
        .eq('meeting_id', meetingId)
        .order('order_index');
    return (data as List).map((j) => MeetingAgenda.fromJson(j)).toList();
  }

  Future<MeetingAgenda> createAgendaItem(MeetingAgenda item) async {
    final data = await _client
        .from('meeting_agenda')
        .insert(item.toInsertJson())
        .select('*, profiles!meeting_agenda_presenter_id_fkey(full_name)')
        .single();
    return MeetingAgenda.fromJson(data);
  }

  Future<void> updateAgendaOrder(
      List<Map<String, dynamic>> updates) async {
    for (final u in updates) {
      await _client
          .from('meeting_agenda')
          .update({'order_index': u['order_index']}).eq('id', u['id']);
    }
  }

  Future<void> deleteAgendaItem(String id) async {
    await _client.from('meeting_agenda').delete().eq('id', id);
  }

  // ─── Timeline ───

  Future<List<MeetingTimeline>> getTimeline(String meetingId) async {
    final data = await _client
        .from('meeting_timeline')
        .select()
        .eq('meeting_id', meetingId)
        .order('sort_order')
        .order('due_date');
    return (data as List).map((j) => MeetingTimeline.fromJson(j)).toList();
  }

  Future<void> createTimeline(List<MeetingTimeline> milestones) async {
    if (milestones.isEmpty) return;
    await _client
        .from('meeting_timeline')
        .insert(milestones.map((m) => m.toInsertJson()).toList());
  }

  Future<void> completeMilestone(String id) async {
    await _client.from('meeting_timeline').update({
      'is_completed': true,
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> toggleMilestone(
    String id, {
    required bool isCompleted,
  }) async {
    await _client.from('meeting_timeline').update({
      'is_completed': isCompleted,
      'completed_at':
          isCompleted ? DateTime.now().toIso8601String() : null,
    }).eq('id', id);
  }

  Future<void> updateMilestone(
    String id, {
    required String label,
    required DateTime dueDate,
  }) async {
    await _client.from('meeting_timeline').update({
      'label': label,
      'due_date': dueDate.toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteMilestone(String id) async {
    await _client
        .from('meeting_timeline')
        .delete()
        .eq('id', id);
  }

  Future<void> addMilestone(MeetingTimeline m) async {
    await _client
        .from('meeting_timeline')
        .insert(m.toInsertJson());
  }

  Future<void> reorderTimeline(
    List<String> orderedIds,
  ) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await _client.from('meeting_timeline').update({
        'sort_order': i,
      }).eq('id', orderedIds[i]);
    }
  }

  /// 최근 회의 목록 + 타임라인 항목 수 (이전 회의 불러오기용)
  Future<List<Map<String, dynamic>>>
      getRecentMeetingsWithTimelineCount({
    String? searchQuery,
    int limit = 20,
  }) async {
    var filter = _client
        .from('meetings')
        .select('id, title, meeting_date, '
            'meeting_timeline(count)');

    if (searchQuery != null &&
        searchQuery.isNotEmpty) {
      filter = filter.ilike(
        'title',
        '%$searchQuery%',
      );
    }

    final data = await filter
        .order('meeting_date', ascending: false)
        .limit(limit);
    return (data as List)
        .cast<Map<String, dynamic>>();
  }
}
