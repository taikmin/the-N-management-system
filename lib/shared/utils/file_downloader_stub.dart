import 'dart:typed_data';

/// Non-web 플랫폼: 파일 저장 (추후 path_provider 연동)
Future<void> saveFileToDevice({
  required Uint8List bytes,
  required String fileName,
}) async {
  throw UnsupportedError(
    'Direct file saving not supported on this platform',
  );
}
