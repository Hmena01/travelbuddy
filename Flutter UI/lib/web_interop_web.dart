// web_interop_web.dart - Web implementation
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'package:logger/logger.dart';

@JS()
external JSAny? eval(String code);

class WebInterop {
  static final Logger _logger = Logger();
  static web.HTMLVideoElement? _videoElement;
  static web.HTMLCanvasElement? _canvasElement;
  static web.MediaStream? _videoStream;
  static bool _webcamViewRegistered = false;
  static web.WebSocket? _webSocket;

  static void initialize() {
    try {
      // Force HTML renderer for webcam support
      web.document.documentElement
          ?.setAttribute('data-flutter-web-renderer', 'html');

      // Debug JS errors
      eval(
          'window.onerror = function(message, source, lineno, colno, error) { console.log("JS ERROR:", message, "at", source, lineno, colno, error); }');

      // Initialize the bridge
      final result = eval('window.flutterBridge.initialize()');
      _logger.i('Flutter bridge initialized: $result');
    } catch (e) {
      _logger.e('Error initializing JS bridge: $e');
    }
  }

  static void setupVideoElement() {
    try {
      // Check if video element already exists
      _videoElement =
          web.document.getElementById('videoElement') as web.HTMLVideoElement?;

      if (_videoElement == null) {
        // Create new if it doesn't exist
        _videoElement = web.HTMLVideoElement()
          ..id = 'videoElement'
          ..autoplay = true
          ..muted = true
          ..style.width = '320px'
          ..style.height = '240px'
          ..style.borderRadius = '20px'
          ..style.display = 'none'; // Initially hidden until placed in Flutter

        _canvasElement = web.HTMLCanvasElement()
          ..id = 'canvasElement'
          ..style.display = 'none';

        web.document.body?.append(_videoElement!);
        web.document.body?.append(_canvasElement!);
        startWebcam();
      } else {
        // Reuse existing video element
        _canvasElement = web.document.getElementById('canvasElement')
            as web.HTMLCanvasElement?;

        // Make sure the element is visible for Flutter
        _videoElement!.style.display = 'block';

        // Check if stream is active
        if (_videoElement!.srcObject == null) {
          startWebcam();
        }
      }

      _webcamViewRegistered = true;
      _logger.i('Video element setup complete');
    } catch (e) {
      _logger.e('Error setting up video element: $e');
    }
  }

  static Future<void> setupAudioWorklet() async {
    try {
      // Try to retrieve an existing audioContext
      dynamic audioContext = eval('window.audioContext');

      if (audioContext == null) {
        // Create new audio context
        audioContext = eval('''
          (() => {
            const AudioContextClass = window.AudioContext || window.webkitAudioContext;
            const context = new AudioContextClass({ sampleRate: 24000 });
            window.audioContext = context;
            return context;
          })()
        ''');
      }

      // Load the external processor module
      await (eval('''
        (async () => {
          await window.audioContext.audioWorklet.addModule('pcm-processor.js');
          const workletNode = new AudioWorkletNode(window.audioContext, 'pcm-processor');
          workletNode.connect(window.audioContext.destination);
          window.workletNode = workletNode;
        })()
      ''') as JSPromise).toDart;

      _logger.i('AudioWorklet initialized successfully');
    } catch (e) {
      _logger.e('Error initializing AudioWorklet: $e');
    }
  }

  static void registerChatCallback(Function(String, bool) callback) {
    try {
      // Create a callback function in the global scope using js.allowInterop
      eval('''
        window.onChatMessage = function(text, isUser) {
          console.log('Chat message received:', isUser ? 'USER' : 'GEMINI', ':', text);
          window.dartChatCallback(text, isUser);
          return true;
        };
      ''');

      // Set the Dart callback
      web.window.setProperty('dartChatCallback'.toJS, callback.toJS);

      // Register with the bridge
      eval('''
        window.flutterBridge.registerCallback("onChatMessage", function(text, isUser) { 
          return window.onChatMessage(text, isUser); 
        });
        window.flutterBridge.registerChatCallback("onChatMessage");
      ''');

      _logger.i('Chat callback registered');
    } catch (e) {
      _logger.e('Error registering chat callback: $e');
    }
  }

  static bool isWebSocketConnected() {
    try {
      final result = eval('window.flutterBridge.isWebSocketConnected()');
      return result?.dartify() == true;
    } catch (e) {
      _logger.e('Error checking connection status: $e');
      return false;
    }
  }

  static bool activateFlutterUI() {
    try {
      eval('console.log("Activating Flutter UI from Dart")');

      if (_videoElement != null) {
        _videoElement!.style.display = 'block';
        _logger.i('Made video element visible');
      }

      final result = eval('window.flutterBridge.activateFlutterUI()');
      return result?.dartify() == true;
    } catch (e) {
      _logger.e('Error activating Flutter UI: $e');
      return false;
    }
  }

  static bool startAudioRecording() {
    try {
      final result = eval('window.flutterBridge.startAudioRecording()');
      return result?.dartify() == true;
    } catch (e) {
      _logger.e('Error starting recording: $e');
      return false;
    }
  }

  static bool stopAudioRecording() {
    try {
      final result = eval('window.flutterBridge.stopAudioRecording()');
      return result?.dartify() == true;
    } catch (e) {
      _logger.e('Error stopping recording: $e');
      return false;
    }
  }

  static bool sendTextMessage(String text) {
    try {
      final encodedText = text.replaceAll("'", "\\'");
      final result =
          eval('window.flutterBridge.sendTextMessage(\'$encodedText\')');
      return result?.dartify() == true;
    } catch (e) {
      _logger.e('Error sending text message: $e');
      return false;
    }
  }

  static void dispose() {
    _webSocket?.close();
    _videoElement?.remove();
    _canvasElement?.remove();
  }

  static dynamic getVideoElement() => _videoElement;
  static dynamic getCanvasElement() => _canvasElement;

  static Future<void> startWebcam() async {
    try {
      final mediaConstraints = web.MediaStreamConstraints(
        video: web.MediaTrackConstraints(
          width: web.ConstrainULongRange(max: 640),
          height: web.ConstrainULongRange(max: 480),
        ),
      );

      final promise =
          web.window.navigator.mediaDevices.getUserMedia(mediaConstraints);
      _videoStream =
          await promise.toDart.then((stream) => stream as web.MediaStream);
      _videoElement!.srcObject = _videoStream;

      _logger.i('Webcam started successfully');
    } catch (e) {
      _logger.e('Error starting webcam: $e');
    }
  }

  static void captureImage() {
    if (_videoElement == null || _canvasElement == null) {
      return;
    }

    try {
      _canvasElement!.width = _videoElement!.videoWidth;
      _canvasElement!.height = _videoElement!.videoHeight;

      final context =
          _canvasElement!.getContext('2d') as web.CanvasRenderingContext2D;
      context.drawImage(_videoElement!, 0, 0);
    } catch (e) {
      _logger.e('Error capturing image: $e');
    }
  }

  static void setWebcamViewRegistered(bool value) {
    _webcamViewRegistered = value;
  }
}
