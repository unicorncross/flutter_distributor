import 'dart:io';

import 'package:flutter_app_packager/src/makers/windows/windows_msvc_runtime.dart';
import 'package:path/path.dart' as p;

void main() {
  final tempDir = Directory.systemTemp.createTempSync('msvc_runtime_check_');
  try {
    _checksDirectRuntimeDir(tempDir);
    _checksVCToolsRedistDirArchSelection(tempDir);
    _checksRuntimeCopy(tempDir);
    _checksMissingRuntimeFails(tempDir);
  } finally {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  }
}

void _checksDirectRuntimeDir(Directory tempDir) {
  final runtimeDir = Directory(p.join(tempDir.path, 'crt'))
    ..createSync(recursive: true);
  _writeRuntimeDlls(runtimeDir);

  final found = WindowsMsvcRuntime.findRuntimeDirectory(
    arch: 'x64',
    environment: {'VC_REDIST_CRT_DIR': runtimeDir.path},
  );

  _expect(found?.path == runtimeDir.path, 'VC_REDIST_CRT_DIR was not used');
}

void _checksVCToolsRedistDirArchSelection(Directory tempDir) {
  final x64RuntimeDir = Directory(
    p.join(
      tempDir.path,
      'redist',
      '14.40.33810',
      'x64',
      'Microsoft.VC143.CRT',
    ),
  )..createSync(recursive: true);
  final arm64RuntimeDir = Directory(
    p.join(
      tempDir.path,
      'redist',
      '14.40.33810',
      'arm64',
      'Microsoft.VC143.CRT',
    ),
  )..createSync(recursive: true);
  _writeRuntimeDlls(x64RuntimeDir);
  _writeRuntimeDlls(arm64RuntimeDir);

  final found = WindowsMsvcRuntime.findRuntimeDirectory(
    arch: 'arm64',
    environment: {'VCToolsRedistDir': p.join(tempDir.path, 'redist')},
  );

  _expect(
    found?.path == arm64RuntimeDir.path,
    'VCToolsRedistDir did not select the requested architecture',
  );
}

void _checksRuntimeCopy(Directory tempDir) {
  final runtimeDir = Directory(p.join(tempDir.path, 'copy-crt'))
    ..createSync(recursive: true);
  final appDir = Directory(p.join(tempDir.path, 'app'));
  _writeRuntimeDlls(runtimeDir);

  WindowsMsvcRuntime.copyTo(
    appDir,
    arch: 'x64',
    environment: {'VC_REDIST_CRT_DIR': runtimeDir.path},
  );

  for (final dllName in WindowsMsvcRuntime.dllNames) {
    _expect(
      File(p.join(appDir.path, dllName)).existsSync(),
      '$dllName was not copied',
    );
  }
}

void _checksMissingRuntimeFails(Directory tempDir) {
  var failed = false;
  try {
    WindowsMsvcRuntime.copyTo(
      Directory(p.join(tempDir.path, 'missing-app')),
      arch: 'x64',
      environment: const {},
    );
  } on StateError {
    failed = true;
  }

  _expect(failed, 'missing runtime DLLs did not fail packaging');
}

void _writeRuntimeDlls(Directory directory) {
  for (final dllName in WindowsMsvcRuntime.dllNames) {
    File(p.join(directory.path, dllName)).writeAsStringSync('runtime');
  }
}

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}
