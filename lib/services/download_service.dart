import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/download_model.dart';
import '../utils/constants.dart';
import 'package:crypto/crypto.dart';

class DownloadService with ChangeNotifier {
  final List<ModelDownloadItem> _items = requiredModels;
  bool _allDownloaded = false;
  bool _isDownloading = false;
  String _statusMessage = '';
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  List<ModelDownloadItem> get items => _items;
  bool get allDownloaded => _allDownloaded;
  bool get isDownloading => _isDownloading;
  String get statusMessage => _statusMessage;

  DownloadService() {
    _init();
  }

  Future<void> _init() async {
    await checkAllDownloaded();
  }

  double get weightedProgress {
    if (_items.isEmpty) return 0.0;
    double totalMB = 0;
    double doneMB = 0;
    for (final item in _items) {
      totalMB += item.fileSizeMB;
      doneMB += item.fileSizeMB * item.progress;
    }
    return totalMB == 0 ? 0.0 : doneMB / totalMB;
  }

  Future<void> _verifyChecksum(ModelDownloadItem item) async {
    if (item.expectedSha256 == null || item.expectedSha256!.isEmpty) {
      item.status = DownloadStatus.completed;
      notifyListeners();
      _checkOverallStatus();
      return; 
    }
    
    item.status = DownloadStatus.verifying;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 1));
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${item.fileName}');
      if (await file.exists()) {
        final hash = await sha256.bind(file.openRead()).first;
        final hashString = hash.toString();
        if (hashString != item.expectedSha256) {
          debugPrint('SHA-256 mismatch for ${item.fileName}. Expected ${item.expectedSha256}, got $hashString');
          await file.delete();
          item.status = DownloadStatus.failed;
          item.errorMessage = 'Checksum validation failed. File deleted.';
          item.progress = 0.0;
        } else {
          item.status = DownloadStatus.completed;
        }
        notifyListeners();
        _checkOverallStatus();
      }
    } catch (e) {
      debugPrint('Error verifying checksum: $e');
      item.status = DownloadStatus.failed;
      item.errorMessage = 'Verification error';
      notifyListeners();
    }
  }

  void _checkOverallStatus() {
    bool hasDownloading = _items.any((item) => item.status == DownloadStatus.downloading);
    bool allDone = _items.every((item) => item.status == DownloadStatus.completed);
    
    _isDownloading = hasDownloading;
    _allDownloaded = allDone;
    
    if (_allDownloaded) {
      _statusMessage = 'All models ready!';
    } else if (_isDownloading) {
      _statusMessage = 'Downloading...';
    }
  }

  Future<bool> checkAllDownloaded() async {
    final dir = await getApplicationDocumentsDirectory();
    bool all = true;

    for (final item in _items) {
      final file = File('${dir.path}/${item.fileName}');
      final expectedBytes = item.fileSizeMB * 1024 * 1024;

      if (file.existsSync()) {
        final currentBytes = file.lengthSync();
        if (currentBytes >= (expectedBytes * 0.9)) {
          item.status = DownloadStatus.completed;
          item.progress = 1.0;
        } else {
          all = false;
          if (item.status != DownloadStatus.downloading && item.status != DownloadStatus.verifying) {
            item.status = DownloadStatus.pending;
            item.progress = (currentBytes / expectedBytes).clamp(0.0, 0.99);
          }
        }
      } else {
        all = false;
        if (item.status != DownloadStatus.downloading && item.status != DownloadStatus.verifying) {
          if (item.status != DownloadStatus.failed) {
            item.status = DownloadStatus.pending;
            item.progress = 0.0;
          }
        }
      }
    }

    final legacyWhisper = File('${dir.path}/${AppConstants.FILE_STT_WHISPER_MEDIUM_LEGACY}');
    final currentWhisper = File('${dir.path}/${AppConstants.FILE_STT_WHISPER_MEDIUM}');
    if (!currentWhisper.existsSync() && legacyWhisper.existsSync()) {
      try { legacyWhisper.deleteSync(); } catch (_) {}
    }

    _allDownloaded = all;
    notifyListeners();
    return all;
  }

  Future<bool> _hasConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((c) => c != ConnectivityResult.none);
  }

  Future<void> downloadAll() async {
    if (_isDownloading) return;
    
    if (!await _hasConnectivity()) {
      _statusMessage = 'No internet connection. Please connect to WiFi or mobile data.';
      notifyListeners();
      await _connectivitySubscription?.cancel();
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
        if (result.any((c) => c != ConnectivityResult.none) && !_isDownloading && !_allDownloaded) {
          _statusMessage = 'Connection restored! Resuming...';
          notifyListeners();
          downloadAll();
        }
      });
      return;
    }
    
    _isDownloading = true;
    _statusMessage = 'Downloading...';
    _cancelToken = CancelToken();
    notifyListeners();

    await _processQueue();
  }

  Future<void> _processQueue() async {
    final dir = await getApplicationDocumentsDirectory();

    for (final item in _items) {
      if (_cancelToken?.isCancelled ?? true) break;
      if (item.status == DownloadStatus.completed) continue;

      item.status = DownloadStatus.downloading;
      item.errorMessage = null;
      notifyListeners();

      try {
        final savePath = '${dir.path}/${item.fileName}';
        final file = File(savePath);
        int downloadedBytes = 0;
        
        if (await file.exists()) {
          downloadedBytes = await file.length();
        }

        final options = Options(
          responseType: ResponseType.stream,
          headers: downloadedBytes > 0 ? {'Range': 'bytes=$downloadedBytes-'} : null,
        );

        final response = await _dio.get<ResponseBody>(
          item.url,
          options: options,
          cancelToken: _cancelToken,
        );

        // If the server doesn't support partial content, it will return 200 instead of 206
        if (response.statusCode == 200 && downloadedBytes > 0) {
          downloadedBytes = 0;
          await file.writeAsBytes([]); // Clear the file
        }

        final contentLengthStr = response.headers.value(HttpHeaders.contentLengthHeader);
        final contentLength = int.tryParse(contentLengthStr ?? '-1') ?? -1;
        final totalBytes = contentLength != -1 ? contentLength + downloadedBytes : -1;

        final raf = file.openSync(mode: downloadedBytes > 0 ? FileMode.append : FileMode.write);
        int receivedBytes = downloadedBytes;

        try {
          await for (final chunk in response.data!.stream) {
            if (_cancelToken?.isCancelled ?? false) break;
            raf.writeFromSync(chunk);
            receivedBytes += chunk.length;

            if (totalBytes != -1) {
              item.progress = (receivedBytes / totalBytes).clamp(0.0, 0.99);
            } else {
              final expectedBytes = item.fileSizeMB * 1024 * 1024;
              item.progress = (receivedBytes / expectedBytes).clamp(0.0, 0.99);
            }

            final now = DateTime.now();
            final timeElapsed = now.difference(item.lastProgressTime);
            
            if (timeElapsed.inMilliseconds > 300) {
              final diffPct = item.progress - (item.lastProgress / 100.0);
              if (diffPct > 0) {
                final downloadedMB = item.fileSizeMB * diffPct;
                item.downloadSpeedMBps = downloadedMB / (timeElapsed.inMilliseconds / 1000.0);
              }
              item.lastProgress = (item.progress * 100).toInt();
              item.lastProgressTime = now;
              notifyListeners();
            }
          }
        } finally {
          raf.closeSync();
        }
        
        if (_cancelToken?.isCancelled ?? false) {
           throw DioException.requestCancelled(requestOptions: response.requestOptions, reason: 'User cancelled');
        }

        // Download complete
        item.downloadSpeedMBps = 0;
        item.progress = 1.0;
        notifyListeners();
        
        await _verifyChecksum(item);
        
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) {
          item.status = DownloadStatus.pending;
          item.downloadSpeedMBps = 0;
          debugPrint('Download cancelled: ${item.fileName}');
        } else {
          item.status = DownloadStatus.failed;
          item.downloadSpeedMBps = 0;
          item.errorMessage = 'Connection lost. Tap to retry.';
          debugPrint('Download failed: $e');
        }
        notifyListeners();
        break; // Stop the queue on error
      }
    }

    _isDownloading = false;
    _checkOverallStatus();
    notifyListeners();
  }

  Future<void> retryFailed() async {
    for (final item in _items) {
      if (item.status == DownloadStatus.failed) {
        item.status = DownloadStatus.pending;
      }
    }
    await downloadAll();
  }

  Future<String?> getModelPath(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$fileName';
    final file = File(path);
    
    try {
      final item = _items.firstWhere((i) => i.fileName == fileName);
      final expectedBytes = item.fileSizeMB * 1024 * 1024;
      if (file.existsSync() && file.lengthSync() >= (expectedBytes * 0.9)) {
        return path;
      }
    } catch (_) {}
    return null;
  }

  void cancelAll() {
    _cancelToken?.cancel('User cancelled');
    for (final item in _items) {
      if (item.status == DownloadStatus.downloading) {
        item.status = DownloadStatus.pending;
        item.progress = 0.0;
        item.downloadSpeedMBps = 0;
      }
    }
    _isDownloading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }
}
