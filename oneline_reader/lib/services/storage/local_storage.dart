import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalStorage {
  LocalStorage._();
  static final LocalStorage instance = LocalStorage._();

  Future<Directory> getAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final appDir = Directory('${dir.path}/oneline_reader');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  Future<File> _file(String relativePath) async {
    final dir = await getAppDir();
    final file = File('${dir.path}/$relativePath');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  /// Returns a file handle inside the app directory without writing to it yet.
  Future<File> getFile(String relativePath) async {
    final dir = await getAppDir();
    final file = File('${dir.path}/$relativePath');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<void> writeJson(String relativePath, Object data) async {
    final file = await _file(relativePath);
    await file.writeAsString(jsonEncode(data));
  }

  Future<Map<String, dynamic>> readJsonMap(String relativePath) async {
    final file = await _file(relativePath);
    final content = await file.readAsString();
    if (content.isEmpty) return {};
    return jsonDecode(content) as Map<String, dynamic>;
  }

  Future<List<dynamic>> readJsonList(String relativePath) async {
    final file = await _file(relativePath);
    final content = await file.readAsString();
    if (content.isEmpty) return [];
    return jsonDecode(content) as List<dynamic>;
  }

  Future<File> copyIntoApp(File source, String targetName) async {
    final dir = await getAppDir();
    final target = File('${dir.path}/$targetName');
    await target.parent.create(recursive: true);
    return source.copy(target.path);
  }

  /// Best-effort attempt to open a file externally. Returns true on success.
  Future<bool> openExternally(String path) async {
    try {
      if (Platform.isMacOS) {
        final result = await Process.run('open', [path]);
        return result.exitCode == 0;
      }
      if (Platform.isWindows) {
        final result = await Process.run('cmd', ['/c', 'start', '', path]);
        return result.exitCode == 0;
      }
      if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [path]);
        return result.exitCode == 0;
      }
    } catch (_) {
      // swallow and return false
    }
    return false;
  }
}
