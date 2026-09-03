import 'dart:js_interop';
import 'dart:js_interop_unsafe';

JSFunction? _handler;

/// 브라우저 새로고침/닫기 시 경고 표시
void enableBeforeUnloadWarning() {
  if (_handler != null) return;

  _handler = ((JSObject event) {
    // 표준: returnValue를 설정하면 경고 표시
    event['returnValue'] = ''.toJS;
  }).toJS;

  final addFn = globalContext['addEventListener']
      as JSFunction?;
  addFn?.callAsFunction(
    globalContext,
    'beforeunload'.toJS,
    _handler!,
  );
}

/// 브라우저 경고 해제
void disableBeforeUnloadWarning() {
  if (_handler == null) return;

  final removeFn =
      globalContext['removeEventListener']
          as JSFunction?;
  removeFn?.callAsFunction(
    globalContext,
    'beforeunload'.toJS,
    _handler!,
  );
  _handler = null;
}
