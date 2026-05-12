// core/app_settings.dart
// User preferences persisted across app restarts.

class AppSettings {
  /// Directory where received files are saved.
  final String downloadDirectory;

  /// Size of each file chunk in bytes (default: 64 KB).
  final int chunkSizeBytes;

  /// If true, incoming file transfers are accepted without prompting.
  final bool autoAccept;

  const AppSettings({
    required this.downloadDirectory,
    this.chunkSizeBytes = 65536, // 64 KB
    this.autoAccept = false,
  });

  AppSettings copyWith({
    String? downloadDirectory,
    int? chunkSizeBytes,
    bool? autoAccept,
  }) {
    return AppSettings(
      downloadDirectory: downloadDirectory ?? this.downloadDirectory,
      chunkSizeBytes: chunkSizeBytes ?? this.chunkSizeBytes,
      autoAccept: autoAccept ?? this.autoAccept,
    );
  }

  Map<String, dynamic> toJson() => {
        'downloadDirectory': downloadDirectory,
        'chunkSizeBytes': chunkSizeBytes,
        'autoAccept': autoAccept,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        downloadDirectory: json['downloadDirectory'] as String,
        chunkSizeBytes: json['chunkSizeBytes'] as int? ?? 65536,
        autoAccept: json['autoAccept'] as bool? ?? false,
      );
}
