// web_interop_stub.dart - Stub implementation for non-web platforms

class WebInterop {
  static void initialize() {
    // No-op on non-web platforms
  }

  static void setupVideoElement() {
    // No-op on non-web platforms
  }

  static Future<void> setupAudioWorklet() async {
    // No-op on non-web platforms
  }

  static void registerChatCallback(Function(String, bool) callback) {
    // No-op on non-web platforms
  }

  static bool isWebSocketConnected() {
    return false;
  }

  static bool activateFlutterUI() {
    return false;
  }

  static bool startAudioRecording() {
    return false;
  }

  static bool stopAudioRecording() {
    return false;
  }

  static bool sendTextMessage(String text) {
    return false;
  }

  static void dispose() {
    // No-op on non-web platforms
  }

  static dynamic getVideoElement() {
    return null;
  }

  static dynamic getCanvasElement() {
    return null;
  }

  static Future<void> startWebcam() async {
    // No-op on non-web platforms
  }

  static void captureImage() {
    // No-op on non-web platforms
  }

  static void setWebcamViewRegistered(bool value) {
    // No-op on non-web platforms
  }
}
