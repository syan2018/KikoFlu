import 'package:equatable/equatable.dart';

enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  paused,
}

class DownloadTask extends Equatable {
  final String id; // 使用 hash 作为唯一标识
  final int workId;
  final String workTitle;
  final String fileName;
  final String downloadUrl;
  final String? hash;
  final int? totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;

  const DownloadTask({
    required this.id,
    required this.workId,
    required this.workTitle,
    required this.fileName,
    required this.downloadUrl,
    this.hash,
    this.totalBytes,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.pending,
    this.error,
    required this.createdAt,
    this.completedAt,
  });

  double get progress {
    if (totalBytes == null || totalBytes == 0) return 0.0;
    return downloadedBytes / totalBytes!;
  }

  DownloadTask copyWith({
    String? id,
    int? workId,
    String? workTitle,
    String? fileName,
    String? downloadUrl,
    String? hash,
    int? totalBytes,
    int? downloadedBytes,
    DownloadStatus? status,
    String? error,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      workId: workId ?? this.workId,
      workTitle: workTitle ?? this.workTitle,
      fileName: fileName ?? this.fileName,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      hash: hash ?? this.hash,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workId': workId,
      'workTitle': workTitle,
      'fileName': fileName,
      'downloadUrl': downloadUrl,
      'hash': hash,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'status': status.name,
      'error': error,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String,
      workId: json['workId'] as int,
      workTitle: json['workTitle'] as String,
      fileName: json['fileName'] as String,
      downloadUrl: json['downloadUrl'] as String,
      hash: json['hash'] as String?,
      totalBytes: json['totalBytes'] as int?,
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.pending,
      ),
      error: json['error'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        workId,
        workTitle,
        fileName,
        downloadUrl,
        hash,
        totalBytes,
        downloadedBytes,
        status,
        error,
        createdAt,
        completedAt,
      ];
}
