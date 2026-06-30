import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/download_model.dart';

class DownloadService with ChangeNotifier {
  final List<ModelDownloadItem> _items = requiredModels;
  bool _allDownloaded = false;
  bool _isDownloading = false;
  String _statusMessage = '';
  
  final ReceivePort _port = ReceivePort();

  List<ModelDownloadItem> get items => _items;
  bool get allDownloaded => _allDownloaded;
  bool get isDownloading => _isDownloading;
  String get statusMessage => _statusMessage;

  DownloadService() {
    _bindBackgroundIsolate();
    FlutterDownloader.registerCallback(downloadCallback);
  }

  void _bindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {
      String id = data[0];
      int statusValue = data[1];
      int progress = data[2];
      
      DownloadTaskStatus status = DownloadTaskStatus.fromInt(statusValue);
      _handleDownloadUpdate(id, status, progress);
    });
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }

  void _handleDownloadUpdate(String taskId, DownloadTaskStatus status, int progress) {
    bool updated = false;
    for (var item in _items) {
      if (item.id == taskId) {
        if (status == DownloadTaskStatus.running) {
          item.status = DownloadStatus.downloading;
          item.progress = progress / 100.0;
        } else if (status == DownloadTaskStatus.complete) {
          item.status = DownloadStatus.completed;
          item.progress = 1.0;
        } else if (status == DownloadTaskStatus.failed) {
          item.status = DownloadStatus.failed;
          item.errorMessage = 'Download failed — will retry';
          // Auto-retry after 5 seconds
          Future.delayed(const Duration(seconds: 5), () => _retryItem(item));
        } else if (status == DownloadTaskStatus.paused) {
          item.status = DownloadStatus.downloading;
        }
        updated = true;
        break;
      }
    }
    if (updated) {
      _checkAllCompleted();
      notifyListeners();
    }
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

  Future<bool> checkAllDownloaded() async {
    final dir = await getApplicationDocumentsDirectory();
    bool all = true;

    final tasks = await FlutterDownloader.loadTasks();

    for (final item in _items) {
      final file = File('${dir.path}/${item.fileName}');
      if (file.existsSync() && file.lengthSync() > 1024) {
        item.status = DownloadStatus.completed;
        item.progress = 1.0;
      } else {
        // Find existing task
        final task = tasks?.where((t) => t.filename == item.fileName).lastOrNull;
        if (task != null) {
          item.id = task.taskId;
          if (task.status == DownloadTaskStatus.complete) {
             item.status = DownloadStatus.completed;
             item.progress = 1.0;
          } else if (task.status == DownloadTaskStatus.running || task.status == DownloadTaskStatus.paused) {
             item.status = DownloadStatus.downloading;
             item.progress = task.progress / 100.0;
             all = false;
          } else if (task.status == DownloadTaskStatus.failed) {
             item.status = DownloadStatus.failed;
             all = false;
          }
        } else {
          item.status = DownloadStatus.pending;
          item.progress = 0.0;
          all = false;
        }
      }
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
    
    // Check connectivity first
    if (!await _hasConnectivity()) {
      _statusMessage = 'No internet connection. Please connect to WiFi or mobile data.';
      notifyListeners();
      // Listen for connectivity changes and auto-start
      Connectivity().onConnectivityChanged.listen((result) {
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
    notifyListeners();

    final dir = await getApplicationDocumentsDirectory();

    for (final item in _items) {
      if (item.status == DownloadStatus.completed) continue;
      
      // Cancel any existing task for this item to prevent conflicts
      if (item.id.isNotEmpty && item.status == DownloadStatus.failed) {
        try {
          await FlutterDownloader.remove(taskId: item.id, shouldDeleteContent: true);
        } catch (_) {}
        item.id = '';
      }
      
      if (item.status == DownloadStatus.pending || item.status == DownloadStatus.failed) {
        // Delete partial file if exists
        final file = File('${dir.path}/${item.fileName}');
        if (file.existsSync() && file.lengthSync() < item.fileSizeMB * 1024 * 1024 * 0.9) {
          try { file.deleteSync(); } catch (_) {}
        }
        
        final taskId = await FlutterDownloader.enqueue(
          url: item.url,
          savedDir: dir.path,
          fileName: item.fileName,
          showNotification: true, 
          openFileFromNotification: false,
          requiresStorageNotLow: false,
        );
        if (taskId != null) {
          item.id = taskId;
          item.status = DownloadStatus.downloading;
          item.errorMessage = null;
        }
      } else if (item.status == DownloadStatus.downloading && item.id.isNotEmpty) {
         // resume if paused
         try {
           final newId = await FlutterDownloader.resume(taskId: item.id);
           if (newId != null) item.id = newId;
         } catch (e) {
           // Resume failed — re-enqueue
           item.status = DownloadStatus.pending;
           item.id = '';
         }
      }
    }
    notifyListeners();
  }

  Future<void> _retryItem(ModelDownloadItem item) async {
    if (item.status != DownloadStatus.failed) return;
    if (!await _hasConnectivity()) return;
    
    final dir = await getApplicationDocumentsDirectory();
    
    // Remove old task
    if (item.id.isNotEmpty) {
      try {
        await FlutterDownloader.remove(taskId: item.id, shouldDeleteContent: true);
      } catch (_) {}
    }
    
    // Delete partial file
    final file = File('${dir.path}/${item.fileName}');
    if (file.existsSync()) {
      try { file.deleteSync(); } catch (_) {}
    }
    
    // Re-enqueue
    final taskId = await FlutterDownloader.enqueue(
      url: item.url,
      savedDir: dir.path,
      fileName: item.fileName,
      showNotification: true,
      openFileFromNotification: false,
      requiresStorageNotLow: false,
    );
    if (taskId != null) {
      item.id = taskId;
      item.status = DownloadStatus.downloading;
      item.errorMessage = null;
      notifyListeners();
    }
  }

  void _checkAllCompleted() {
    _allDownloaded = _items.every((i) => i.status == DownloadStatus.completed);
    if (_allDownloaded) {
      _isDownloading = false;
      _statusMessage = 'All models ready!';
    }
  }

  Future<void> retryFailed() async {
    for (final item in _items) {
      if (item.status == DownloadStatus.failed) {
        item.status = DownloadStatus.pending;
        item.id = '';
      }
    }
    notifyListeners();
    _isDownloading = false; // Reset to allow downloadAll
    await downloadAll();
  }

  Future<String?> getModelPath(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$fileName';
    final file = File(path);
    return (file.existsSync() && file.lengthSync() > 1024) ? path : null;
  }

  void cancelAll() {
    FlutterDownloader.cancelAll();
    _isDownloading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    super.dispose();
  }
}
