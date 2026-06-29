import '../utils/constants.dart';

enum DownloadStatus { pending, downloading, completed, failed }

class ModelDownloadItem {
  String id;
  final String displayName;
  final String url;
  final String fileName;
  final int fileSizeMB;
  DownloadStatus status;
  double progress;   // 0.0-1.0
  String? errorMessage;

  ModelDownloadItem({
    required this.id,
    required this.displayName,
    required this.url,
    required this.fileName,
    required this.fileSizeMB,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
  });
}

List<ModelDownloadItem> get requiredModels {
  return [
    ModelDownloadItem(
      id: 'qwen',
      displayName: 'Qwen Core (LLM)',
      url: AppConstants.URL_QWEN,
      fileName: AppConstants.FILE_QWEN,
      fileSizeMB: 400,
    ),
    ModelDownloadItem(
      id: 'gemma',
      displayName: 'Gemma Vision (Agentic)',
      url: AppConstants.URL_GEMMA,
      fileName: AppConstants.FILE_GEMMA,
      fileSizeMB: 2600,
    ),
    ModelDownloadItem(
      id: 'tts_en_model',
      displayName: 'Voice: English (Amy)',
      url: AppConstants.URL_TTS_EN_MODEL,
      fileName: AppConstants.FILE_TTS_EN_MODEL,
      fileSizeMB: 50,
    ),
    ModelDownloadItem(
      id: 'tts_en_config',
      displayName: 'Config: English',
      url: AppConstants.URL_TTS_EN_CONFIG,
      fileName: AppConstants.FILE_TTS_EN_CONFIG,
      fileSizeMB: 1,
    ),
    ModelDownloadItem(
      id: 'tts_hi_model',
      displayName: 'Voice: Hindi (Rohan)',
      url: AppConstants.URL_TTS_HI_MODEL,
      fileName: AppConstants.FILE_TTS_HI_MODEL,
      fileSizeMB: 50,
    ),
    ModelDownloadItem(
      id: 'tts_hi_config',
      displayName: 'Config: Hindi',
      url: AppConstants.URL_TTS_HI_CONFIG,
      fileName: AppConstants.FILE_TTS_HI_CONFIG,
      fileSizeMB: 1,
    ),
    ModelDownloadItem(
      id: 'stt_pre',
      displayName: 'Hearing: Preprocessor',
      url: AppConstants.URL_STT_PREPROCESSOR,
      fileName: AppConstants.FILE_STT_PREPROCESSOR,
      fileSizeMB: 6,
    ),
    ModelDownloadItem(
      id: 'stt_enc',
      displayName: 'Hearing: Encoder',
      url: AppConstants.URL_STT_ENCODER,
      fileName: AppConstants.FILE_STT_ENCODER,
      fileSizeMB: 24,
    ),
    ModelDownloadItem(
      id: 'stt_dec_init',
      displayName: 'Hearing: Decoder Init',
      url: AppConstants.URL_STT_DECODER_INIT,
      fileName: AppConstants.FILE_STT_DECODER_INIT,
      fileSizeMB: 77,
    ),
    ModelDownloadItem(
      id: 'stt_dec',
      displayName: 'Hearing: Decoder',
      url: AppConstants.URL_STT_DECODER,
      fileName: AppConstants.FILE_STT_DECODER,
      fileSizeMB: 73,
    ),
  ];
}
