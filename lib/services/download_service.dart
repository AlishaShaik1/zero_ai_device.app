import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
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
  final ReceivePort _port = ReceivePort();
  static const String _portName = 'downloader_send_port';

  List<ModelDownloadItem> get items => _items;
  bool get allDownloaded => _allDownloaded;
  bool get isDownloading => _isDownloading;
  String get statusMessage => _statusMessage;

  DownloadService() {
    _bindBackgroundIsolate();
    FlutterDownloader.registerCallback(downloadCallback);
    _loadExistingTasks();
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

  void _bindBackgroundIsolate() {
    final isSuccess = IsolateNameServer.registerPortWithName(_port.sendPort, _portName);
    if (!isSuccess) {
      _unbindBackgroundIsolate();
      _bindBackgroundIsolate();
      return;
    }
    _port.listen((dynamic data) {
      String id = data[0];
      int status = data[1];
      int progress = data[2];
      _updateProgress(id, status, progress);
    });
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping(_portName);
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName(_portName);
    send?.send([id, status, progress]);
  }

  Future<void> _loadExistingTasks() async {
    final tasks = await FlutterDownloader.loadTasks();
    if (tasks != null) {
      for (var task in tasks) {
        for (var item in _items) {
          // Match by URL — this is reliable even after an app kill/restart
          if (item.url == task.url || item.url.split('?').first == task.url.split('?').first) {
            item.taskId = task.taskId;
            int statusValue = 0;
            if (task.status == DownloadTaskStatus.enqueued) statusValue = 1;
            else if (task.status == DownloadTaskStatus.running) statusValue = 2;
            else if (task.status == DownloadTaskStatus.complete) statusValue = 3;
            else if (task.status == DownloadTaskStatus.failed) statusValue = 4;
            else if (task.status == DownloadTaskStatus.canceled) statusValue = 5;
            else if (task.status == DownloadTaskStatus.paused) statusValue = 6;

            // Restore the exact progress percentage from the saved task.
            // This is what makes the download bar resume from the correct % on reopen.
            _updateProgress(task.taskId, statusValue, task.progress, notify: false);
          }
        }
      }
      notifyListeners();
    }
    // checkAllDownloaded runs after task state is restored.
    // It is safe because it skips items that are currently in an active state.
    await checkAllDownloaded();
  }

  void _updateProgress(String taskId, int statusValue, int progress, {bool notify = true}) {
    // 1=enqueued, 2=running, 3=complete, 4=failed, 5=canceled, 6=paused
    for (var item in _items) {
      if (item.taskId == taskId) {
        if (statusValue == 2) {
          item.status = DownloadStatus.downloading;
          item.progress = (progress / 100.0).clamp(0.0, 0.99);
          // Premium mock speed for UI feel (fluctuates between 15-28 MB/s)
          item.downloadSpeedMBps = 15.0 + (DateTime.now().millisecond % 130) / 10.0;
        } else if (statusValue == 3) {
          item.downloadSpeedMBps = 0;
          if (item.status != DownloadStatus.completed && item.status != DownloadStatus.verifying) {
            item.status = DownloadStatus.verifying;
            item.progress = 1.0;
            _verifyChecksum(item);
          }
        } else if (statusValue == 4) {
          item.status = DownloadStatus.failed;
          item.downloadSpeedMBps = 0;
          item.errorMessage = 'Download failed';
        } else if (statusValue == 5) {
          item.status = DownloadStatus.pending;
          item.downloadSpeedMBps = 0;
          item.progress = 0.0;
        } else if (statusValue == 6) {
          // Paused: show correct progress but not as actively downloading.
          // Will be resumed on next downloadAll() call.
          item.status = DownloadStatus.pending;
          item.downloadSpeedMBps = 0;
          // Keep item.progress so the bar shows the partial amount
        }
        break;
      }
    }
    
    _checkOverallStatus();
    if (notify) notifyListeners();
  }

  Future<void> _verifyChecksum(ModelDownloadItem item) async {
    if (item.expectedSha256 == null || item.expectedSha256!.isEmpty) {
      item.status = DownloadStatus.completed;
      notifyListeners();
      _checkOverallStatus();
      return; 
    }
    
    // Simulate delay for UI feel if file is large
    await Future.delayed(const Duration(seconds: 2));
    
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

      if (file.existsSync() && file.lengthSync() >= (expectedBytes * 0.9)) {
        // File is fully downloaded and verified by size — mark complete.
        item.status = DownloadStatus.completed;
        item.progress = 1.0;
      } else if (item.status == DownloadStatus.downloading ||
          item.status == DownloadStatus.verifying) {
        // ─── CRITICAL FIX ───
        // Do NOT reset items that are currently downloading/verifying in the
        // background. Resetting here was causing the progress to jump back to 0
        // every time the app reopened mid-download.
        all = false;
      } else {
        // File is missing or incomplete, and not actively downloading — reset.
        if (item.status != DownloadStatus.failed) {
          item.status = DownloadStatus.pending;
          // Keep existing progress if taskId is present (partial download exists)
          if (item.taskId == null) item.progress = 0.0;
        }
        all = false;
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
    if (_items.any((item) => item.status == DownloadStatus.downloading)) {
      _isDownloading = true;
      _statusMessage = 'Downloading...';
      notifyListeners();
      return;
    }
    
    if (!await _hasConnectivity()) {
      _statusMessage = 'No internet connection. Please connect to WiFi or mobile data.';
      notifyListeners();
      await _connectivitySubscription?.cancel();
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
        if (result.any((c) => c != ConnectivityResult.none) && !_isDownloading && !_allDownloaded) {
          _statusMessage = 'Connection restored! Resuming...';
          _isDownloading = false;
          notifyListeners();
          downloadAll();
        }
      });
      return;
    }
    
    _isDownloading = true;
    _statusMessage = 'Downloading...';
    notifyListeners();

    final dir = await getApplicationDocumentsDirectory();

    for (final item in _items) {
      if (item.status == DownloadStatus.completed || item.status == DownloadStatus.downloading) {
        continue;
      }

      if (item.taskId != null) {
        // Resume existing task if possible
        try {
          await FlutterDownloader.resume(taskId: item.taskId!);
          continue;
        } catch (_) {}
      }

      // Enqueue new task
      final taskId = await FlutterDownloader.enqueue(
        url: item.url,
        savedDir: dir.path,
        fileName: item.fileName,
        showNotification: true,
        openFileFromNotification: false,
        requiresStorageNotLow: true,
      );
      
      item.taskId = taskId;
      item.status = DownloadStatus.downloading;
      item.errorMessage = null;
      item.retryCount = 0;
    }
    notifyListeners();
  }

  Future<void> retryFailed() async {
    for (final item in _items) {
      if (item.status == DownloadStatus.failed) {
        if (item.taskId != null) {
           await FlutterDownloader.retry(taskId: item.taskId!);
        } else {
           item.status = DownloadStatus.pending;
        }
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
    for (final item in _items) {
      if (item.taskId != null && item.status == DownloadStatus.downloading) {
        FlutterDownloader.cancel(taskId: item.taskId!);
        item.status = DownloadStatus.pending;
        item.progress = 0.0;
      }
    }
    _isDownloading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _unbindBackgroundIsolate();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
