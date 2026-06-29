import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/ring_state.dart';
import '../utils/constants.dart';

class BleService {
  final StreamController<Uint8List> _audioController = StreamController<Uint8List>.broadcast();
  final StreamController<Uint8List> _cameraController = StreamController<Uint8List>.broadcast();
  final StreamController<List<double>> _accelController = StreamController<List<double>>.broadcast();
  final StreamController<RingConnectionState> _connectionController = StreamController<RingConnectionState>.broadcast();
  final StreamController<int> _batteryController = StreamController<int>.broadcast();

  BluetoothDevice? _connectedDevice;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  int _reconnectAttempt = 0;
  final List<StreamSubscription> _subscriptions = [];

  BluetoothCharacteristic? _displayCharacteristic;
  BluetoothCharacteristic? _commandCharacteristic;

  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<Uint8List> get cameraStream => _cameraController.stream;
  Stream<List<double>> get accelStream => _accelController.stream;
  Stream<RingConnectionState> get connectionStream => _connectionController.stream;
  Stream<int> get batteryStream => _batteryController.stream;

  bool get isConnected => _connectedDevice != null && !_isConnecting;

  void startScan() {
    _connectionController.add(RingConnectionState.scanning);
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));

    _subscriptions.add(FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        final deviceName = r.device.platformName.isNotEmpty 
            ? r.device.platformName 
            : r.advertisementData.advName;
        if (deviceName == AppConstants.BLE_DEVICE_NAME) {
          FlutterBluePlus.stopScan();
          _connect(r.device);
          break;
        }
      }
    }));

    _subscriptions.add(FlutterBluePlus.isScanning.listen((isScanning) {
      if (!isScanning && _connectedDevice == null && !_isConnecting) {
        _connectionController.add(RingConnectionState.disconnected);
        _scheduleReconnect();
      }
    }));
  }

  Future<void> _connect(BluetoothDevice device) async {
    _isConnecting = true;
    _connectionController.add(RingConnectionState.connecting);

    try {
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;
      
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == AppConstants.SERVICE_UUID.toLowerCase()) {
          for (BluetoothCharacteristic c in service.characteristics) {
            final uuid = c.uuid.toString().toLowerCase();
            if (uuid == AppConstants.AUDIO_UUID.toLowerCase()) {
              await c.setNotifyValue(true);
              _subscriptions.add(c.onValueReceived.listen((value) {
                _audioController.add(Uint8List.fromList(value));
              }));
            } else if (uuid == AppConstants.ACCEL_UUID.toLowerCase()) {
              await c.setNotifyValue(true);
              _subscriptions.add(c.onValueReceived.listen((value) {
                if (value.length >= 12) {
                  final byteData = ByteData.sublistView(Uint8List.fromList(value));
                  List<double> accel = [
                    byteData.getFloat32(0, Endian.little),
                    byteData.getFloat32(4, Endian.little),
                    byteData.getFloat32(8, Endian.little),
                  ];
                  _accelController.add(accel);
                }
              }));
            } else if (uuid == AppConstants.CAMERA_UUID.toLowerCase()) {
              await c.setNotifyValue(true);
              _subscriptions.add(c.onValueReceived.listen((value) {
                _cameraController.add(Uint8List.fromList(value));
              }));
            } else if (uuid == AppConstants.DISPLAY_UUID.toLowerCase()) {
              _displayCharacteristic = c;
            } else if (uuid == AppConstants.COMMAND_UUID.toLowerCase()) {
              _commandCharacteristic = c;
            }
          }
        }
      }

      _connectionController.add(RingConnectionState.connected);
      _reconnectAttempt = 0;
      _isConnecting = false;

      _subscriptions.add(device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _connectionController.add(RingConnectionState.disconnected);
          _scheduleReconnect();
        }
      }));

    } catch (e) {
      _isConnecting = false;
      _connectedDevice = null;
      _connectionController.add(RingConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() async {
    if (!_shouldReconnect) return;
    
    int delay = AppConstants.RECONNECT_DELAYS[
      min(_reconnectAttempt, AppConstants.RECONNECT_DELAYS.length - 1)
    ];
    _reconnectAttempt++;
    
    _connectionController.add(RingConnectionState.scanning);
    await Future.delayed(Duration(seconds: delay));
    startScan();
  }

  Future<void> sendDisplayCommand(Uint8List data) async {
    if (_displayCharacteristic != null) {
      await _displayCharacteristic!.write(data, withoutResponse: false);
    }
  }

  Future<void> sendRingCommand(Uint8List data) async {
    if (_commandCharacteristic != null) {
      await _commandCharacteristic!.write(data, withoutResponse: false);
    }
  }

  Future<void> sendEmotionToRing(ZeroEmotion emotion) async {
    Map<ZeroEmotion, int> emotions = {
      ZeroEmotion.happy: 0,
      ZeroEmotion.thinking: 1,
      ZeroEmotion.excited: 2,
      ZeroEmotion.sleeping: 3,
      ZeroEmotion.surprised: 4,
      ZeroEmotion.listening: 5,
    };
    await sendDisplayCommand(Uint8List.fromList([0x03, emotions[emotion]!]));
  }

  void dispose() {
    _shouldReconnect = false;
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _connectedDevice?.disconnect();
    _audioController.close();
    _cameraController.close();
    _accelController.close();
    _connectionController.close();
    _batteryController.close();
  }
}
