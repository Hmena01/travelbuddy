// NativeFlow Translation App - Home Page
// For web development, run with: flutter run -d chrome --web-renderer canvaskit --web-browser-flag '--disable-web-security' -t lib/main.dart --release

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart'; // Import SoLoud
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Keep for animations
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';

// Define theme colors (assuming NativeFlowTheme class exists)
class NativeFlowTheme {
  static const Color primaryBlue = Color(0xFF4D96FF);
  static const Color accentPurple = Color(0xFF5C33FF);
  static const Color lightBlue = Color(0xFF8BC7FF);
  static const Color backgroundGrey = Color(0xFFF9FAFC);
  static const Color textDark = Color(0xFF2D3748);

  // Gradient for background and buttons
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, accentPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // Core components
  late WebSocketChannel channel;
  final record = AudioRecorder();

  // Camera components
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  String? _lastCapturedImagePath;
  final List<String> _transcriptionHistory = [];
  bool _showCameraPopup = false;

  // State variables
  bool isRecording = false;
  bool isConnecting = true;
  bool isAiSpeaking = false;
  String serverResponse = '';
  String connectionStatus = 'Initializing...';
  bool _audioInitAttempted = false;
  bool _audioInitSucceeded = false;

  // Audio buffers
  List<int> audioBuffer = [];
  final List<int> _pcmBuffer = [];

  // Timers
  Timer? sendTimer;
  Timer? silenceTimer;
  Timer? _speakingTimeoutTimer;
  DateTime? _lastAudioChunkTime;
  int silentSeconds = 0;

  // Audio state
  AudioSource? currentSound;
  SoundHandle? _currentSoundHandle;
  StreamSubscription? _audioEventSubscription;

  // Animation controllers
  late AnimationController _logoAnimationController;
  late AnimationController _buttonScaleController;
  late AnimationController _buttonSlideController;
  late AnimationController _statusAnimationController;
  late AnimationController _micIconController;
  late AnimationController _speakingAnimationController;
  late AnimationController _progressAnimationController;

  // Animations
  late Animation<double> _logoFadeAnimation;
  late Animation<Offset> _logoSlideAnimation;
  late Animation<double> _buttonScaleAnimation;
  late Animation<Offset> _buttonSlideAnimation;
  late Animation<double> _statusFadeAnimation;
  late Animation<Offset> _statusSlideAnimation;
  late Animation<double> _micIconScaleAnimation;
  late Animation<double> _speakingScaleAnimation;
  late Animation<double> _progressFadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeApp();
  }

  void _initAnimations() {
    // Initialize animation controllers
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _buttonScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _buttonSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _statusAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _micIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _speakingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Set up animations
    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoAnimationController, curve: Curves.easeOut),
    );
    _logoSlideAnimation = Tween<Offset>(
      begin: const Offset(-0.2, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
          parent: _logoAnimationController, curve: Curves.easeOutQuad),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
          parent: _buttonScaleController, curve: Curves.easeInOutCubic),
    );
    _buttonSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
          parent: _buttonSlideController, curve: Curves.easeOutQuad),
    );
    _statusFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _statusAnimationController, curve: Curves.easeOut),
    );
    _statusSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
          parent: _statusAnimationController, curve: Curves.easeOutQuad),
    );
    _micIconScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _micIconController, curve: Curves.easeInOut),
    );
    _speakingScaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
          parent: _speakingAnimationController, curve: Curves.easeInOut),
    );
    _progressFadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
          parent: _progressAnimationController, curve: Curves.easeInOut),
    );

    // Start animations
    _logoAnimationController.forward();
    _buttonSlideController.forward();
    _statusAnimationController.forward();
  }

  Future<void> _initializeApp() async {
    setState(() {
      connectionStatus = 'Initializing...';
    });

    try {
      // Skip camera initialization on startup - only initialize when user requests it
      // await _getCameraList();

      // For web platform, delay SoLoud initialization until user interaction
      // due to AudioContext restrictions
      if (!kIsWeb) {
        await _initializeSoLoud();
      }

      // Initialize WebSocket connection
      await _initConnection();

      // Test audio playback after initialization (only on non-web platforms)
      if (!kIsWeb && _audioInitSucceeded) {
        _testAudioPlayback();
      }
    } catch (e) {
      log('Initialization error: $e');
      setState(() {
        connectionStatus = 'Initialization failed: $e';
        isConnecting = false;
      });
    }
  }

  Future<void> _getCameraList() async {
    try {
      setState(() {
        connectionStatus = 'Detecting cameras...';
      });

      // Get available cameras
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        log('No cameras available on this device');
        return;
      }

      log('Found ${_cameras!.length} cameras');
    } catch (e) {
      log('Camera detection error: $e');
      _cameras = null;
    }
  }

  Future<void> _initializeCamera() async {
    if (_cameras == null || _cameras!.isEmpty) {
      throw Exception('No cameras available');
    }

    try {
      log('Initializing camera...');

      // Use the first camera (usually back camera)
      _cameraController = CameraController(
        _cameras!.first,
        ResolutionPreset.medium,
        enableAudio: false, // We handle audio separately
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _initializeControllerFuture = _cameraController!.initialize();
      await _initializeControllerFuture;

      if (_cameraController!.value.isInitialized) {
        _isCameraInitialized = true;
        log('Camera initialized successfully');
      } else {
        log('Camera controller not properly initialized');
        _isCameraInitialized = false;
        throw Exception('Camera failed to initialize');
      }
    } catch (e) {
      log('Camera initialization error: $e');
      _isCameraInitialized = false;
      _cameraController?.dispose();
      _cameraController = null;
      throw e;
    }
  }

  Future<void> _initializeSoLoud() async {
    // This method is now only used for native platforms during app startup
    if (kIsWeb || _audioInitAttempted) {
      log('Audio initialization skipped (web platform uses gesture-based init)');
      return;
    }

    _audioInitAttempted = true;

    setState(() {
      connectionStatus = 'Initializing audio engine...';
    });

    try {
      await SoLoud.instance.init();
      _audioInitSucceeded = await _checkSoLoudInitialized();

      if (_audioInitSucceeded) {
        log('SoLoud initialized successfully on native platform');

        // Set global volume to ensure audio is audible
        SoLoud.instance.setGlobalVolume(1.0);
        log('Global volume set to 1.0');

        if (mounted) {
          setState(() {
            connectionStatus = 'Connected';
          });
        }
      } else {
        log('SoLoud initialization failed on native platform');
        if (mounted) {
          setState(() {
            connectionStatus = 'Connected (Audio unavailable)';
          });
        }
      }
    } catch (e) {
      log('SoLoud initialization error: $e');
      _audioInitSucceeded = false;
      if (mounted) {
        setState(() {
          connectionStatus = 'Connected (Audio failed)';
        });
      }
    }
  }

  Future<bool> _checkSoLoudInitialized() async {
    try {
      return SoLoud.instance.isInitialized;
    } catch (e) {
      log('Error checking SoLoud initialization: $e');
      return false;
    }
  }

  bool get _isAudioAvailable {
    try {
      return _audioInitSucceeded && SoLoud.instance.isInitialized;
    } catch (e) {
      return false;
    }
  }

  Future<void> _safeAudioOperation(Future<void> Function() operation) async {
    if (!_isAudioAvailable) return;
    try {
      await operation();
    } catch (e) {
      log('Audio operation failed: $e');
    }
  }

  Future<void> _initConnection() async {
    setState(() {
      connectionStatus = 'Connecting to server...';
    });

    try {
      final wsUrl = _getWebSocketUrl();
      log('Connecting to WebSocket URL: $wsUrl');

      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _listenForAudioStream();
      _listenToSoLoudEvents();

      setState(() {
        isConnecting = false;
        connectionStatus = 'Connected';
        serverResponse = '';
      });

      log('WebSocket connected successfully');
    } catch (e) {
      log('Connection error: $e');
      if (mounted) {
        setState(() {
          isConnecting = false;
          connectionStatus = 'Connection failed: $e';
        });
      }
    }
  }

  String _getWebSocketUrl() {
    if (kIsWeb) {
      return 'ws://localhost:9083';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ws://10.0.2.2:9083';
    } else {
      return 'ws://localhost:9083';
    }
  }

  @override
  void dispose() {
    // Dispose animation controllers
    _logoAnimationController.dispose();
    _buttonScaleController.dispose();
    _buttonSlideController.dispose();
    _statusAnimationController.dispose();
    _micIconController.dispose();
    _speakingAnimationController.dispose();
    _progressAnimationController.dispose();

    // Cancel timers
    silenceTimer?.cancel();
    sendTimer?.cancel();
    _speakingTimeoutTimer?.cancel();
    _audioEventSubscription?.cancel();

    // Cleanup camera
    _cameraController?.dispose();

    // Cleanup recording and WebSocket
    if (isRecording) {
      stopStream();
    } else {
      try {
        channel.sink.close();
      } catch (e) {
        log("Error closing WebSocket channel: $e");
      }
    }
    record.dispose();

    // Cleanup SoLoud resources
    _cleanupAudio();

    log('HomePage disposed');
    super.dispose();
  }

  void _cleanupAudio() {
    if (!_isAudioAvailable || !_audioInitSucceeded) return;

    _safeAudioOperation(() async {
      if (currentSound != null) {
        SoLoud.instance.disposeSource(currentSound!);
        currentSound = null;
      }
      if (_currentSoundHandle != null) {
        SoLoud.instance.stop(_currentSoundHandle!);
        _currentSoundHandle = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen during initialization
    if (isConnecting) {
      return _buildLoadingScreen();
    }

    return Stack(
      children: [
        _buildMainScreen(),
        if (_showCameraPopup) _buildCameraPopup(),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: NativeFlowTheme.backgroundGrey,
      appBar: AppBar(
        title: _buildLogo(),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(connectionStatus, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainScreen() {
    return Scaffold(
      backgroundColor: NativeFlowTheme.backgroundGrey,
      appBar: AppBar(
        title: _buildLogo(),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        actions: [
          // Camera icon button
          IconButton(
            onPressed: () => _showCameraInterface(),
            icon: Icon(
              Icons.camera_alt,
              color: NativeFlowTheme.primaryBlue,
            ),
            tooltip: 'Open Camera',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, NativeFlowTheme.backgroundGrey],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Transcription Section
              _buildTranscriptionSection(),

              // Status and Control Section
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isConnecting)
                        FadeTransition(
                          opacity: _progressFadeAnimation,
                          child: const CircularProgressIndicator(),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: _buildStatusMessage(),
                      ),
                      if (isRecording) _buildRecordingIndicator(),
                      if (isAiSpeaking) _buildSpeakingIndicator(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildRecordingButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildLogo() {
    return FadeTransition(
      opacity: _logoFadeAnimation,
      child: SlideTransition(
        position: _logoSlideAnimation,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Native',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: NativeFlowTheme.primaryBlue,
              ),
            ),
            Text(
              'Flow',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: NativeFlowTheme.accentPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    String message;
    if (isConnecting) {
      message = connectionStatus;
    } else if (serverResponse.isNotEmpty) {
      message = serverResponse;
    } else if (isAiSpeaking) {
      message = 'Gemini is speaking...';
    } else if (isRecording) {
      message = 'Listening...';
    } else {
      // Default message based on audio availability
      if (kIsWeb && !_audioInitAttempted) {
        message =
            'Press microphone to start (Audio will initialize on first use)';
      } else if (!_isAudioAvailable) {
        message = 'Press microphone to start (Text-only mode)';
      } else {
        message = 'Press microphone to start speaking';
      }
    }

    final textColor = isAiSpeaking
        ? NativeFlowTheme.accentPurple
        : isRecording
            ? NativeFlowTheme.primaryBlue
            : NativeFlowTheme.textDark;

    return FadeTransition(
      opacity: _statusFadeAnimation,
      child: SlideTransition(
        position: _statusSlideAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: isAiSpeaking || isRecording
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FadeTransition(
        opacity: const AlwaysStoppedAnimation(1.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _micIconScaleAnimation,
              child: Icon(
                Icons.mic,
                color: NativeFlowTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Recording will auto-stop after 3 seconds of silence',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeakingIndicator() {
    return ScaleTransition(
      scale: _speakingScaleAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: NativeFlowTheme.accentPurple.withAlpha(26),
        ),
        child: Icon(
          Icons.hearing,
          color: NativeFlowTheme.accentPurple,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildTranscriptionSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.transcribe,
                color: NativeFlowTheme.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Live Transcription',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: NativeFlowTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 120,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NativeFlowTheme.backgroundGrey,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_transcriptionHistory.isEmpty)
                    Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.grey.shade400,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Transcriptions will appear here...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Speak clearly for better recognition',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  else
                    for (int i = _transcriptionHistory.length - 1; i >= 0; i--)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _transcriptionHistory[i].startsWith('👤')
                                ? Colors.blue.shade50
                                : Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _transcriptionHistory[i].startsWith('👤')
                                  ? Colors.blue.shade200
                                  : Colors.purple.shade200,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _transcriptionHistory[i],
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingButton() {
    return SlideTransition(
      position: _buttonSlideAnimation,
      child: ScaleTransition(
        scale: isRecording || isAiSpeaking
            ? _buttonScaleAnimation
            : const AlwaysStoppedAnimation(1.0),
        child: FloatingActionButton(
          onPressed: isConnecting || isAiSpeaking ? null : _toggleRecording,
          backgroundColor: isRecording
              ? Colors.red
              : isAiSpeaking
                  ? NativeFlowTheme.accentPurple
                  : NativeFlowTheme.primaryBlue,
          child: Icon(
            isRecording
                ? Icons.stop
                : isAiSpeaking
                    ? Icons.hearing
                    : Icons.mic,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Camera Methods
  Future<void> _showCameraInterface() async {
    setState(() {
      _showCameraPopup = true;
    });

    try {
      // Get camera list first if not already done
      if (_cameras == null) {
        await _getCameraList();
      }

      // Then initialize the camera
      await _initializeCamera();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      log('Error initializing camera: $e');
      if (mounted) {
        setState(() {
          _showCameraPopup = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera initialization failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildCameraPopup() {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(51),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NativeFlowTheme.primaryBlue,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Camera',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showCameraPopup = false;
                          _isCameraInitialized = false;
                        });
                        _cameraController?.dispose();
                        _cameraController = null;
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Camera Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black87,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // Camera Preview
                        if (_isCameraInitialized && _cameraController != null)
                          FutureBuilder<void>(
                            future: _initializeControllerFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.done) {
                                return SizedBox(
                                  width: double.infinity,
                                  height: double.infinity,
                                  child: CameraPreview(_cameraController!),
                                );
                              } else {
                                return Container(
                                  color: Colors.black87,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white),
                                  ),
                                );
                              }
                            },
                          )
                        else
                          Container(
                            color: Colors.black87,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.camera_alt,
                                      color: Colors.white54, size: 48),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Initializing camera...',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 16),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () async {
                                      try {
                                        await _initializeCamera();
                                        if (mounted) setState(() {});
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Failed to retry camera: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          NativeFlowTheme.primaryBlue,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Retry Camera'),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Camera Controls
                        if (_isCameraInitialized)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Take Picture Button
                                FloatingActionButton(
                                  onPressed: _takePicture,
                                  backgroundColor: Colors.white,
                                  child: const Icon(Icons.camera_alt,
                                      color: Colors.black87),
                                ),
                                // Switch Camera Button (if multiple cameras)
                                if (_cameras != null && _cameras!.length > 1)
                                  FloatingActionButton(
                                    mini: true,
                                    onPressed: _switchCamera,
                                    backgroundColor:
                                        Colors.white.withAlpha(200),
                                    child: const Icon(Icons.switch_camera,
                                        color: Colors.black87),
                                  ),
                              ],
                            ),
                          ),

                        // Last captured image thumbnail
                        if (_lastCapturedImagePath != null)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: GestureDetector(
                              onTap: () => _showImagePreview(),
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(
                                    File(_lastCapturedImagePath!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length <= 1) return;

    try {
      // Find current camera index
      int currentIndex = _cameras!.indexWhere(
        (camera) =>
            camera.lensDirection ==
            _cameraController!.description.lensDirection,
      );

      // Switch to next camera
      int nextIndex = (currentIndex + 1) % _cameras!.length;

      // Dispose current controller
      await _cameraController?.dispose();

      // Initialize new camera
      _cameraController = CameraController(
        _cameras![nextIndex],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _initializeControllerFuture = _cameraController!.initialize();
      await _initializeControllerFuture;

      if (mounted) {
        setState(() {
          _isCameraInitialized = _cameraController!.value.isInitialized;
        });
      }
    } catch (e) {
      log('Error switching camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch camera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImagePreview() {
    if (_lastCapturedImagePath == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              Center(
                child: Image.file(File(_lastCapturedImagePath!)),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _cameraController == null) {
      log('Camera not initialized');
      return;
    }

    try {
      // Ensure camera is initialized
      await _initializeControllerFuture;

      // Take the picture
      final XFile image = await _cameraController!.takePicture();

      setState(() {
        _lastCapturedImagePath = image.path;
      });

      log('Picture taken: ${image.path}');

      // Send image to backend
      await _sendImageToBackend(image);
    } catch (e) {
      log('Error taking picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to take picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendImageToBackend(XFile image) async {
    try {
      // Read image as bytes
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Send image data to backend via WebSocket
      final message = jsonEncode({
        "realtime_input": {
          "media_chunks": [
            {
              "mime_type": "image/jpeg",
              "data": base64Image,
            },
          ],
        },
      });

      if (channel.closeCode == null) {
        channel.sink.add(message);
        log('Image sent to backend: ${bytes.length} bytes');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image sent for analysis'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        log('WebSocket is closed, cannot send image');
      }
    } catch (e) {
      log('Error sending image to backend: $e');
    }
  }

  // Audio Recording Methods
  Future<void> _toggleRecording() async {
    if (isRecording) {
      _stopRecording();
    } else {
      // Initialize SoLoud IMMEDIATELY on first user interaction for web
      // This MUST happen synchronously in the gesture handler to preserve context
      if (kIsWeb && !_audioInitAttempted) {
        _audioInitAttempted = true;
        log('IMMEDIATE user gesture - initializing SoLoud synchronously...');

        try {
          // Call SoLoud.init() directly in the gesture handler - no delays or async operations before this!
          await SoLoud.instance.init();
          _audioInitSucceeded = SoLoud.instance.isInitialized;

          if (_audioInitSucceeded) {
            log('SoLoud initialized successfully on web with user gesture');

            // Set global volume to ensure audio is audible
            SoLoud.instance.setGlobalVolume(1.0);
            log('Global volume set to 1.0 for web');

            if (mounted) {
              setState(() {
                connectionStatus = 'Connected';
              });
            }
          } else {
            log('SoLoud initialization failed on web');
            _audioInitSucceeded = false;
            if (mounted) {
              setState(() {
                connectionStatus = 'Connected (Audio failed)';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Audio playback unavailable - translation will work in text mode'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        } catch (e) {
          log('SoLoud initialization error in gesture handler: $e');
          _audioInitSucceeded = false;
          if (mounted) {
            setState(() {
              connectionStatus = 'Connected (Audio error)';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Audio initialization failed - using text mode'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (isConnecting || isAiSpeaking) {
      log('Cannot record while connecting or AI speaking');
      return;
    }

    // Check microphone permission
    bool hasPermission = await record.hasPermission();
    if (!hasPermission) {
      log('Microphone permission not granted');
      if (mounted) _showPermissionAlert(context);
      return;
    }

    // Clear previous state
    setState(() {
      serverResponse = '';
    });
    _pcmBuffer.clear();

    // Clear audio sources if available
    await _safeAudioOperation(() async {
      await SoLoud.instance.disposeAllSources();
    });

    // Send initial configuration
    channel.sink.add(jsonEncode({
      "setup": {
        "generation_config": {"language": "en"},
      },
    }));
    log('Config sent');

    try {
      final stream = await record.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      audioBuffer.clear();
      sendTimer?.cancel();
      _startSilenceDetection();

      // Optimized audio data sending - reduced intervals for real-time performance
      sendTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (audioBuffer.isNotEmpty) {
          _sendBufferedAudio();
          silentSeconds = 0;
        }
      });

      stream.listen(
        (List<int> chunk) {
          if (chunk.isNotEmpty) {
            audioBuffer.addAll(chunk);
            silentSeconds = 0;

            // Send audio more frequently for better real-time performance
            if (audioBuffer.length >= 1600) {
              // ~100ms of audio at 16kHz
              _sendBufferedAudio();
            }
          }
        },
        onError: (error) {
          log('Recording Stream error: $error');
          if (mounted) setState(() => isRecording = false);
          sendTimer?.cancel();
          silenceTimer?.cancel();
        },
        onDone: () {
          log('Recording Stream done');
          sendTimer?.cancel();
          silenceTimer?.cancel();
          if (audioBuffer.isNotEmpty) _sendBufferedAudio();
          if (mounted) setState(() => isRecording = false);
        },
      );

      if (mounted) setState(() => isRecording = true);
    } catch (e) {
      log('Error starting recording stream: $e');
      if (mounted) {
        setState(() => serverResponse = "Error starting recording.");
      }
    }
  }

  void _stopRecording() {
    silenceTimer?.cancel();
    sendTimer?.cancel();
    record.stop();
    if (audioBuffer.isNotEmpty) _sendBufferedAudio();
    log('Recording stopped');

    // Add user input indicator to transcription history
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _transcriptionHistory
                .add('👤 You: [Spoke in audio - waiting for translation...]');

            // Keep only last 8 transcriptions for better performance
            if (_transcriptionHistory.length > 8) {
              _transcriptionHistory.removeAt(0);
            }
          });
        }
      });
    }

    if (mounted) setState(() => isRecording = false);
  }

  void _startSilenceDetection() {
    silenceTimer?.cancel();
    silentSeconds = 0;

    silenceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      silentSeconds++;
      if (silentSeconds >= 3) {
        log('3 seconds of silence detected - stopping recording for faster processing');
        _stopRecording();
        silenceTimer?.cancel();
      }
    });
  }

  void _sendBufferedAudio() {
    if (audioBuffer.isNotEmpty && channel.closeCode == null) {
      String base64Audio = base64Encode(audioBuffer);
      channel.sink.add(jsonEncode({
        "realtime_input": {
          "media_chunks": [
            {"mime_type": "audio/pcm", "data": base64Audio},
          ],
        },
      }));
      audioBuffer.clear();
    } else if (channel.closeCode != null) {
      log('WebSocket closed, cannot send audio.');
      if (isRecording) {
        _stopRecording();
      }
    }
  }

  void stopStream() async {
    silenceTimer?.cancel();
    sendTimer?.cancel();
    await record.stop();
    if (audioBuffer.isNotEmpty) _sendBufferedAudio();
    channel.sink.close();
    log('Stream & WebSocket closed');
    if (mounted) setState(() => isRecording = false);
  }

  void _showPermissionAlert(BuildContext context) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Microphone Permission Required'),
          content: const Text(
            'This app needs microphone access to record audio. '
            'Please enable microphone access in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // You can add permission_handler package for opening settings
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  // Audio Playback Methods
  void _listenToSoLoudEvents() {
    _audioEventSubscription?.cancel();

    // Only start audio event listening if audio is available
    if (!_isAudioAvailable) {
      log('Audio not available - skipping SoLoud event listener');
      return;
    }

    // Additional safety check for web
    if (kIsWeb && !_audioInitSucceeded) {
      log('Audio not properly initialized on web - skipping SoLoud event listener');
      return;
    }

    _audioEventSubscription = Stream.periodic(
      const Duration(milliseconds: 500),
    ).listen((_) {
      if (_currentSoundHandle != null && isAiSpeaking && _isAudioAvailable) {
        try {
          // Check if the sound handle is still valid (simpler approach)
          final isValid =
              SoLoud.instance.getIsValidVoiceHandle(_currentSoundHandle!);
          if (!isValid) {
            if (mounted) {
              setState(() {
                isAiSpeaking = false;
                _currentSoundHandle = null;
              });
            }
            log('Sound playback completed (handle no longer valid)');
          }
        } catch (e) {
          if (mounted && isAiSpeaking) {
            setState(() {
              isAiSpeaking = false;
              _currentSoundHandle = null;
            });
          }
          log('Sound playback completed (handle invalid): $e');
        }
      }
    });
    log('Started periodic check for sound completion');
  }

  void _listenForAudioStream() {
    channel.stream.listen(
      (message) {
        try {
          var data = jsonDecode(message as String);

          if (data['text'] != null) {
            if (mounted) {
              setState(() => serverResponse = "${data['text']}");

              // Add Gemini's text response to transcription history
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _transcriptionHistory.add('🤖 Gemini: ${data['text']}');

                    // Keep only last 8 transcriptions for better performance
                    if (_transcriptionHistory.length > 8) {
                      _transcriptionHistory.removeAt(0);
                    }
                  });
                }
              });
            }
            log('Received text: ${data['text']}');
          } else if (data['transcription'] != null) {
            // Handle transcription data from backend - optimized for real-time
            final transcriptionData = data['transcription'];
            final transcriptionText = transcriptionData['text'] as String?;
            final source = transcriptionData['source'] as String?;
            final status = transcriptionData['status'] as String?;

            if (transcriptionText != null && transcriptionText.isNotEmpty) {
              // Skip unclear or error transcriptions from displaying in history
              if (transcriptionText.contains('<Not recognizable>') ||
                  transcriptionText.contains('UNCLEAR_AUDIO') ||
                  transcriptionText.contains('not recognizable') ||
                  transcriptionText.contains('Audio unclear') ||
                  transcriptionText.contains('Transcription failed') ||
                  status == 'unclear' ||
                  status == 'error') {
                log('Skipping unclear transcription: $transcriptionText');
                return; // Don't add to history
              }

              if (mounted) {
                // Batch UI updates for better performance
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      final prefix =
                          source == 'user_input' ? '👤 You: ' : '🤖 AI: ';
                      _transcriptionHistory.add('$prefix$transcriptionText');

                      // Keep only last 8 transcriptions for better performance
                      if (_transcriptionHistory.length > 8) {
                        _transcriptionHistory.removeAt(0);
                      }
                    });
                  }
                });
              }
              log('Transcription ($source): $transcriptionText');
            }
          } else if (data['audio_start'] == true) {
            log('Received audio_start signal');
            if (mounted) {
              setState(() {
                isAiSpeaking = true;
                _pcmBuffer.clear();
              });
            }
            _lastAudioChunkTime = DateTime.now();
            _speakingTimeoutTimer?.cancel();
            _startSpeakingTimeoutCheck();
          } else if (data['audio'] != null) {
            // Optimized audio chunk processing - no UI updates here
            String base64Audio = data['audio'] as String;
            var pcmBytes = base64Decode(base64Audio);
            _pcmBuffer.addAll(pcmBytes);
            _lastAudioChunkTime = DateTime.now();

            _speakingTimeoutTimer?.cancel();
            _startSpeakingTimeoutCheck();
          } else if (data['turn_complete'] == true) {
            log('Turn complete signal received');
            _speakingTimeoutTimer?.cancel();

            if (_pcmBuffer.isNotEmpty) {
              log('Turn complete: Playing buffered audio (${_pcmBuffer.length} bytes)');

              // Save audio for debugging on non-web platforms
              if (!kIsWeb) {
                _saveAudioForDebug(List<int>.from(_pcmBuffer));
              }

              _playAudioWithSoloud(List<int>.from(_pcmBuffer));
              _pcmBuffer.clear();
            } else {
              log('Turn complete received, but no audio was buffered.');
              if (mounted && isAiSpeaking) {
                setState(() => isAiSpeaking = false);
              }
            }
          }
        } catch (e, s) {
          log('WebSocket message processing error: $e\n$s',
              error: e, stackTrace: s);
        }
      },
      onError: (error) {
        log('WebSocket error: $error');
        if (mounted) {
          setState(() {
            connectionStatus = 'Connection error';
            isAiSpeaking = false;
            isRecording = false;
            isConnecting = true;
          });
        }
      },
      onDone: () {
        log('WebSocket closed');
        if (mounted) {
          setState(() {
            connectionStatus = 'Connection closed';
            isAiSpeaking = false;
            isRecording = false;
            isConnecting = true;
          });
        }
        _speakingTimeoutTimer?.cancel();
        _cleanupAudio();
        if (mounted && isAiSpeaking) setState(() => isAiSpeaking = false);
      },
    );
  }

  void _startSpeakingTimeoutCheck() {
    _speakingTimeoutTimer = Timer(const Duration(milliseconds: 800), () {
      if (isAiSpeaking &&
          _lastAudioChunkTime != null &&
          DateTime.now().difference(_lastAudioChunkTime!).inMilliseconds >
              700) {
        log('No audio chunks received for 0.8 seconds, assuming AI is done speaking (Timeout)');

        if (_pcmBuffer.isNotEmpty) {
          log('Playing buffered audio after timeout (${_pcmBuffer.length} bytes)');
          _playAudioWithSoloud(List<int>.from(_pcmBuffer));
          _pcmBuffer.clear();
        } else {
          if (mounted && isAiSpeaking) {
            setState(() {
              isAiSpeaking = false;
            });
          }
        }
      }
    });
  }

  Future<void> _playAudioWithSoloud(List<int> pcmData) async {
    if (!_isAudioAvailable || !_audioInitSucceeded) {
      log('Audio not available or not properly initialized - skipping audio playback');
      if (mounted) setState(() => isAiSpeaking = false);
      return;
    }

    if (pcmData.isEmpty) {
      log('Warning: Attempted to play empty audio buffer.');
      if (mounted) setState(() => isAiSpeaking = false);
      return;
    }

    log('Starting audio playback with ${pcmData.length} bytes of PCM data');

    if (mounted && !isAiSpeaking) {
      setState(() {
        isAiSpeaking = true;
      });
    }

    try {
      // Stop previous sound
      await _safeAudioOperation(() async {
        if (_currentSoundHandle != null) {
          await SoLoud.instance.stop(_currentSoundHandle!);
          _currentSoundHandle = null;
        }
        if (currentSound != null) {
          await SoLoud.instance.disposeSource(currentSound!);
          currentSound = null;
        }
      });

      // Create WAV data with proper format for Gemini's 24kHz PCM
      const int sampleRate = 24000;
      const int numChannels = 1;
      const int bitsPerSample = 16;

      final headerBytes = _generateWavHeader(
        pcmData.length,
        sampleRate,
        numChannels,
        bitsPerSample,
      );

      final Uint8List combinedWavData = Uint8List(
        headerBytes.length + pcmData.length,
      );
      combinedWavData.setRange(0, headerBytes.length, headerBytes);
      combinedWavData.setRange(
        headerBytes.length,
        combinedWavData.length,
        pcmData,
      );

      // Load and play audio
      log('Loading WAV data into SoLoud (${combinedWavData.length} bytes, ${pcmData.length} PCM bytes)...');

      // Check SoLoud initialization state before loading
      final isInitialized = SoLoud.instance.isInitialized;
      log('SoLoud initialized state before loading: $isInitialized');

      // Use memory mode for better performance
      currentSound = await SoLoud.instance.loadMem(
        'gemini_response_${DateTime.now().millisecondsSinceEpoch}.wav',
        combinedWavData,
        mode: kIsWeb ? LoadMode.disk : LoadMode.memory,
      );

      if (currentSound == null) {
        log('Error: Failed to load audio data from memory.');
        if (mounted) setState(() => isAiSpeaking = false);
        return;
      }

      log('Audio loaded successfully, playing now...');

      _currentSoundHandle = await SoLoud.instance.play(currentSound!);
      log('Playing Gemini response with handle: $_currentSoundHandle');

      // Set volume to ensure audibility
      if (_currentSoundHandle != null) {
        SoLoud.instance.setVolume(_currentSoundHandle!, 1.0);
        log('Volume set to 1.0 for handle $_currentSoundHandle');

        // Check if sound is actually playing
        final isValid =
            SoLoud.instance.getIsValidVoiceHandle(_currentSoundHandle!);
        log('Sound handle valid: $isValid');

        // Check global volume
        final globalVolume = SoLoud.instance.getGlobalVolume();
        log('Global volume: $globalVolume');

        // Check if any voices are active
        final activeVoices = SoLoud.instance.getActiveVoiceCount();
        log('Active voice count: $activeVoices');
      }
    } catch (e, s) {
      log('Error playing audio from memory: $e\n$s', error: e, stackTrace: s);
      if (mounted) {
        setState(() {
          isAiSpeaking = false;
          _currentSoundHandle = null;
        });
      }
    }
  }

  List<int> _generateWavHeader(
    int pcmDataLength,
    int sampleRate,
    int numChannels,
    int bitsPerSample,
  ) {
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    final dataSize = pcmDataLength;
    final chunkSize = 36 + dataSize;

    final header = ByteData(44);

    // RIFF chunk descriptor
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, chunkSize, Endian.little);
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // fmt sub-chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // data sub-chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);

    return header.buffer.asUint8List();
  }

  // Debug method to save audio for testing
  Future<void> _saveAudioForDebug(List<int> pcmData) async {
    if (!kIsWeb) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${directory.path}/debug_audio_$timestamp.wav');

        // Create WAV file
        const int sampleRate = 24000;
        const int numChannels = 1;
        const int bitsPerSample = 16;

        final headerBytes = _generateWavHeader(
          pcmData.length,
          sampleRate,
          numChannels,
          bitsPerSample,
        );

        final Uint8List combinedWavData = Uint8List(
          headerBytes.length + pcmData.length,
        );
        combinedWavData.setRange(0, headerBytes.length, headerBytes);
        combinedWavData.setRange(
          headerBytes.length,
          combinedWavData.length,
          pcmData,
        );

        await file.writeAsBytes(combinedWavData);
        log('Debug audio saved to: ${file.path}');
      } catch (e) {
        log('Error saving debug audio: $e');
      }
    }
  }

  // Test method to verify audio playback works
  Future<void> _testAudioPlayback() async {
    if (!_isAudioAvailable) {
      log('Test audio skipped - audio not available');
      return;
    }

    try {
      log('Testing audio playback with a simple tone...');

      // Generate a simple sine wave tone (440Hz for 0.5 seconds)
      const int sampleRate = 44100;
      const double frequency = 440.0;
      const double duration = 0.5;
      final int numSamples = (sampleRate * duration).toInt();

      final List<int> pcmData = [];
      for (int i = 0; i < numSamples; i++) {
        final double sample =
            math.sin(2 * math.pi * frequency * i / sampleRate);
        final int pcmSample = (sample * 32767).toInt();
        // Add as 16-bit little-endian
        pcmData.add(pcmSample & 0xFF);
        pcmData.add((pcmSample >> 8) & 0xFF);
      }

      // Play the test tone
      await _playAudioWithSoloud(pcmData);
      log('Test tone should be playing now');
    } catch (e) {
      log('Error during audio test: $e');
    }
  }
}
