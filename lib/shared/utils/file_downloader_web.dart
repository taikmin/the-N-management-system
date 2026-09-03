import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// 웹 플랫폼: Blob + AnchorElement로 강제 다운로드
/// 브라우저가 이미지를 열지 않고 다운로드 폴더에 저장
Future<void> saveFileToDevice({
  required Uint8List bytes,
  required String fileName,
}) async {
  final jsArray = bytes.toJS;
  final blob = web.Blob([jsArray].toJS);
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
