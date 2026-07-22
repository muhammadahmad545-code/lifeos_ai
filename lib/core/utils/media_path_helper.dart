import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class MediaPathHelper {
  static Future<Directory> _dir(String folder) async {
    final Directory root = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(root.path, 'lifeos_media', folder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> nextPath({required String folder, required String extension}) async {
    final Directory dir = await _dir(folder);
    return p.join(dir.path, '${const Uuid().v4()}.$extension');
  }

  static Future<File> copyInto({
    required String sourcePath,
    required String folder,
    required String extension,
  }) async {
    final String target = await nextPath(folder: folder, extension: extension);
    return File(sourcePath).copy(target);
  }
}
