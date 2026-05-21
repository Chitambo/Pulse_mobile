class Document {
  final int id;
  final String title;
  final String? description;
  final String category;
  final String targetAudience;
  final String filename;
  final String filePath;
  final int fileSize;
  final String mimeType;
  final String createdAt;

  Document({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.targetAudience,
    required this.filename,
    required this.filePath,
    required this.fileSize,
    required this.mimeType,
    required this.createdAt,
  });

  factory Document.fromJson(Map<String, dynamic> j) => Document(
        id: j['id'],
        title: j['title'] ?? '',
        description: j['description'],
        category: j['category'] ?? 'other',
        targetAudience: j['targetAudience'] ?? 'all',
        filename: j['filename'] ?? j['originalName'] ?? '',
        filePath: j['filePath'] ?? j['path'] ?? '',
        fileSize: j['fileSize'] ?? j['size'] ?? 0,
        mimeType: j['mimeType'] ?? '',
        createdAt: j['createdAt'] ?? '',
      );

  String get fileSizeDisplay {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
