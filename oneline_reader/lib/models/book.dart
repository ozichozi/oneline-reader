class Book {
  final String id;
  final String filePath;
  final String originalFileName;
  final String title;
  final String author;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;
  final int totalUnits;

  const Book({
    required this.id,
    required this.filePath,
    required this.originalFileName,
    required this.title,
    required this.author,
    required this.createdAt,
    required this.updatedAt,
    required this.totalUnits,
    this.lastOpenedAt,
  });

  Book copyWith({
    String? title,
    String? author,
    DateTime? updatedAt,
    DateTime? lastOpenedAt,
    int? totalUnits,
    String? filePath,
  }) {
    return Book(
      id: id,
      filePath: filePath ?? this.filePath,
      originalFileName: originalFileName,
      title: title ?? this.title,
      author: author ?? this.author,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      totalUnits: totalUnits ?? this.totalUnits,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'originalFileName': originalFileName,
        'title': title,
        'author': author,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lastOpenedAt': lastOpenedAt?.toIso8601String(),
        'totalUnits': totalUnits,
      };

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as String,
        filePath: json['filePath'] as String,
        originalFileName: json['originalFileName'] as String,
        title: json['title'] as String,
        author: json['author'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        lastOpenedAt: (json['lastOpenedAt'] as String?) != null
            ? DateTime.parse(json['lastOpenedAt'] as String)
            : null,
        totalUnits: json['totalUnits'] as int,
      );
}
