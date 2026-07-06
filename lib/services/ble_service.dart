import 'dart:async';
import 'dart:typed_data';
import '../models/ring_state.dart';

class BleService {
  final StreamController<Uint8List> _audioController = StreamController<Uint8List>.broadcast();
  final StreamController<Uint8List> _cameraController = StreamController<Uint8List>.broadcast();
  final StreamController<List<double>> _accelController = StreamController<List<double>>.broadcast();
  final StreamController<RingConnectionState> _connectionController = StreamController<RingConnectionState>.broadcast();
  final StreamController<int> _batteryController = StreamController<int>.broadcast();

  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<Uint8List> get cameraStream => _cameraController.stream;
  Stream<List<double>> get accelStream => _accelController.stream;
  Stream<RingConnectionState> get connectionStream => _connectionController.stream;
  Stream<int> get batteryStream => _batteryController.stream;

  bool get isConnected => true; // standalone mode: mock as connected

  void startScan() {
    // Immediately mock successful connection to let user use the app standalone
    _connectionController.add(RingConnectionState.connected);
  }

  Future<void> sendDisplayCommand(Uint8List data) async {
    // No-op for standalone mode
  }

  Future<void> sendRingCommand(Uint8List data) async {
    // No-op for standalone mode
  }

  Future<void> sendEmotionToRing(ZeroEmotion emotion) async {
    // No-op for standalone mode
  }

  void dispose() {
    _audioController.close();
    _cameraController.close();
    _accelController.close();
    _connectionController.close();
    _batteryController.close();
  }
}
