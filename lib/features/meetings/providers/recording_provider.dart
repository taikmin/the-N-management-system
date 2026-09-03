import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/supabase_config.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/gemini_service.dart';
import '../data/services/speech_service.dart';

/// 녹음 상태
class RecordingState {
  const RecordingState({
    this.isActivated = false,
    this.speechState = SpeechState.idle,
    this.transcriptLines = const [],
    this.interimText = '',
    this.elapsedSeconds = 0,
    this.isGenerating = false,
    this.minutesResult,
    this.error,
    this.retryMessage,
    this.progressMessage,
    this.meetingId,
  });

  final bool isActivated;
  final SpeechState speechState;
  final List<String> transcriptLines;
  final String interimText;
  final int elapsedSeconds;
  final bool isGenerating;
  final MeetingMinutesResult? minutesResult;
  final String? error;
  final String? retryMessage;
  final String? progressMessage;
  final String? meetingId;

  bool get isRecording =>
      speechState == SpeechState.listening;
  bool get isPaused =>
      speechState == SpeechState.paused;
  bool get isIdle => speechState == SpeechState.idle;

  /// 대기 상태: 활성화됨, 아직 녹음 안 함, 텍스트 없음
  bool get isWaiting =>
      isActivated &&
      isIdle &&
      transcriptLines.isEmpty &&
      !isGenerating &&
      minutesResult == null;

  /// 녹음 완료 상태: 중지됨, 텍스트 있음, 아직 회의록 미생성
  bool get isStopped =>
      isIdle &&
      transcriptLines.isNotEmpty &&
      !isGenerating &&
      minutesResult == null;

  /// 플로팅 위젯 표시 여부
  bool get isFloatingVisible =>
      isActivated ||
      speechState != SpeechState.idle ||
      isGenerating ||
      (transcriptLines.isNotEmpty &&
          minutesResult == null);

  String get fullTranscript =>
      transcriptLines.join('\n');

  String get formattedTime {
    final h = elapsedSeconds ~/ 3600;
    final m = (elapsedSeconds % 3600) ~/ 60;
    final s = elapsedSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  RecordingState copyWith({
    bool? isActivated,
    SpeechState? speechState,
    List<String>? transcriptLines,
    String? interimText,
    int? elapsedSeconds,
    bool? isGenerating,
    MeetingMinutesResult? Function()? minutesResult,
    String? Function()? error,
    String? Function()? retryMessage,
    String? Function()? progressMessage,
    String? Function()? meetingId,
  }) {
    return RecordingState(
      isActivated:
          isActivated ?? this.isActivated,
      speechState:
          speechState ?? this.speechState,
      transcriptLines:
          transcriptLines ?? this.transcriptLines,
      interimText:
          interimText ?? this.interimText,
      elapsedSeconds:
          elapsedSeconds ?? this.elapsedSeconds,
      isGenerating:
          isGenerating ?? this.isGenerating,
      minutesResult: minutesResult != null
          ? minutesResult()
          : this.minutesResult,
      error: error != null ? error() : this.error,
      retryMessage: retryMessage != null
          ? retryMessage()
          : this.retryMessage,
      progressMessage: progressMessage != null
          ? progressMessage()
          : this.progressMessage,
      meetingId: meetingId != null
          ? meetingId()
          : this.meetingId,
    );
  }
}

/// 녹음 Notifier (전역 — autoDispose 없음)
class RecordingNotifier
    extends StateNotifier<RecordingState> {
  RecordingNotifier()
      : super(const RecordingState());

  SpeechService? _speechService;
  Timer? _timer;
  final List<StreamSubscription> _subs = [];

  // 회의 컨텍스트 (회의록 생성 시 사용)
  String? _meetingTitle;
  String? _meetingDate;
  String? _projectTitle;

  /// 미완료 기존 업무 목록 조회 (중복 방지용)
  Future<List<String>> _fetchExistingTasks() async {
    try {
      final client = SupabaseConfig.client;
      final data = await client
          .from('tasks')
          .select(
            'title, '
            'profiles!tasks_assignee_id_fkey'
            '(full_name), '
            'projects!tasks_project_id_fkey'
            '(title)',
          )
          .neq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(100);

      return (data as List).map((t) {
        final projMap = t['projects']
            as Map<String, dynamic>?;
        final assigneeMap = t['profiles']
            as Map<String, dynamic>?;
        final title = t['title'] as String? ?? '';
        final projTitle =
            projMap?['title'] as String?;
        final assigneeName =
            assigneeMap?['full_name'] as String?;

        final parts = <String>[];
        if (projTitle != null &&
            projTitle.isNotEmpty) {
          parts.add('[$projTitle]');
        }
        parts.add(title);
        if (assigneeName != null &&
            assigneeName.isNotEmpty) {
          parts.add('(담당: $assigneeName)');
        }
        return parts.join(' ');
      }).toList();
    } catch (_) {
      return [];
    }
  }

  bool get isSupported {
    _speechService ??= SpeechService();
    return _speechService!.isSupported;
  }

  /// 플로팅 바 활성화 (대기 상태)
  void activate({
    String? meetingId,
    String? meetingTitle,
    String? meetingDate,
    String? projectTitle,
  }) {
    state = state.copyWith(isActivated: true);
    if (meetingId != null) {
      state = state.copyWith(
        meetingId: () => meetingId,
      );
    }
    _meetingTitle = meetingTitle;
    _meetingDate = meetingDate;
    _projectTitle = projectTitle;
  }

  /// 녹음 시작
  void startRecording({
    String? meetingId,
    String? meetingTitle,
    String? meetingDate,
    String? projectTitle,
  }) {
    _speechService ??= SpeechService();

    if (!_speechService!.isSupported) {
      state = state.copyWith(
        isActivated: true,
        error: () =>
            '이 브라우저는 음성 인식을 지원하지 않습니다. '
            'Chrome 또는 Edge를 사용해주세요.',
      );
      return;
    }

    // 회의 컨텍스트 저장
    state = state.copyWith(isActivated: true);
    if (meetingId != null) {
      state = state.copyWith(
        meetingId: () => meetingId,
      );
    }
    if (meetingTitle != null) {
      _meetingTitle = meetingTitle;
    }
    if (meetingDate != null) {
      _meetingDate = meetingDate;
    }
    if (projectTitle != null) {
      _projectTitle = projectTitle;
    }

    // 이미 구독 중이면 중복 방지
    if (_subs.isEmpty) {
      _subs.add(
        _speechService!.onTranscript
            .listen((text) {
          if (text.isNotEmpty) {
            state = state.copyWith(
              transcriptLines: [
                ...state.transcriptLines,
                text,
              ],
              interimText: '',
            );
          } else {
            state = state.copyWith(
              interimText:
                  _speechService!.interimText,
            );
          }
        }),
      );

      _subs.add(
        _speechService!.onStateChange.listen((s) {
          state = state.copyWith(speechState: s);
        }),
      );

      _subs.add(
        _speechService!.onError.listen((e) {
          state = state.copyWith(error: () => e);
        }),
      );
    }

    // 타이머 시작 (없을 때만)
    _timer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (state.isRecording) {
          state = state.copyWith(
            elapsedSeconds:
                state.elapsedSeconds + 1,
          );
        }
      },
    );

    _speechService!.start();
  }

  /// 일시 정지
  void pauseRecording() {
    _speechService?.pause();
  }

  /// 재개
  void resumeRecording() {
    _speechService?.resume();
  }

  /// 녹음 중지
  void stopRecording() {
    _speechService?.stop();
    _timer?.cancel();
    _timer = null;
  }

  /// 수동 텍스트 추가
  void addManualText(String text) {
    if (text.trim().isEmpty) return;
    state = state.copyWith(
      transcriptLines: [
        ...state.transcriptLines,
        '[수동] $text',
      ],
    );
  }

  /// AI 회의록 생성 (재시도 메시지 콜백 포함)
  Future<void> generateMinutes({
    String? meetingTitle,
    String? meetingDate,
    String? projectTitle,
  }) async {
    if (state.fullTranscript.trim().isEmpty) {
      state = state.copyWith(
        error: () => '녹음 텍스트가 없습니다',
      );
      return;
    }

    // 녹음 중이면 먼저 중지
    if (state.isRecording) {
      stopRecording();
    }

    state = state.copyWith(
      isGenerating: true,
      error: () => null,
      retryMessage: () => null,
      progressMessage: () =>
          'AI 회의록 분석을 준비 중입니다...',
    );

    try {
      final now = DateTime.now();
      final title = meetingTitle ??
          _meetingTitle ??
          '업무점검 회의 '
              '(${now.year}.'
              '${now.month.toString().padLeft(2, '0')}.'
              '${now.day.toString().padLeft(2, '0')})';
      final date = meetingDate ??
          _meetingDate ??
          '${now.year}.'
              '${now.month.toString().padLeft(2, '0')}.'
              '${now.day.toString().padLeft(2, '0')}';

      // Supabase에서 팀원 이름 + 프로젝트 조회
      final client = SupabaseConfig.client;
      List<String> teamNames = [];
      List<Map<String, String>> projects = [];

      try {
        final usersData = await client
            .from('profiles')
            .select('full_name');
        teamNames = (usersData as List)
            .map(
              (u) =>
                  u['full_name'] as String? ??
                  '',
            )
            .where((n) => n.isNotEmpty)
            .toList();
      } catch (_) {
        // 이름 조회 실패해도 계속 진행
      }

      try {
        final projData = await client
            .from('projects')
            .select(
              'id, title, description, '
              'profiles!projects_owner_id_fkey'
              '(full_name), '
              'assignee:profiles!'
              'projects_assignee_id_fkey'
              '(full_name)',
            )
            .inFilter('status', [
          'active',
          'planning',
        ]);
        projects = (projData as List)
            .map(
              (p) {
                final ownerMap = p['profiles']
                    as Map<String, dynamic>?;
                final assigneeMap =
                    p['assignee']
                        as Map<String,
                            dynamic>?;
                return <String, String>{
                  'id': p['id'] as String,
                  'title':
                      p['title'] as String? ??
                          '',
                  'description':
                      p['description']
                              as String? ??
                          '',
                  'owner_name':
                      ownerMap?['full_name']
                              as String? ??
                          '',
                  'assignee_name':
                      assigneeMap?['full_name']
                              as String? ??
                          '',
                };
              },
            )
            .toList();
      } catch (_) {
        // 프로젝트 조회 실패해도 계속 진행
      }

      // 기존 업무 목록 조회 (중복 방지)
      final existingTasks =
          await _fetchExistingTasks();

      final ai = GeminiService();
      final result = await ai.generateMinutes(
        transcript: state.fullTranscript,
        meetingTitle: title,
        meetingDate: date,
        projectTitle:
            projectTitle ?? _projectTitle,
        teamMemberNames: teamNames,
        projects: projects,
        existingTasks: existingTasks,
        onRetry: (message) {
          state = state.copyWith(
            retryMessage: () => message,
          );
        },
        onProgress: (message) {
          state = state.copyWith(
            progressMessage: () => message,
          );
        },
      );

      state = state.copyWith(
        isGenerating: false,
        minutesResult: () => result,
        retryMessage: () => null,
        progressMessage: () => null,
      );
    } catch (e) {
      final errMsg = e.toString();
      String userMessage;
      if (errMsg.contains('SocketException') ||
          errMsg.contains('ClientException') ||
          errMsg.contains('Connection')) {
        userMessage =
            '네트워크 연결을 확인해주세요. '
            '인터넷에 연결된 상태에서 다시 시도하세요.';
      } else if (errMsg
          .contains('GEMINI_API_KEY')) {
        userMessage =
            'AI API 키가 설정되지 않았습니다. '
            '관리자에게 문의하세요.';
      } else {
        // API 응답 본문 제거 (API 키 노출 방지)
        final cleanMsg =
            errMsg.replaceAll(RegExp(r'key=\S+'), 'key=***');
        userMessage =
            'AI 회의록 생성 실패: $cleanMsg';
      }
      state = state.copyWith(
        isGenerating: false,
        retryMessage: () => null,
        progressMessage: () => null,
        error: () => userMessage,
      );
    }
  }

  /// 저장된 회의록에서 업무만 추출
  Future<void> extractTasksFromMinutes({
    required String minutesText,
    required String meetingId,
    String? meetingTitle,
    String? meetingDate,
    String? rawTranscript,
  }) async {
    state = state.copyWith(
      isActivated: true,
      isGenerating: true,
      minutesResult: () => null,
      error: () => null,
      meetingId: () => meetingId,
      progressMessage: () =>
          '회의록에서 업무를 추출하고 있습니다...',
    );

    try {
      // Supabase에서 팀원 이름 + 프로젝트 조회
      final client = SupabaseConfig.client;
      List<String> teamNames = [];
      List<Map<String, String>> projects = [];

      try {
        final usersData = await client
            .from('profiles')
            .select('full_name');
        teamNames = (usersData as List)
            .map(
              (u) =>
                  u['full_name'] as String? ?? '',
            )
            .where((n) => n.isNotEmpty)
            .toList();
      } catch (_) {}

      try {
        final projData = await client
            .from('projects')
            .select(
              'id, title, description, '
              'profiles!projects_owner_id_fkey'
              '(full_name), '
              'assignee:profiles!'
              'projects_assignee_id_fkey'
              '(full_name)',
            )
            .inFilter('status', [
          'active',
          'planning',
        ]);
        projects = (projData as List)
            .map(
              (p) {
                final ownerMap = p['profiles']
                    as Map<String, dynamic>?;
                final assigneeMap =
                    p['assignee']
                        as Map<String,
                            dynamic>?;
                return <String, String>{
                  'id': p['id'] as String,
                  'title':
                      p['title'] as String? ?? '',
                  'description':
                      p['description']
                              as String? ??
                          '',
                  'owner_name':
                      ownerMap?['full_name']
                              as String? ??
                          '',
                  'assignee_name':
                      assigneeMap?['full_name']
                              as String? ??
                          '',
                };
              },
            )
            .toList();
      } catch (_) {}

      // 기존 업무 목록 조회 (중복 방지)
      final existingTasks =
          await _fetchExistingTasks();

      // raw_transcript가 있으면 그것을 사용
      // (더 정확한 업무 추출)
      final textToAnalyze =
          rawTranscript?.isNotEmpty == true
              ? rawTranscript!
              : minutesText;

      final ai = GeminiService();
      final tasks =
          await ai.extractTasksFromMinutes(
        minutesText: textToAnalyze,
        meetingTitle: meetingTitle,
        meetingDate: meetingDate,
        teamMemberNames: teamNames,
        projects: projects,
        existingTasks: existingTasks,
        onRetry: (message) {
          state = state.copyWith(
            retryMessage: () => message,
          );
        },
        onProgress: (message) {
          state = state.copyWith(
            progressMessage: () => message,
          );
        },
      );

      // minutesResult에 기존 회의록 + 추출된 업무 설정
      state = state.copyWith(
        isGenerating: false,
        minutesResult: () => MeetingMinutesResult(
          minutes: minutesText,
          tasks: tasks,
          analysisNote: tasks.isEmpty
              ? '회의록에서 추출된 업무가 없습니다.'
              : null,
        ),
        retryMessage: () => null,
        progressMessage: () => null,
      );
    } catch (e) {
      final errMsg = e.toString();
      String userMessage;
      if (errMsg.contains('SocketException') ||
          errMsg.contains('ClientException') ||
          errMsg.contains('Connection')) {
        userMessage =
            '네트워크 연결을 확인해주세요.';
      } else if (errMsg
          .contains('GEMINI_API_KEY')) {
        userMessage =
            'AI API 키가 설정되지 않았습니다. '
            '관리자에게 문의하세요.';
      } else {
        final cleanMsg = errMsg.replaceAll(
          RegExp(r'key=\S+'),
          'key=***',
        );
        userMessage =
            '업무 추출 실패: $cleanMsg';
      }
      state = state.copyWith(
        isGenerating: false,
        retryMessage: () => null,
        progressMessage: () => null,
        error: () => userMessage,
      );
    }
  }

  /// 기존 회의록 AI 재작성 (raw_transcript 기반)
  Future<void> regenerateMinutes({
    required String rawTranscript,
    String? meetingId,
    String? meetingTitle,
    String? meetingDate,
    String? projectTitle,
  }) async {
    // 상태에 원문 텍스트 설정 + 이전 결과 초기화
    state = state.copyWith(
      isActivated: true,
      transcriptLines:
          rawTranscript.split('\n'),
      minutesResult: () => null,
      error: () => null,
      meetingId: () => meetingId,
    );
    _meetingTitle = meetingTitle;
    _meetingDate = meetingDate;
    _projectTitle = projectTitle;

    // 기존 생성 로직 재사용
    await generateMinutes(
      meetingTitle: meetingTitle,
      meetingDate: meetingDate,
      projectTitle: projectTitle,
    );
  }

  /// 외부 오디오 파일로 회의록 생성
  Future<void> processAudioFile({
    required Uint8List audioBytes,
    required String fileName,
    String? meetingId,
    String? meetingTitle,
    String? meetingDate,
    String? projectTitle,
  }) async {
    // 녹음 중이면 먼저 중지
    if (state.isRecording || state.isPaused) {
      stopRecording();
    }

    // mimeType 결정
    final ext =
        fileName.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'm4a' => 'audio/mp4',
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      'flac' => 'audio/flac',
      'aac' => 'audio/aac',
      'webm' => 'audio/webm',
      _ => 'audio/mpeg',
    };

    state = state.copyWith(
      isActivated: true,
      isGenerating: true,
      transcriptLines: [],
      meetingId: () => meetingId,
      error: () => null,
      retryMessage: () => null,
      progressMessage: () =>
          '오디오 파일 분석을 준비 중입니다...',
    );

    _meetingTitle = meetingTitle;
    _meetingDate = meetingDate;
    _projectTitle = projectTitle;

    try {
      final now = DateTime.now();
      final title = meetingTitle ??
          '오디오 회의록 '
              '(${now.year}.'
              '${now.month.toString().padLeft(2, '0')}.'
              '${now.day.toString().padLeft(2, '0')})';
      final date = meetingDate ??
          '${now.year}.'
              '${now.month.toString().padLeft(2, '0')}.'
              '${now.day.toString().padLeft(2, '0')}';

      // 팀원 이름 + 프로젝트 조회
      final client = SupabaseConfig.client;
      List<String> teamNames = [];
      List<Map<String, String>> projects = [];

      try {
        final usersData = await client
            .from('profiles')
            .select('full_name');
        teamNames = (usersData as List)
            .map(
              (u) =>
                  u['full_name'] as String? ??
                  '',
            )
            .where((n) => n.isNotEmpty)
            .toList();
      } catch (_) {}

      try {
        final projData = await client
            .from('projects')
            .select(
              'id, title, description, '
              'profiles!projects_owner_id_fkey'
              '(full_name), '
              'assignee:profiles!'
              'projects_assignee_id_fkey'
              '(full_name)',
            )
            .inFilter('status', [
          'active',
          'planning',
        ]);
        projects = (projData as List)
            .map(
              (p) {
                final ownerMap = p['profiles']
                    as Map<String, dynamic>?;
                final assigneeMap =
                    p['assignee']
                        as Map<String,
                            dynamic>?;
                return <String, String>{
                  'id': p['id'] as String,
                  'title':
                      p['title'] as String? ??
                          '',
                  'description':
                      p['description']
                              as String? ??
                          '',
                  'owner_name':
                      ownerMap?['full_name']
                              as String? ??
                          '',
                  'assignee_name':
                      assigneeMap?['full_name']
                              as String? ??
                          '',
                };
              },
            )
            .toList();
      } catch (_) {}

      // 기존 업무 목록 조회 (중복 방지)
      final existingTasks =
          await _fetchExistingTasks();

      final ai = GeminiService();
      final result =
          await ai.generateMinutesFromAudio(
        audioBytes: audioBytes,
        mimeType: mimeType,
        meetingTitle: title,
        meetingDate: date,
        projectTitle:
            projectTitle ?? _projectTitle,
        teamMemberNames: teamNames,
        projects: projects,
        existingTasks: existingTasks,
        onRetry: (message) {
          state = state.copyWith(
            retryMessage: () => message,
          );
        },
        onProgress: (message) {
          state = state.copyWith(
            progressMessage: () => message,
          );
        },
      );

      state = state.copyWith(
        isGenerating: false,
        minutesResult: () => result,
        transcriptLines:
            result.rawTranscript != null
                ? result.rawTranscript!
                    .split('\n')
                : ['[오디오 파일에서 생성됨]'],
        retryMessage: () => null,
        progressMessage: () => null,
      );
    } catch (e) {
      final errMsg = e.toString();
      String userMessage;
      if (errMsg.contains('SocketException') ||
          errMsg.contains('ClientException') ||
          errMsg.contains('Connection')) {
        userMessage =
            '네트워크 연결을 확인해주세요.';
      } else if (errMsg
          .contains('GEMINI_API_KEY')) {
        userMessage =
            'AI API 키가 설정되지 않았습니다.';
      } else if (errMsg.contains('시간이 초과') ||
          errMsg
              .contains('TimeoutException')) {
        userMessage =
            '오디오 분석 시간이 초과되었습니다. '
            '더 짧은 파일로 시도해주세요.';
      } else {
        final cleanMsg = errMsg.replaceAll(
          RegExp(r'key=\S+'),
          'key=***',
        );
        userMessage =
            'AI 분석 실패: $cleanMsg';
      }
      state = state.copyWith(
        isGenerating: false,
        retryMessage: () => null,
        progressMessage: () => null,
        error: () => userMessage,
      );
    }
  }

  /// 상태 초기화
  void reset() {
    stopRecording();
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _speechService?.dispose();
    _speechService = null;
    _meetingTitle = null;
    _meetingDate = null;
    _projectTitle = null;
    state = const RecordingState();
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}

/// 전역 Recording Provider (autoDispose 없음)
final recordingProvider = StateNotifierProvider<
    RecordingNotifier, RecordingState>(
  (ref) => RecordingNotifier(),
);

/// Gemini Service Provider
final geminiServiceProvider =
    Provider<GeminiService>(
  (ref) => GeminiService(),
);
