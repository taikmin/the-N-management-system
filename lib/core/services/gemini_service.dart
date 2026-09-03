import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'ai_service.dart';

/// Gemini API 구현체 (2.5 Pro, 향상된 회의록 분석)
class GeminiService implements AiService {
  GeminiService({String? apiKey})
      : _apiKey = apiKey ??
            dotenv.env['GEMINI_API_KEY'] ??
            '';

  final String _apiKey;

  static const _baseUrl =
      'https://generativelanguage.googleapis.com'
      '/v1beta/models';
  static const _model = 'gemini-2.5-pro';
  static const _maxRetries = 3;
  static const _retryDelay =
      Duration(seconds: 5);

  /// 직접 처리 가능한 최대 글자 수
  static const _maxDirectChars = 80000;

  /// 청크 크기 (청크 처리 시)
  static const _chunkSize = 15000;

  static final _httpClient = http.Client();

  /// 진행 상태 콜백 타입
  @override
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
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'GEMINI_API_KEY가 설정되지 않았습니다',
      );
    }

    // 긴 텍스트: 청크 분할 → 요약 → 통합
    if (transcript.length > _maxDirectChars) {
      return _generateWithChunking(
        transcript: transcript,
        meetingTitle: meetingTitle,
        meetingDate: meetingDate,
        projectTitle: projectTitle,
        teamMemberNames: teamMemberNames,
        projects: projects,
        existingTasks: existingTasks,
        onRetry: onRetry,
        onProgress: onProgress,
      );
    }

    // 일반 처리 (80,000자 이하)
    onProgress?.call(
      'AI가 회의록을 분석 중입니다...',
    );

    final prompt = _buildMainPrompt(
      transcript: transcript,
      meetingTitle: meetingTitle,
      meetingDate: meetingDate,
      projectTitle: projectTitle,
      teamMemberNames: teamMemberNames,
      projects: projects,
      existingTasks: existingTasks,
    );

    final responseText = await _callGemini(
      prompt: prompt,
      useJsonMode: true,
      onRetry: onRetry,
    );

    return _parseResponse(responseText, transcript);
  }

  /// 청크 분할 처리 (매우 긴 텍스트)
  Future<MeetingMinutesResult>
      _generateWithChunking({
    required String transcript,
    String? meetingTitle,
    String? meetingDate,
    String? projectTitle,
    List<String>? teamMemberNames,
    List<Map<String, String>>? projects,
    List<String>? existingTasks,
    void Function(String message)? onRetry,
    void Function(String message)? onProgress,
  }) async {
    // 1단계: 청크 분할
    final chunks = _splitIntoChunks(
      transcript,
      _chunkSize,
    );
    final totalChunks = chunks.length;

    onProgress?.call(
      '긴 텍스트를 $totalChunks개 구간으로 나누어 '
      '분석합니다...',
    );

    // 2단계: 각 청크 요약
    final chunkSummaries = <String>[];
    for (var i = 0; i < chunks.length; i++) {
      onProgress?.call(
        '구간 ${i + 1}/$totalChunks 분석 중...',
      );

      final chunkPrompt = '''
당신은 한국어 회의 녹음 텍스트 분석 전문가입니다.
아래는 전체 회의 녹음 중 ${i + 1}번째 구간입니다 (총 $totalChunks구간).

## 규칙
1. 이 구간의 핵심 논의 내용을 요약하세요.
2. 업무/할일 항목이 있으면 추출하세요.
3. 담당자, 마감일이 언급되면 포함하세요.
4. 원문을 그대로 복사하지 마세요.
${teamMemberNames != null && teamMemberNames.isNotEmpty ? '\n## 팀원 이름 (음성인식 오류 교정용)\n${teamMemberNames.join(', ')}\n' : ''}
## 텍스트
${chunks[i]}

## 응답 형식 (JSON)
{
  "summary": "이 구간의 핵심 내용 요약",
  "tasks": [
    {
      "title": "업무 제목",
      "assignee_name": "담당자 또는 null",
      "deadline": "YYYY-MM-DD 또는 null",
      "description": "상세 내용"
    }
  ]
}
''';

      try {
        final chunkResult = await _callGemini(
          prompt: chunkPrompt,
          useJsonMode: true,
          onRetry: onRetry,
        );
        chunkSummaries.add(chunkResult);
      } catch (e) {
        chunkSummaries.add(
          '{"summary": "(구간 ${i + 1} 분석 실패)", '
          '"tasks": []}',
        );
      }
    }

    // 3단계: 청크 결과 통합
    onProgress?.call(
      '분석 결과를 통합하여 최종 회의록을 '
      '생성 중입니다...',
    );

    final mergedInput = StringBuffer();
    for (var i = 0; i < chunkSummaries.length; i++) {
      mergedInput.writeln(
        '=== 구간 ${i + 1} ===',
      );
      mergedInput.writeln(chunkSummaries[i]);
      mergedInput.writeln();
    }

    final mergePrompt = _buildMergePrompt(
      chunkSummaries: mergedInput.toString(),
      meetingTitle: meetingTitle,
      meetingDate: meetingDate,
      projectTitle: projectTitle,
      teamMemberNames: teamMemberNames,
      projects: projects,
      existingTasks: existingTasks,
    );

    final finalResponse = await _callGemini(
      prompt: mergePrompt,
      useJsonMode: true,
      onRetry: onRetry,
    );

    return _parseResponse(
      finalResponse,
      transcript,
    );
  }

  /// 텍스트를 청크로 분할 (문장 단위)
  List<String> _splitIntoChunks(
    String text,
    int chunkSize,
  ) {
    final chunks = <String>[];
    var start = 0;

    while (start < text.length) {
      var end = start + chunkSize;
      if (end >= text.length) {
        chunks.add(text.substring(start));
        break;
      }

      // 문장 끝(마침표, 물음표, 느낌표)에서 자르기
      final nearEnd = text.substring(
        end - 500 > start ? end - 500 : start,
        end,
      );
      final lastPeriod = nearEnd.lastIndexOf(
        RegExp(r'[.?!。\n]'),
      );
      if (lastPeriod > 0) {
        end = (end - 500 > start
                ? end - 500
                : start) +
            lastPeriod +
            1;
      }

      chunks.add(text.substring(start, end));
      start = end;
    }

    return chunks;
  }

  /// 메인 프롬프트 (직접 처리용)
  String _buildMainPrompt({
    required String transcript,
    String? meetingTitle,
    String? meetingDate,
    String? projectTitle,
    List<String>? teamMemberNames,
    List<Map<String, String>>? projects,
    List<String>? existingTasks,
  }) {
    final ctx = StringBuffer();
    if (meetingTitle != null) {
      ctx.writeln('- 회의명: $meetingTitle');
    }
    if (meetingDate != null) {
      ctx.writeln('- 일시: $meetingDate');
    }
    if (projectTitle != null) {
      ctx.writeln('- 관련 과제: $projectTitle');
    }

    final nameSection = _buildNameSection(
      teamMemberNames,
    );
    final projSection = _buildProjectSection(
      projects,
    );
    final hasProjects =
        projects != null && projects.isNotEmpty;

    return '''
당신은 전문 회의록 작성자입니다. 한국 정부출연 연구기관(KIMM)의 R&D 과제 회의를 정리합니다.

다음은 한국어 음성 인식(Web Speech API)으로 변환된 회의 텍스트입니다.
음성 인식 특성상 오타, 문맥 오류, 불완전한 문장, 반복이 많습니다.
이를 이해하고 전문적으로 정리해주세요.

## 반드시 지켜야 할 핵심 규칙

1. **원문을 절대 그대로 복사하지 마세요.** 반드시 요약하고 재구성해야 합니다.
2. **회의록은 깔끔한 문장으로 재작성**하세요. 구어체를 문어체로 변환하세요.
3. **업무/할일 항목은 반드시 추출**하세요. 없으면 빈 배열 []로 반환하세요.
4. 음성 인식 오류(오탈자, 동음이의어)를 문맥에 맞게 교정하세요.
5. "음...", "그...", "아...", 반복 표현 등 불필요한 내용은 제거하세요.
$nameSection$projSection${_buildExistingTasksSection(existingTasks)}
## 회의 정보
$ctx
## 응답 형식 (반드시 이 JSON 구조로만 응답)

{
  "minutes": "## 회의록\\n\\n### 일시\\nYYYY-MM-DD\\n\\n### 참석자\\n- 이름1, 이름2\\n\\n### 주요 논의 사항\\n\\n**1. 주제1**\\n- 논의 내용 요약\\n- 결정 사항\\n\\n**2. 주제2**\\n- 논의 내용 요약\\n\\n### 결정 사항\\n- 항목1\\n- 항목2\\n\\n### 향후 계획\\n- 계획1\\n- 계획2",
  "tasks": [
    {
      "title": "구체적인 업무 제목 (동사+목적어 형태)",
      "assignee_name": "담당자 이름 또는 null",
      "deadline": "YYYY-MM-DD 또는 null",
      "priority": "high 또는 medium 또는 low",
      "description": "업무 상세 설명"${hasProjects ? ',\n      "project_title": "관련 프로젝트명 또는 null"' : ''}
    }
  ]
}

## 업무 추출 가이드

다음 표현에서 업무를 추출하세요:
- "~해야 한다", "~해주세요", "~하겠습니다", "~해보겠습니다", "~할게요"
- "~을 확인하다", "~을 준비하다", "~을 제출하다", "~을 구매하다"
- "~을 실험하다", "~을 제작하다", "~을 연락하다", "~을 보고하다"
- "다음 주까지", "이번 주 내로", "오늘 중으로" 등 마감일 표현

업무 추출 규칙:
- 담당자가 불분명하면 assignee_name을 null로 설정
- 마감일이 불분명하면 deadline을 null로 설정
- "이번 주", "다음 주", "오늘 중", "월말까지" 등은 오늘 날짜($meetingDate) 기준으로 구체적 날짜(YYYY-MM-DD)로 변환
- 우선순위: 긴급/중요 → high, 일반 → medium, 여유 → low
- 하나의 논의에서 여러 업무가 나올 수 있음 — 각각 별도 항목으로 추출

## 회의 녹음 텍스트 (음성 인식 원문)

$transcript

## 지시

위 텍스트를 분석하여 지정된 JSON 형식으로 응답하세요.
회의록은 마크다운으로 깔끔하게 작성하고, 업무는 빠짐없이 추출하세요.
원문을 그대로 나열하지 말고 반드시 정리·요약·재구성하세요.
''';
  }

  /// 청크 통합 프롬프트
  String _buildMergePrompt({
    required String chunkSummaries,
    String? meetingTitle,
    String? meetingDate,
    String? projectTitle,
    List<String>? teamMemberNames,
    List<Map<String, String>>? projects,
    List<String>? existingTasks,
  }) {
    final ctx = StringBuffer();
    if (meetingTitle != null) {
      ctx.writeln('- 회의명: $meetingTitle');
    }
    if (meetingDate != null) {
      ctx.writeln('- 일시: $meetingDate');
    }
    if (projectTitle != null) {
      ctx.writeln('- 관련 과제: $projectTitle');
    }

    final projSection = _buildProjectSection(
      projects,
    );
    final hasProjects =
        projects != null && projects.isNotEmpty;

    return '''
당신은 전문 회의록 작성자입니다. 아래는 긴 회의 녹음을 여러 구간으로 나누어 분석한 결과입니다.
이를 하나의 완성된 회의록으로 통합해주세요.

## 회의 정보
$ctx
$projSection${_buildExistingTasksSection(existingTasks)}
## 각 구간별 분석 결과

$chunkSummaries

## 통합 규칙
1. 모든 구간의 내용을 하나의 체계적인 회의록으로 통합
2. 중복 내용은 병합하고, 시간순으로 정리
3. 모든 구간에서 추출된 업무를 합치되, 중복 제거
4. 업무의 담당자/마감일은 가장 구체적인 정보를 사용

## 응답 형식 (반드시 이 JSON 구조로만 응답)

{
  "minutes": "## 회의록\\n\\n### 일시\\n...\\n\\n### 참석자\\n...\\n\\n### 주요 논의 사항\\n...\\n\\n### 결정 사항\\n...\\n\\n### 향후 계획\\n...",
  "tasks": [
    {
      "title": "업무 제목",
      "assignee_name": "담당자 또는 null",
      "deadline": "YYYY-MM-DD 또는 null",
      "priority": "high/medium/low",
      "description": "상세 내용"${hasProjects ? ',\n      "project_title": "관련 프로젝트명 또는 null"' : ''}
    }
  ]
}
''';
  }

  /// 팀원 이름 섹션
  String _buildNameSection(
    List<String>? teamMemberNames,
  ) {
    if (teamMemberNames == null ||
        teamMemberNames.isEmpty) {
      return '';
    }

    return '''

## 팀원 이름 (음성 인식 오류 교정용)
${teamMemberNames.join(', ')}

음성 인식 텍스트에서 위 이름과 유사한 발음이 나오면 올바른 이름으로 교정하세요.
예: "박천훈" → "박철훈", "김영히" → "김영희"
담당자(assignee_name) 필드에는 반드시 위 목록의 정확한 이름을 사용하세요.
''';
  }

  /// 프로젝트 목록 섹션
  String _buildProjectSection(
    List<Map<String, String>>? projects,
  ) {
    if (projects == null || projects.isEmpty) {
      return '';
    }

    final buf = StringBuffer();
    buf.writeln();
    buf.writeln(
      '## 진행 중인 프로젝트 목록',
    );
    for (var i = 0; i < projects.length; i++) {
      final p = projects[i];
      buf.write('${i + 1}. "${p['title']}"');
      final owner = p['owner_name'];
      final assignee = p['assignee_name'];
      if ((owner != null && owner.isNotEmpty) ||
          (assignee != null &&
              assignee.isNotEmpty)) {
        buf.write(' (');
        final parts = <String>[];
        if (owner != null && owner.isNotEmpty) {
          parts.add('책임자: $owner');
        }
        if (assignee != null &&
            assignee.isNotEmpty) {
          parts.add('담당자: $assignee');
        }
        buf.write(parts.join(', '));
        buf.write(')');
      }
      final desc = p['description'];
      if (desc != null && desc.isNotEmpty) {
        buf.write(' - $desc');
      }
      buf.writeln();
    }
    buf.writeln();
    buf.writeln(
      '업무 항목의 project_title에 가장 관련 있는 '
      '프로젝트명을 매칭하세요. '
      '매칭이 어려우면 null로 설정하세요.',
    );
    buf.writeln(
      '담당자/책임자가 특정 프로젝트에 관해 '
      '이야기하면 해당 프로젝트로 매칭하세요.',
    );
    return buf.toString();
  }

  /// 기존 등록 업무 섹션 (중복 방지용)
  String _buildExistingTasksSection(
    List<String>? existingTasks,
  ) {
    if (existingTasks == null ||
        existingTasks.isEmpty) {
      return '';
    }

    final buf = StringBuffer();
    buf.writeln();
    buf.writeln(
      '## 이미 등록된 업무 목록 '
      '(중복 추출 금지)',
    );
    for (final task in existingTasks) {
      buf.writeln('- $task');
    }
    buf.writeln();
    buf.writeln(
      '위 목록에 이미 있는 업무와 동일하거나 '
      '매우 유사한 업무는 추출하지 마세요.',
    );
    buf.writeln(
      '새로운 업무, 또는 기존 업무와 '
      '명확히 다른 내용만 추출해주세요.',
    );
    buf.writeln(
      '기존 업무의 진행 상황이나 후속 조치가 '
      '언급된 경우에만, 구체적인 신규 액션 '
      '아이템이 있을 때 추출하세요.',
    );
    return buf.toString();
  }

  /// Gemini API 호출 (재시도 포함)
  Future<String> _callGemini({
    required String prompt,
    bool useJsonMode = false,
    void Function(String message)? onRetry,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/$_model:generateContent'
      '?key=$_apiKey',
    );

    final genConfig = <String, dynamic>{
      'temperature': 0.2,
    };
    if (useJsonMode) {
      genConfig['responseMimeType'] =
          'application/json';
    }

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': genConfig,
    });

    for (var attempt = 0;
        attempt <= _maxRetries;
        attempt++) {
      try {
        final response = await _httpClient.post(
          url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: body,
        );

        if (response.statusCode == 200) {
          return _extractText(response.body);
        }

        if (response.statusCode == 429 &&
            attempt < _maxRetries) {
          onRetry?.call(
            '요청 제한 초과. '
            '${_retryDelay.inSeconds}초 후 '
            '재시도합니다... '
            '(${attempt + 1}/$_maxRetries)',
          );
          await Future.delayed(_retryDelay);
          continue;
        }

        if (response.statusCode >= 500 &&
            attempt < _maxRetries) {
          onRetry?.call(
            '서버 오류 발생. 재시도 중... '
            '(${attempt + 1}/$_maxRetries)',
          );
          await Future.delayed(_retryDelay);
          continue;
        }

        throw Exception(
          'Gemini API 오류 '
          '(${response.statusCode})',
        );
      } on Exception catch (e) {
        final isNetworkError = e
                .toString()
                .contains('SocketException') ||
            e
                .toString()
                .contains('ClientException') ||
            e
                .toString()
                .contains('Connection') ||
            e
                .toString()
                .contains('TimeoutException');
        if (isNetworkError &&
            attempt < _maxRetries) {
          onRetry?.call(
            '네트워크 오류. 재시도 중... '
            '(${attempt + 1}/$_maxRetries)',
          );
          await Future.delayed(_retryDelay);
          continue;
        }
        rethrow;
      }
    }

    throw Exception(
      '최대 재시도 횟수를 초과했습니다',
    );
  }

  /// API 응답에서 텍스트 추출
  String _extractText(String responseBody) {
    final json = jsonDecode(responseBody)
        as Map<String, dynamic>;
    final candidates =
        json['candidates'] as List?;
    if (candidates == null ||
        candidates.isEmpty) {
      throw Exception('AI 응답이 비어있습니다');
    }

    final content = candidates[0]['content']
        as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('AI 응답 내용이 없습니다');
    }

    return parts[0]['text'] as String? ?? '';
  }

  /// 응답 파싱 (강화된 JSON 추출)
  MeetingMinutesResult _parseResponse(
    String responseText,
    String transcript,
  ) {
    // 1차: 직접 JSON 파싱 시도
    try {
      final parsed = jsonDecode(responseText)
          as Map<String, dynamic>;
      return _buildResult(parsed, transcript);
    } catch (_) {
      // 계속 시도
    }

    // 2차: 코드 블록(```json ... ```)에서 추출
    try {
      final codeBlockMatch = RegExp(
        r'```(?:json)?\s*([\s\S]*?)```',
      ).firstMatch(responseText);
      if (codeBlockMatch != null) {
        final jsonStr =
            codeBlockMatch.group(1)!.trim();
        final parsed = jsonDecode(jsonStr)
            as Map<String, dynamic>;
        return _buildResult(parsed, transcript);
      }
    } catch (_) {
      // 계속 시도
    }

    // 3차: 첫 번째 { } 블록 추출
    try {
      final startIdx = responseText.indexOf('{');
      final endIdx =
          responseText.lastIndexOf('}');
      if (startIdx >= 0 && endIdx > startIdx) {
        final jsonStr = responseText.substring(
          startIdx,
          endIdx + 1,
        );
        final parsed = jsonDecode(jsonStr)
            as Map<String, dynamic>;
        return _buildResult(parsed, transcript);
      }
    } catch (_) {
      // 계속 시도
    }

    // 4차: minutes/tasks 키가 있는지 확인
    //      (부분적으로라도 추출)
    try {
      final minutesMatch = RegExp(
        r'"minutes"\s*:\s*"([\s\S]*?)"(?=\s*,|\s*})',
      ).firstMatch(responseText);
      if (minutesMatch != null) {
        final minutes = minutesMatch
            .group(1)!
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\"', '"');
        return MeetingMinutesResult(
          minutes: minutes,
          tasks: [],
          analysisNote:
              '업무 추출에 실패했습니다. '
              '수동으로 업무를 추가해주세요.',
        );
      }
    } catch (_) {
      // 최종 폴백
    }

    // 최종 폴백: 응답 텍스트가 있으면 그것을 회의록으로
    if (responseText.trim().isNotEmpty &&
        responseText.trim() != transcript.trim()) {
      return MeetingMinutesResult(
        minutes: responseText.trim(),
        tasks: [],
        analysisNote:
            'AI가 JSON 형식으로 응답하지 않았습니다. '
            '텍스트를 회의록으로 사용합니다. '
            '업무는 수동으로 추가해주세요.',
      );
    }

    // 완전 실패
    return MeetingMinutesResult(
      minutes: transcript,
      tasks: [],
      analysisNote:
          'AI 분석에 실패했습니다. '
          '원문 텍스트를 표시합니다. '
          '수동으로 회의록을 작성해주세요.',
    );
  }

  /// JSON 결과로부터 MeetingMinutesResult 빌드
  MeetingMinutesResult _buildResult(
    Map<String, dynamic> parsed,
    String transcript,
  ) {
    final minutes =
        parsed['minutes'] as String? ?? '';
    final tasksJson =
        parsed['tasks'] as List? ?? [];
    final tasks = tasksJson
        .map(
          (t) => ExtractedTask.fromJson(
            t as Map<String, dynamic>,
          ),
        )
        .toList();

    // minutes가 원문과 거의 동일하면 분석 실패로 판단
    final similarity = _textSimilarity(
      minutes,
      transcript,
    );
    String? note;
    if (similarity > 0.85 &&
        transcript.length > 500) {
      note =
          'AI가 원문을 충분히 요약하지 못했을 수 있습니다. '
          '내용을 검토해주세요.';
    }

    return MeetingMinutesResult(
      minutes: minutes.isNotEmpty
          ? minutes
          : transcript,
      tasks: tasks,
      analysisNote: note,
    );
  }

  /// 텍스트 유사도 (간단한 Jaccard 방식)
  double _textSimilarity(
    String a,
    String b,
  ) {
    if (a.isEmpty || b.isEmpty) return 0.0;

    // 짧은 텍스트는 비교 불필요
    if (a.length < 200 || b.length < 200) {
      return 0.0;
    }

    // 양쪽 텍스트에서 공백 제거 후 비교
    final aClean = a.replaceAll(
      RegExp(r'\s+'),
      '',
    );
    final bClean = b.replaceAll(
      RegExp(r'\s+'),
      '',
    );

    // 짧은 쪽 기준으로 포함도 측정
    final shorter = aClean.length <= bClean.length
        ? aClean
        : bClean;
    final longer = aClean.length > bClean.length
        ? aClean
        : bClean;

    if (shorter.isEmpty) return 0.0;

    // 200자 샘플링으로 효율적 비교
    var matchCount = 0;
    const sampleSize = 200;
    final step = shorter.length > sampleSize
        ? shorter.length ~/ sampleSize
        : 1;

    var checked = 0;
    for (var i = 0;
        i < shorter.length;
        i += step) {
      final end = (i + 10) <= shorter.length
          ? i + 10
          : shorter.length;
      final snippet = shorter.substring(i, end);
      if (longer.contains(snippet)) {
        matchCount++;
      }
      checked++;
      if (checked >= sampleSize) break;
    }

    return checked > 0
        ? matchCount / checked
        : 0.0;
  }

  // ─── Task Extraction from Minutes ───

  /// 저장된 회의록에서 업무만 추출
  Future<List<ExtractedTask>> extractTasksFromMinutes({
    required String minutesText,
    String? meetingTitle,
    String? meetingDate,
    List<String>? teamMemberNames,
    List<Map<String, String>>? projects,
    List<String>? existingTasks,
    void Function(String message)? onRetry,
    void Function(String message)? onProgress,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'GEMINI_API_KEY가 설정되지 않았습니다',
      );
    }

    onProgress?.call(
      '회의록에서 업무를 추출하고 있습니다...',
    );

    final ctx = StringBuffer();
    if (meetingTitle != null) {
      ctx.writeln('- 회의명: $meetingTitle');
    }
    if (meetingDate != null) {
      ctx.writeln('- 일시: $meetingDate');
    }

    final nameSection = _buildNameSection(
      teamMemberNames,
    );
    final projSection = _buildProjectSection(
      projects,
    );
    final hasProjects =
        projects != null && projects.isNotEmpty;

    final prompt = '''
당신은 업무 추출 전문가입니다. 한국 정부출연 연구기관(KIMM)의 R&D 과제 회의록에서 업무/할일 항목을 추출합니다.

## 회의 정보
$ctx
$nameSection$projSection${_buildExistingTasksSection(existingTasks)}
## 업무 추출 규칙

다음 표현에서 업무를 추출하세요:
- "~해야 한다", "~해주세요", "~하겠습니다", "~해보겠습니다", "~할게요"
- "~을 확인하다", "~을 준비하다", "~을 제출하다", "~을 구매하다"
- "~을 실험하다", "~을 제작하다", "~을 연락하다", "~을 보고하다"
- "다음 주까지", "이번 주 내로", "오늘 중으로" 등 마감일 표현
- 결정 사항, 향후 계획, 조치 사항 등에서도 업무를 추출

규칙:
- 담당자가 불분명하면 assignee_name을 null로 설정
- 마감일이 불분명하면 deadline을 null로 설정
- 상대 날짜는 오늘($meetingDate) 기준 YYYY-MM-DD로 변환
- 우선순위: 긴급/중요 → high, 일반 → medium, 여유 → low
- 하나의 논의에서 여러 업무가 나올 수 있음 — 각각 별도 항목으로 추출
- 업무 제목은 "동사+목적어" 형태로 구체적으로 작성

## 회의록 텍스트

$minutesText

## 응답 형식 (반드시 이 JSON 구조로만 응답)

{
  "tasks": [
    {
      "title": "구체적인 업무 제목 (동사+목적어 형태)",
      "assignee_name": "담당자 이름 또는 null",
      "deadline": "YYYY-MM-DD 또는 null",
      "priority": "high 또는 medium 또는 low",
      "description": "업무 상세 설명"${hasProjects ? ',\n      "project_title": "관련 프로젝트명 또는 null"' : ''}
    }
  ]
}

## 지시

위 회의록을 분석하여 업무/할일 항목을 빠짐없이 추출하세요.
업무가 없으면 빈 배열 []을 반환하세요.
''';

    final responseText = await _callGemini(
      prompt: prompt,
      useJsonMode: true,
      onRetry: onRetry,
    );

    return _parseTasksResponse(responseText);
  }

  /// 업무 추출 응답 파싱
  List<ExtractedTask> _parseTasksResponse(
    String responseText,
  ) {
    Map<String, dynamic>? parsed;

    // 1차: 직접 JSON 파싱
    try {
      parsed = jsonDecode(responseText)
          as Map<String, dynamic>;
    } catch (_) {}

    // 2차: 코드 블록 추출
    if (parsed == null) {
      try {
        final match = RegExp(
          r'```(?:json)?\s*([\s\S]*?)```',
        ).firstMatch(responseText);
        if (match != null) {
          parsed = jsonDecode(
            match.group(1)!.trim(),
          ) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    // 3차: 첫 { } 블록 추출
    if (parsed == null) {
      try {
        final s = responseText.indexOf('{');
        final e = responseText.lastIndexOf('}');
        if (s >= 0 && e > s) {
          parsed = jsonDecode(
            responseText.substring(s, e + 1),
          ) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    if (parsed != null) {
      final tasksJson =
          parsed['tasks'] as List? ?? [];
      return tasksJson
          .map(
            (t) => ExtractedTask.fromJson(
              t as Map<String, dynamic>,
            ),
          )
          .toList();
    }

    return [];
  }

  // ─── Audio File Analysis ───

  /// 인라인 데이터 최대 크기 (20MB)
  static const _maxInlineBytes = 20 * 1024 * 1024;

  /// 오디오 파일에서 회의록 + 업무 추출
  Future<MeetingMinutesResult>
      generateMinutesFromAudio({
    required Uint8List audioBytes,
    required String mimeType,
    String? meetingTitle,
    String? meetingDate,
    String? projectTitle,
    List<String>? teamMemberNames,
    List<Map<String, String>>? projects,
    List<String>? existingTasks,
    void Function(String message)? onRetry,
    void Function(String message)? onProgress,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'GEMINI_API_KEY가 설정되지 않았습니다',
      );
    }

    final prompt = _buildAudioPrompt(
      meetingTitle: meetingTitle,
      meetingDate: meetingDate,
      projectTitle: projectTitle,
      teamMemberNames: teamMemberNames,
      projects: projects,
      existingTasks: existingTasks,
    );

    String responseText;

    if (audioBytes.length <= _maxInlineBytes) {
      // ≤20MB: inline base64
      onProgress?.call(
        '오디오 파일을 분석 중입니다...',
      );
      responseText = await _callGeminiWithAudio(
        audioBytes: audioBytes,
        mimeType: mimeType,
        prompt: prompt,
        onRetry: onRetry,
        timeout: const Duration(minutes: 3),
      );
    } else {
      // >20MB: File API 업로드
      onProgress?.call('대용량 파일 업로드 중...');
      final fileInfo = await _uploadToFileApi(
        audioBytes: audioBytes,
        mimeType: mimeType,
        onProgress: onProgress,
      );

      try {
        onProgress?.call('파일 처리 대기 중...');
        await _pollFileReady(fileInfo['name']!);

        onProgress?.call(
          'AI가 오디오를 분석 중입니다...',
        );
        responseText =
            await _callGeminiWithFileData(
          fileUri: fileInfo['uri']!,
          mimeType: mimeType,
          prompt: prompt,
          onRetry: onRetry,
          timeout: const Duration(minutes: 10),
        );
      } finally {
        try {
          await _deleteGeminiFile(
            fileInfo['name']!,
          );
        } catch (_) {}
      }
    }

    return _parseAudioResponse(responseText);
  }

  /// 오디오 분석용 프롬프트
  String _buildAudioPrompt({
    String? meetingTitle,
    String? meetingDate,
    String? projectTitle,
    List<String>? teamMemberNames,
    List<Map<String, String>>? projects,
    List<String>? existingTasks,
  }) {
    final ctx = StringBuffer();
    if (meetingTitle != null) {
      ctx.writeln('- 회의명: $meetingTitle');
    }
    if (meetingDate != null) {
      ctx.writeln('- 일시: $meetingDate');
    }
    if (projectTitle != null) {
      ctx.writeln('- 관련 과제: $projectTitle');
    }

    final nameSection = _buildNameSection(
      teamMemberNames,
    );
    final projSection = _buildProjectSection(
      projects,
    );
    final hasProjects =
        projects != null && projects.isNotEmpty;

    return '''
당신은 전문 회의록 작성자입니다. 한국 정부출연 연구기관(KIMM)의 R&D 과제 회의를 정리합니다.

첨부된 오디오 파일은 한국어 회의 녹음입니다.
이 오디오를 듣고 다음 작업을 수행해주세요:

1. **음성을 텍스트로 변환** (STT): 전체 내용을 한국어 텍스트로 변환
2. **회의록 작성**: 변환된 텍스트를 기반으로 체계적인 회의록 작성
3. **업무 추출**: 회의에서 언급된 업무/할일 항목 추출

## 핵심 규칙

1. **원문을 그대로 복사하지 마세요.** 회의록은 요약·재구성하세요.
2. **회의록은 깔끔한 문장으로** 구어체를 문어체로 변환하세요.
3. **업무/할일 항목은 반드시 추출**하세요. 없으면 빈 배열 [].
4. **raw_transcript에 음성 변환 원문**을 포함하세요.
5. 불필요한 표현("음...", "그...", 반복)은 회의록에서 제거하세요.
$nameSection$projSection${_buildExistingTasksSection(existingTasks)}
## 회의 정보
$ctx
## 응답 형식 (반드시 이 JSON 구조로만 응답)

{
  "raw_transcript": "오디오에서 변환한 전체 텍스트 (화자 구분 포함)",
  "minutes": "## 회의록\\n\\n### 일시\\n...\\n\\n### 참석자\\n...\\n\\n### 주요 논의 사항\\n...\\n\\n### 결정 사항\\n...\\n\\n### 향후 계획\\n...",
  "tasks": [
    {
      "title": "구체적인 업무 제목 (동사+목적어)",
      "assignee_name": "담당자 이름 또는 null",
      "deadline": "YYYY-MM-DD 또는 null",
      "priority": "high 또는 medium 또는 low",
      "description": "업무 상세 설명"${hasProjects ? ',\n      "project_title": "관련 프로젝트명 또는 null"' : ''}
    }
  ]
}

## 업무 추출 가이드

다음 표현에서 업무를 추출하세요:
- "~해야 한다", "~해주세요", "~하겠습니다"
- "~을 확인/준비/제출/구매/실험/제작하다"
- "다음 주까지", "이번 주 내로", "오늘 중으로"

규칙:
- 담당자 불분명 → assignee_name: null
- 마감일 불분명 → deadline: null
- 상대 날짜는 $meetingDate 기준 YYYY-MM-DD로 변환
- 긴급/중요 → high, 일반 → medium, 여유 → low

## 지시

첨부된 오디오를 분석하여 JSON으로 응답하세요.
raw_transcript에 원문, minutes에 회의록, tasks에 업무를 포함하세요.
''';
  }

  /// 인라인 base64로 Gemini 호출 (≤20MB)
  Future<String> _callGeminiWithAudio({
    required Uint8List audioBytes,
    required String mimeType,
    required String prompt,
    void Function(String message)? onRetry,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final url = Uri.parse(
      '$_baseUrl/$_model:generateContent'
      '?key=$_apiKey',
    );

    final base64Data = base64Encode(audioBytes);

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Data,
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        'responseMimeType': 'application/json',
      },
    });

    return _callGeminiPost(
      url: url,
      body: body,
      timeout: timeout,
      onRetry: onRetry,
    );
  }

  /// File API로 대용량 파일 업로드
  Future<Map<String, String>> _uploadToFileApi({
    required Uint8List audioBytes,
    required String mimeType,
    void Function(String message)? onProgress,
  }) async {
    // Step 1: resumable upload 시작
    final startUrl = Uri.parse(
      'https://generativelanguage.googleapis.com'
      '/upload/v1beta/files?key=$_apiKey',
    );

    final startResp = await _httpClient
        .post(
          startUrl,
          headers: {
            'X-Goog-Upload-Protocol': 'resumable',
            'X-Goog-Upload-Command': 'start',
            'X-Goog-Upload-Header-Content-Length':
                '${audioBytes.length}',
            'X-Goog-Upload-Header-Content-Type':
                mimeType,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'file': {
              'display_name': 'meeting_audio',
            },
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (startResp.statusCode != 200) {
      throw Exception(
        '파일 업로드 시작 실패 '
        '(${startResp.statusCode})',
      );
    }

    final uploadUrl =
        startResp.headers['x-goog-upload-url'];
    if (uploadUrl == null) {
      throw Exception(
        '업로드 URL을 받지 못했습니다',
      );
    }

    // Step 2: 파일 업로드
    onProgress?.call('파일 업로드 중...');

    final uploadResp = await _httpClient
        .put(
          Uri.parse(uploadUrl),
          headers: {
            'Content-Length': '${audioBytes.length}',
            'X-Goog-Upload-Offset': '0',
            'X-Goog-Upload-Command':
                'upload, finalize',
          },
          body: audioBytes,
        )
        .timeout(const Duration(minutes: 5));

    if (uploadResp.statusCode != 200) {
      throw Exception(
        '파일 업로드 실패 '
        '(${uploadResp.statusCode})',
      );
    }

    final fileJson = jsonDecode(uploadResp.body)
        as Map<String, dynamic>;
    final fileInfo =
        fileJson['file'] as Map<String, dynamic>;

    return {
      'name': fileInfo['name'] as String,
      'uri': fileInfo['uri'] as String,
    };
  }

  /// 파일 처리 완료 대기 (ACTIVE 될 때까지 폴링)
  Future<void> _pollFileReady(
    String fileName,
  ) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com'
      '/v1beta/$fileName?key=$_apiKey',
    );

    // 최대 5분 (60 × 5초)
    for (var i = 0; i < 60; i++) {
      final resp = await _httpClient
          .get(url)
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body)
            as Map<String, dynamic>;
        final st = json['state'] as String?;
        if (st == 'ACTIVE') return;
        if (st == 'FAILED') {
          throw Exception('파일 처리에 실패했습니다');
        }
      }

      await Future.delayed(
        const Duration(seconds: 5),
      );
    }

    throw Exception('파일 처리 시간이 초과되었습니다');
  }

  /// File API 파일 참조로 Gemini 호출 (>20MB)
  Future<String> _callGeminiWithFileData({
    required String fileUri,
    required String mimeType,
    required String prompt,
    void Function(String message)? onRetry,
    Duration timeout =
        const Duration(minutes: 10),
  }) async {
    final url = Uri.parse(
      '$_baseUrl/$_model:generateContent'
      '?key=$_apiKey',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'fileData': {
                'fileUri': fileUri,
                'mimeType': mimeType,
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        'responseMimeType': 'application/json',
      },
    });

    return _callGeminiPost(
      url: url,
      body: body,
      timeout: timeout,
      onRetry: onRetry,
    );
  }

  /// 업로드된 파일 삭제
  Future<void> _deleteGeminiFile(
    String fileName,
  ) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com'
      '/v1beta/$fileName?key=$_apiKey',
    );
    await _httpClient
        .delete(url)
        .timeout(const Duration(seconds: 10));
  }

  /// Gemini POST + 재시도 (공용)
  Future<String> _callGeminiPost({
    required Uri url,
    required String body,
    Duration timeout = const Duration(minutes: 3),
    void Function(String message)? onRetry,
  }) async {
    for (var attempt = 0;
        attempt <= _maxRetries;
        attempt++) {
      try {
        final response = await _httpClient
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
              },
              body: body,
            )
            .timeout(timeout);

        if (response.statusCode == 200) {
          return _extractText(response.body);
        }

        if (response.statusCode == 429 &&
            attempt < _maxRetries) {
          onRetry?.call(
            '요청 제한 초과. '
            '${_retryDelay.inSeconds}초 후 '
            '재시도합니다... '
            '(${attempt + 1}/$_maxRetries)',
          );
          await Future.delayed(_retryDelay);
          continue;
        }

        if (response.statusCode >= 500 &&
            attempt < _maxRetries) {
          onRetry?.call(
            '서버 오류 발생. 재시도 중... '
            '(${attempt + 1}/$_maxRetries)',
          );
          await Future.delayed(_retryDelay);
          continue;
        }

        throw Exception(
          'Gemini API 오류 '
          '(${response.statusCode})',
        );
      } on Exception catch (e) {
        final errStr = e.toString();

        if (errStr.contains('TimeoutException')) {
          if (attempt < _maxRetries) {
            onRetry?.call(
              '요청 시간 초과. 재시도 중... '
              '(${attempt + 1}/$_maxRetries)',
            );
            await Future.delayed(_retryDelay);
            continue;
          }
          throw Exception(
            '요청 시간이 초과되었습니다',
          );
        }

        final isNetworkError = errStr
                .contains('SocketException') ||
            errStr.contains('ClientException') ||
            errStr.contains('Connection');
        if (isNetworkError &&
            attempt < _maxRetries) {
          onRetry?.call(
            '네트워크 오류. 재시도 중... '
            '(${attempt + 1}/$_maxRetries)',
          );
          await Future.delayed(_retryDelay);
          continue;
        }
        rethrow;
      }
    }

    throw Exception(
      '최대 재시도 횟수를 초과했습니다',
    );
  }

  /// 오디오 응답 파싱 (raw_transcript 포함)
  MeetingMinutesResult _parseAudioResponse(
    String responseText,
  ) {
    Map<String, dynamic>? parsed;

    // 1차: 직접 JSON 파싱
    try {
      parsed = jsonDecode(responseText)
          as Map<String, dynamic>;
    } catch (_) {}

    // 2차: 코드 블록 추출
    if (parsed == null) {
      try {
        final match = RegExp(
          r'```(?:json)?\s*([\s\S]*?)```',
        ).firstMatch(responseText);
        if (match != null) {
          parsed = jsonDecode(
            match.group(1)!.trim(),
          ) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    // 3차: 첫 { } 블록 추출
    if (parsed == null) {
      try {
        final s = responseText.indexOf('{');
        final e = responseText.lastIndexOf('}');
        if (s >= 0 && e > s) {
          parsed = jsonDecode(
            responseText.substring(s, e + 1),
          ) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    if (parsed != null) {
      final rawTranscript =
          parsed['raw_transcript'] as String?;
      final minutes =
          parsed['minutes'] as String? ?? '';
      final tasksJson =
          parsed['tasks'] as List? ?? [];
      final tasks = tasksJson
          .map(
            (t) => ExtractedTask.fromJson(
              t as Map<String, dynamic>,
            ),
          )
          .toList();

      return MeetingMinutesResult(
        minutes: minutes.isNotEmpty
            ? minutes
            : rawTranscript ?? '',
        tasks: tasks,
        rawTranscript: rawTranscript,
      );
    }

    // 폴백
    return MeetingMinutesResult(
      minutes: responseText.trim().isNotEmpty
          ? responseText.trim()
          : '',
      tasks: [],
      analysisNote:
          'AI가 JSON 형식으로 응답하지 않았습니다. '
          '텍스트를 회의록으로 사용합니다.',
    );
  }
}
