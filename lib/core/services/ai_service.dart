/// AI 서비스에서 추출한 업무 모델
class ExtractedTask {
  const ExtractedTask({
    required this.title,
    this.assigneeName,
    this.deadline,
    this.priority = 'medium',
    this.description,
    this.projectTitle,
  });

  final String title;
  final String? assigneeName;
  final String? deadline;
  final String priority;
  final String? description;
  final String? projectTitle;

  factory ExtractedTask.fromJson(
    Map<String, dynamic> j,
  ) {
    return ExtractedTask(
      title: j['title'] as String? ?? '제목 없음',
      assigneeName:
          j['assignee_name'] as String?,
      deadline: j['deadline'] as String?,
      priority:
          (j['priority'] as String? ?? 'medium')
              .toLowerCase(),
      description:
          j['description'] as String?,
      projectTitle:
          j['project_title'] as String?,
    );
  }
}

/// AI 회의록 생성 결과
class MeetingMinutesResult {
  const MeetingMinutesResult({
    required this.minutes,
    required this.tasks,
    this.analysisNote,
    this.rawTranscript,
  });

  final String minutes;
  final List<ExtractedTask> tasks;

  /// AI 분석 관련 안내 메시지 (파싱 실패, 유사도 경고 등)
  final String? analysisNote;

  /// 음성 변환 원문 텍스트 (오디오 파일 분석 시)
  final String? rawTranscript;
}

/// AI 서비스 추상 인터페이스
abstract class AiService {
  /// 녹음 원문으로부터 회의록 + 업무 추출
  Future<MeetingMinutesResult> generateMinutes({
    required String transcript,
    String? meetingTitle,
    String? meetingDate,
    String? projectTitle,
    List<String>? teamMemberNames,
    List<Map<String, String>>? projects,
    List<String>? existingTasks,
    void Function(String message)? onRetry,
    void Function(String message)? onProgress,
  });
}
