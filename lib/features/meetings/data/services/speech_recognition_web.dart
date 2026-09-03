// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// 음성 인식 상태
enum SpeechState { idle, listening, paused }

/// Web Speech API를 사용하는 STT 서비스 (Web 전용)
class SpeechService {
  bool get isSupported {
    final window = globalContext;
    return window.has('SpeechRecognition') ||
        window.has('webkitSpeechRecognition');
  }

  JSObject? _recognition;
  SpeechState _state = SpeechState.idle;
  SpeechState get state => _state;

  bool _shouldRestart = false;
  String _lang = 'ko-KR';

  final _transcriptController =
      StreamController<String>.broadcast();
  final _stateController =
      StreamController<SpeechState>.broadcast();
  final _errorController =
      StreamController<String>.broadcast();

  Stream<String> get onTranscript =>
      _transcriptController.stream;
  Stream<SpeechState> get onStateChange =>
      _stateController.stream;
  Stream<String> get onError =>
      _errorController.stream;

  String _interimText = '';
  String get interimText => _interimText;

  void _setState(SpeechState s) {
    _state = s;
    if (!_stateController.isClosed) {
      _stateController.add(s);
    }
  }

  /// 음성 인식 시작
  void start({String lang = 'ko-KR'}) {
    if (!isSupported) {
      _errorController.add(
        '이 브라우저는 음성 인식을 지원하지 않습니다',
      );
      return;
    }
    if (_state == SpeechState.listening) return;

    _lang = lang;
    _shouldRestart = true;
    _startInternal();
  }

  void _startInternal() {
    _recognition = null;

    // SpeechRecognition 또는 webkit 폴백
    final window = globalContext;
    final JSObject rec;
    if (window.has('SpeechRecognition')) {
      final ctor = window['SpeechRecognition']
          as JSFunction;
      rec = ctor.callAsConstructor<JSObject>();
    } else {
      final ctor = window['webkitSpeechRecognition']
          as JSFunction;
      rec = ctor.callAsConstructor<JSObject>();
    }

    // 속성 설정
    rec['lang'] = _lang.toJS;
    rec['continuous'] = true.toJS;
    rec['interimResults'] = true.toJS;
    rec['maxAlternatives'] = 1.toJS;

    // onresult 콜백
    rec['onresult'] = ((JSObject event) {
      _handleResult(event);
    }).toJS;

    // onerror 콜백
    rec['onerror'] = ((JSObject event) {
      _handleError(event);
    }).toJS;

    // onend 콜백
    rec['onend'] = ((JSObject event) {
      _handleEnd();
    }).toJS;

    // onstart 콜백
    rec['onstart'] = ((JSObject event) {
      _setState(SpeechState.listening);
    }).toJS;

    _recognition = rec;

    try {
      final startFn = rec['start'] as JSFunction;
      startFn.callAsFunction(rec);
    } catch (e) {
      if (!_errorController.isClosed) {
        _errorController.add('음성 인식 시작 실패: $e');
      }
    }
  }

  void _handleResult(JSObject event) {
    final results = event['results'] as JSObject;
    final resultIndex =
        (event['resultIndex'] as JSNumber).toDartInt;
    final length =
        (results['length'] as JSNumber).toDartInt;

    for (int i = resultIndex; i < length; i++) {
      final itemFn = results['item'] as JSFunction;
      final result =
          itemFn.callAsFunction(results, i.toJS)!
              as JSObject;
      final isFinal =
          (result['isFinal'] as JSBoolean).toDart;
      final altFn = result['item'] as JSFunction;
      final alt =
          altFn.callAsFunction(result, 0.toJS)!
              as JSObject;
      final transcript =
          (alt['transcript'] as JSString).toDart;

      if (isFinal) {
        if (!_transcriptController.isClosed) {
          _transcriptController.add(transcript);
        }
        _interimText = '';
      } else {
        _interimText = transcript;
        if (!_transcriptController.isClosed) {
          _transcriptController.add('');
        }
      }
    }
  }

  void _handleError(JSObject event) {
    final error =
        (event['error'] as JSString).toDart;
    if (error == 'no-speech' ||
        error == 'aborted') {
      return;
    }

    String message;
    switch (error) {
      case 'not-allowed':
        message = '마이크 권한이 거부되었습니다. '
            '브라우저 설정에서 마이크 접근을 '
            '허용해주세요.';
      case 'audio-capture':
        message = '마이크를 찾을 수 없습니다. '
            '마이크가 연결되어 있는지 '
            '확인해주세요.';
      case 'network':
        message = '네트워크 오류가 발생했습니다. '
            '인터넷 연결을 확인해주세요.';
      case 'service-not-allowed':
        message = '음성 인식 서비스를 사용할 수 '
            '없습니다. HTTPS 환경에서 '
            '시도해주세요.';
      default:
        message = '음성 인식 오류: $error';
    }

    if (!_errorController.isClosed) {
      _errorController.add(message);
    }
  }

  void _handleEnd() {
    if (_shouldRestart &&
        _state == SpeechState.listening) {
      Future.delayed(
        const Duration(milliseconds: 200),
        () {
          if (_shouldRestart &&
              _state == SpeechState.listening) {
            _startInternal();
          }
        },
      );
    } else if (_state != SpeechState.paused) {
      _setState(SpeechState.idle);
    }
  }

  /// 일시 정지
  void pause() {
    _shouldRestart = false;
    _setState(SpeechState.paused);
    _stopRecognition();
  }

  /// 재개
  void resume({String lang = 'ko-KR'}) {
    if (_state != SpeechState.paused) return;
    _lang = lang;
    _shouldRestart = true;
    _startInternal();
  }

  /// 완전 중지
  void stop() {
    _shouldRestart = false;
    _stopRecognition();
    _setState(SpeechState.idle);
  }

  void _stopRecognition() {
    try {
      if (_recognition != null) {
        final stopFn =
            _recognition!['stop'] as JSFunction;
        stopFn.callAsFunction(_recognition!);
      }
    } catch (_) {}
    _recognition = null;
  }

  void dispose() {
    stop();
    _transcriptController.close();
    _stateController.close();
    _errorController.close();
  }
}
