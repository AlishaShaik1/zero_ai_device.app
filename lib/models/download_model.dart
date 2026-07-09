import '../utils/constants.dart';

enum DownloadStatus { pending, downloading, verifying, completed, failed }

class ModelDownloadItem {
  String id;
  String? taskId;
  final String displayName;
  final String url;
  final String fileName;
  final int fileSizeMB;
  final String? expectedSha256;
  DownloadStatus status;
  double progress;   // 0.0-1.0
  double downloadSpeedMBps; // for UI display
  String? errorMessage;
  int retryCount;
  int lastProgress = 0;
  DateTime lastProgressTime = DateTime.now();

  ModelDownloadItem({
    required this.id,
    this.taskId,
    required this.displayName,
    required this.url,
    required this.fileName,
    required this.fileSizeMB,
    this.expectedSha256,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.downloadSpeedMBps = 0.0,
    this.errorMessage,
    this.retryCount = 0,
  });
}

List<ModelDownloadItem> get requiredModels {
  return [
    ModelDownloadItem(
      id: 'qwen',
      displayName: 'Qwen 3 0.6B GGUF (Lightweight Reasoning)',
      url: AppConstants.URL_QWEN,
      fileName: AppConstants.FILE_QWEN,
      fileSizeMB: 610,
    ),
    ModelDownloadItem(
      id: 'gemma',
      displayName: 'Gemma 4-E4B-it (Complex Reasoning)',
      url: AppConstants.URL_GEMMA,
      fileName: AppConstants.FILE_GEMMA,
      fileSizeMB: 5400,
    ),
    // ModelDownloadItem(
    //   id: 'whisper_medium',
    //   displayName: 'Hearing: Whisper Medium (Transcribe + Translate)',
    //   url: AppConstants.URL_STT_WHISPER_MEDIUM,
    //   fileName: AppConstants.FILE_STT_WHISPER_MEDIUM,
    //   fileSizeMB: 1533,
    // ),
  ];
}
