import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../domain/app_file.dart';
import '../domain/file_repository.dart';

class FileRepositoryImpl implements FileRepository {
  FileRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<AppFile>> watchFiles(String userId) {
    final query = (_db.select(_db.appFiles)
          ..where((AppFiles tbl) => tbl.userId.equals(userId))
          ..orderBy(<OrderingTerm Function(AppFiles)>[
            (AppFiles tbl) => OrderingTerm.desc(tbl.isFavorite),
            (AppFiles tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .watch();
    return query.map((List<AppFileRow> rows) => rows.map(_map).toList());
  }

  @override
  Future<AppFile> addFile(String userId, AppFile file) async {
    final String id = file.id.isEmpty ? IdGenerator.next() : file.id;
    final DateTime now = DateTime.now();
    await _db.into(_db.appFiles).insert(
          AppFilesCompanion.insert(
            id: id,
            userId: userId,
            name: file.name,
            folder: Value<String>(file.folder),
            mimeType: Value<String>(file.mimeType),
            localPath: file.localPath,
            isFavorite: Value<bool>(file.isFavorite),
            sizeBytes: Value<int>(file.sizeBytes),
            createdAt: file.createdAt ?? now,
          ),
        );
    final AppFileRow row = await (_db.select(_db.appFiles)..where((AppFiles tbl) => tbl.id.equals(id))).getSingle();
    return _map(row);
  }

  @override
  Future<void> deleteFile(String fileId) async {
    await (_db.delete(_db.appFiles)..where((AppFiles tbl) => tbl.id.equals(fileId))).go();
  }

  @override
  Future<void> toggleFavorite(String fileId) async {
    final AppFileRow row = await (_db.select(_db.appFiles)..where((AppFiles tbl) => tbl.id.equals(fileId))).getSingle();
    await (_db.update(_db.appFiles)..where((AppFiles tbl) => tbl.id.equals(fileId))).write(
          AppFilesCompanion(isFavorite: Value<bool>(!row.isFavorite)),
        );
  }

  @override
  Future<List<AppFile>> getByFolder(String userId, String folder) async {
    final List<AppFileRow> rows = await (_db.select(_db.appFiles)
          ..where((AppFiles tbl) => tbl.userId.equals(userId) & tbl.folder.equals(folder))
          ..orderBy(<OrderingTerm Function(AppFiles)>[
            (AppFiles tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .get();
    return rows.map(_map).toList();
  }

  AppFile _map(AppFileRow row) {
    return AppFile(
      id: row.id,
      name: row.name,
      folder: row.folder,
      mimeType: row.mimeType,
      localPath: row.localPath,
      isFavorite: row.isFavorite,
      sizeBytes: row.sizeBytes,
      createdAt: row.createdAt,
    );
  }
}
