import 'dart:async';

/// 음성 인식 상태
enum SpeechState { idle, listening, paused }

/// Non-web stub (음성인식 미지원)
class SpeechService {
  bool get isSupported => false;

  SpeechState get state => SpeechState.idle;

  String get interimText => '';

  Stream<String> get onTranscript =>
      const Stream.empty();
  Stream<SpeechState> get onStateChange =>
      const Stream.empty();
  Stream<String> get onError =>
      const Stream.empty();

  void start({String lang = 'ko-KR'}) {}
  void pause() {}
  void resume({String lang = 'ko-KR'}) {}
  void stop() {}
  void dispose() {}
}
