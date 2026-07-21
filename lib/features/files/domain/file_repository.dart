import 'app_file.dart';

abstract class FileRepository {
  Stream<List<AppFile>> watchFiles(String userId);

  Future<AppFile> addFile(String userId, AppFile file);

  Future<void> deleteFile(String fileId);

  Future<void> toggleFavorite(String fileId);

  Future<List<AppFile>> getByFolder(String userId, String folder);
}
