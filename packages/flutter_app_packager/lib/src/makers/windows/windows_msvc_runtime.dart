import 'dart:io';

import 'package:path/path.dart' as p;

class WindowsMsvcRuntime {
  static const dllNames = [
    'msvcp140.dll',
    'vcruntime140.dll',
    'vcruntime140_1.dll',
  ];

  static List<File> copyTo(
    Directory appDirectory, {
    String? arch,
    Map<String, String>? environment,
  }) {
    final runtimeDirectory = findRuntimeDirectory(
      arch: arch,
      environment: environment,
    );
    if (runtimeDirectory == null) {
      throw StateError(
        'MSVC runtime DLLs were not found. Set VC_REDIST_CRT_DIR to the '
        'Microsoft.VC*.CRT directory before packaging Windows artifacts.',
      );
    }

    if (!appDirectory.existsSync()) {
      appDirectory.createSync(recursive: true);
    }

    return dllNames.map((dllName) {
      final source = File(p.join(runtimeDirectory.path, dllName));
      final destination = File(p.join(appDirectory.path, dllName));
      return source.copySync(destination.path);
    }).toList();
  }

  static Directory? findRuntimeDirectory({
    String? arch,
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    final directDir = env['VC_REDIST_CRT_DIR'];
    if (directDir != null && _hasRuntimeDlls(Directory(directDir))) {
      return Directory(directDir);
    }

    final roots = <Directory>[
      if (env['VCToolsRedistDir'] != null) Directory(env['VCToolsRedistDir']!),
      ..._visualStudioRedistRoots(env),
    ];
    final normalizedArch = _normalizeArch(arch);

    for (final root in roots) {
      final runtimeDirectory = _findUnderRedistRoot(root, normalizedArch);
      if (runtimeDirectory != null) {
        return runtimeDirectory;
      }
    }

    return null;
  }

  static Directory? _findUnderRedistRoot(Directory root, String arch) {
    if (!root.existsSync()) {
      return null;
    }

    final versionDirectories = _directories(root)
      ..sort((a, b) => b.path.compareTo(a.path));

    final candidates = <Directory>[
      Directory(p.join(root.path, arch)),
      for (final versionDirectory in versionDirectories)
        Directory(p.join(versionDirectory.path, arch)),
    ];

    for (final archDirectory in candidates) {
      if (!archDirectory.existsSync()) {
        continue;
      }
      final crtDirectories = _directories(archDirectory)
          .where(
            (directory) =>
                p.basename(directory.path).startsWith('Microsoft.VC'),
          )
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final crtDirectory in crtDirectories) {
        if (_hasRuntimeDlls(crtDirectory)) {
          return crtDirectory;
        }
      }
      if (_hasRuntimeDlls(archDirectory)) {
        return archDirectory;
      }
    }

    return null;
  }

  static List<Directory> _visualStudioRedistRoots(Map<String, String> env) {
    final programFilesX86 = env['ProgramFiles(x86)'];
    if (programFilesX86 == null) {
      return const [];
    }

    return [
      for (final edition in [
        'BuildTools',
        'Community',
        'Professional',
        'Enterprise',
      ])
        Directory(
          p.join(
            programFilesX86,
            'Microsoft Visual Studio',
            '2022',
            edition,
            'VC',
            'Redist',
            'MSVC',
          ),
        ),
    ];
  }

  static bool _hasRuntimeDlls(Directory directory) {
    return dllNames.every((dllName) {
      return File(p.join(directory.path, dllName)).existsSync();
    });
  }

  static List<Directory> _directories(Directory directory) {
    if (!directory.existsSync()) {
      return const [];
    }
    return directory.listSync().whereType<Directory>().toList(growable: false);
  }

  static String _normalizeArch(String? arch) {
    switch (arch?.toLowerCase()) {
      case 'arm64':
        return 'arm64';
      case 'amd64':
      case 'x86_64':
      case 'x64':
      default:
        return 'x64';
    }
  }
}
