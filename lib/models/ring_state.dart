enum RingConnectionState { disconnected, scanning, connecting, connected }
enum ZeroEmotion { happy, thinking, excited, sleeping, surprised, listening }
enum ActiveModel { nano, agentic, prime, none }

class RingState {
  final RingConnectionState connectionState;
  final int batteryLevel;         // 0-100
  final String firmwareVersion;
  final int displayBrightness;    // 0-255
  final bool isMicActive;
  final bool isCameraActive;
  final bool isMouseModeActive;
  final ZeroEmotion currentEmotion;
  final ActiveModel activeModel;
  final bool isRecording;
  final double audioLevel;        // 0.0-1.0

  const RingState({
    required this.connectionState,
    required this.batteryLevel,
    required this.firmwareVersion,
    required this.displayBrightness,
    required this.isMicActive,
    required this.isCameraActive,
    required this.isMouseModeActive,
    required this.currentEmotion,
    required this.activeModel,
    required this.isRecording,
    required this.audioLevel,
  });

  factory RingState.initial() {
    return const RingState(
      connectionState: RingConnectionState.disconnected,
      batteryLevel: 0,
      firmwareVersion: '1.0.0',
      displayBrightness: 128,
      isMicActive: false,
      isCameraActive: false,
      isMouseModeActive: false,
      currentEmotion: ZeroEmotion.happy,
      activeModel: ActiveModel.none,
      isRecording: false,
      audioLevel: 0.0,
    );
  }

  RingState copyWith({
    RingConnectionState? connectionState,
    int? batteryLevel,
    String? firmwareVersion,
    int? displayBrightness,
    bool? isMicActive,
    bool? isCameraActive,
    bool? isMouseModeActive,
    ZeroEmotion? currentEmotion,
    ActiveModel? activeModel,
    bool? isRecording,
    double? audioLevel,
  }) {
    return RingState(
      connectionState: connectionState ?? this.connectionState,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      displayBrightness: displayBrightness ?? this.displayBrightness,
      isMicActive: isMicActive ?? this.isMicActive,
      isCameraActive: isCameraActive ?? this.isCameraActive,
      isMouseModeActive: isMouseModeActive ?? this.isMouseModeActive,
      currentEmotion: currentEmotion ?? this.currentEmotion,
      activeModel: activeModel ?? this.activeModel,
      isRecording: isRecording ?? this.isRecording,
      audioLevel: audioLevel ?? this.audioLevel,
    );
  }
}
