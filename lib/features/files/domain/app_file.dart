class AppFile {
  const AppFile({
    required this.id,
    required this.name,
    this.folder = 'Documents',
    this.mimeType = 'application/octet-stream',
    required this.localPath,
    this.isFavorite = false,
    this.sizeBytes = 0,
    this.createdAt,
  });

  final String id;
  final String name;
  final String folder;
  final String mimeType;
  final String localPath;
  final bool isFavorite;
  final int sizeBytes;
  final DateTime? createdAt;

  AppFile copyWith({
    String? id,
    String? name,
    String? folder,
    String? mimeType,
    String? localPath,
    bool? isFavorite,
    int? sizeBytes,
    DateTime? createdAt,
  }) {
    return AppFile(
      id: id ?? this.id,
      name: name ?? this.name,
      folder: folder ?? this.folder,
      mimeType: mimeType ?? this.mimeType,
      localPath: localPath ?? this.localPath,
      isFavorite: isFavorite ?? this.isFavorite,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
