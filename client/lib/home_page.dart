// NativeFlow Translation App - Modern Home Page
// Professional AI Voice Assistant with Camera Integration

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

// Web-specific imports (removed HTML5 Audio - now using SoLoud for all platforms)
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Import the professional theme and modern components
import 'core/theme/app_theme.dart';
import 'core/services/agentic_ai_service.dart';
import 'core/services/performance_service.dart';
import 'core/services/simple_backend_service.dart';
import 'debug_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // Core services
  WebSocketChannel? channel;
  final record = AudioRecorder();
  late AgenticAIService _agenticService;
  late PerformanceService _performanceService;
  late SimpleBackendService _simpleBackend;

  // Camera components - Web-optimized
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  String? _lastCapturedImagePath;
  final List<ConversationMessage> _conversationHistory = [];
  bool _showCameraPopup = false;

  // State variables
  bool isRecording = false;
  bool isConnecting = true;
  bool isAiSpeaking = false;
  String serverResponse = '';
  String connectionStatus = 'Initializing...';
  bool _audioInitAttempted = false;
  bool _audioInitSucceeded = false;
  bool _isInitializing = false; // Prevent multiple initialization attempts
  bool _disposed = false; // Track disposal state
  late String _instanceId; // Debug instance tracking

  // Add continuous conversation state
  bool _conversationMode = false; // Whether continuous conversation is active
  bool _isPaused = false; // Whether conversation is paused
  bool _waitingForUserSpeech =
      false; // Waiting for user to start speaking after AI finishes

  // Audio buffers and stream
  List<int> audioBuffer = [];
  Stream<Uint8List>? _audioStream;
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  // Timers
  Timer? sendTimer;
  Timer? silenceTimer;
  Timer? _speakingTimeoutTimer;
  DateTime? _lastAudioChunkTime;
  int silentSeconds = 0;

  // Audio state
  AudioSource? currentSound;
  SoundHandle? _currentSoundHandle;
  // TTS fallback state
  FlutterTts? _tts;
  bool _ttsReady = false;

  // Animation controllers
  late AnimationController _logoAnimationController;
  late AnimationController _buttonScaleController;
  late AnimationController _statusAnimationController;

  // Animations
  late Animation<double> _logoFadeAnimation;
  late Animation<Offset> _logoSlideAnimation;
  late Animation<double> _statusFadeAnimation;
  late Animation<Offset> _statusSlideAnimation;

  @override
  void initState() {
    super.initState();

    // Create debug instance
    _instanceId = DebugHelper.createInstance('HomePage');
    DebugHelper.logActiveInstances();

    _initServices();
    _initAnimations();
    _initializeApp();
  }

  void _initServices() {
    _agenticService = AgenticAIService();
    _performanceService = PerformanceService();
    _simpleBackend = SimpleBackendService();
  }

  void _initAnimations() {
    // Initialize animation controllers with performance optimization
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _buttonScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _statusAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

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

    // Start animations
    _logoAnimationController.forward();
    _statusAnimationController.forward();
  }

  Future<void> _initializeApp() async {
    // Prevent multiple initialization attempts
    if (_isInitializing || _disposed) {
      log('Initialization already in progress or disposed');
      return;
    }

    _isInitializing = true;

    if (mounted) {
      setState(() {
        connectionStatus = 'Initializing AI services...';
      });
    }

    try {
      // Initialize performance monitoring
      await _performanceService.initialize();

      // Initialize agentic AI service
      await _agenticService.initialize();

      // Initialize SoLoud
      // Web: defer init until user gesture (mic tap) to satisfy Chrome autoplay policy
      if (!kIsWeb) {
        await _initializeSoLoud();
      } else {
        log('CLIENT INIT: Deferring SoLoud initialization until user taps microphone (web autoplay policy)');
      }

      // Initialize TTS fallback (works well on web/Chrome)
      await _initTts();

      // Initialize WebSocket connection
      await _initConnection();

      // Test audio playback after initialization (only on non-web platforms)
      if (!kIsWeb && _audioInitSucceeded) {
        _testAudioPlayback();
      }
    } catch (e) {
      log('Initialization error: $e');
      if (mounted) {
        setState(() {
          connectionStatus = 'Initialization failed: $e';
          isConnecting = false;
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _initTts() async {
    try {
      _tts = FlutterTts();
      // Web/iOS need this to complete before speaking
      await _tts!.awaitSpeakCompletion(true);
      // Sensible defaults for clarity
      await _tts!.setLanguage('en-US');
      await _tts!.setSpeechRate(0.45);
      await _tts!.setVolume(1.0);
      await _tts!.setPitch(1.0);
      _ttsReady = true;
      log('TTS initialized successfully');
    } catch (e) {
      _ttsReady = false;
      log('TTS initialization failed: $e');
    }
  }

  Future<void> _speakWithTts(String text) async {
    // Use only when no server audio is present or audio engine unavailable
    if (_disposed || !_ttsReady || _tts == null) {
      log('TTS not ready or disposed; skipping speech');
      return;
    }

    try {
      setState(() {
        isAiSpeaking = true;
      });

      // Stop any current utterance
      try {
        await _tts!.stop();
      } catch (_) {}

      await _tts!.speak(text);

      // Safety timeout
      _speakingTimeoutTimer?.cancel();
      _speakingTimeoutTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) {
          setState(() => isAiSpeaking = false);
        }
      });

      // When completion is awaited, we can unset flag after speak returns
      if (mounted) {
        setState(() {
          isAiSpeaking = false;
        });
      }

      // Continuous conversation: Auto-restart listening
      _handleAudioCompletionForContinuousConversation();
    } catch (e) {
      log('TTS speak failed: $e');
      if (mounted) setState(() => isAiSpeaking = false);
    }
  }

  // Web-optimized camera initialization
  Future<void> _getCameraList() async {
    try {
      setState(() {
        connectionStatus = 'Detecting cameras...';
      });

      if (kIsWeb) {
        // Web-specific camera handling
        try {
          _cameras = await availableCameras();
        } catch (e) {
          log('Web camera access error: $e');
          // Show user-friendly message for web camera issues
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Camera access requires HTTPS or localhost. Please ensure proper permissions.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      } else {
        _cameras = await availableCameras();
      }

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

      // Web-optimized camera settings
      _cameraController = CameraController(
        _cameras!.first,
        kIsWeb
            ? ResolutionPreset.medium
            : ResolutionPreset.high, // Lower resolution for web
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
      rethrow;
    }
  }

  Future<void> _initializeSoLoud() async {
    if (_audioInitAttempted) {
      log('Audio initialization already attempted');
      return;
    }

    _audioInitAttempted = true;

    setState(() {
      connectionStatus = 'Initializing audio engine...';
    });

    try {
      log('Attempting to initialize SoLoud for ${kIsWeb ? "web" : "native"} platform...');

      // Initialize SoLoud - works on all platforms including web via WebAssembly
      await SoLoud.instance.init();

      // Verify initialization
      _audioInitSucceeded = SoLoud.instance.isInitialized;

      if (_audioInitSucceeded) {
        log('SoLoud initialized successfully for ${kIsWeb ? "web" : "native"} platform');

        // Set optimal volume for voice responses
        SoLoud.instance.setGlobalVolume(1.0);
        log('Global volume set to 1.0');

        // Verify SoLoud capabilities
        final volume = SoLoud.instance.getGlobalVolume();
        log('SoLoud status check - Volume: $volume, Initialized: $_audioInitSucceeded');

        if (mounted) {
          setState(() {
            connectionStatus = kIsWeb
                ? 'Connected (SoLoud Web Ready)'
                : 'Connected (SoLoud Ready)';
          });
        }
      } else {
        log('❌ SoLoud initialization failed - audio will be unavailable');
        if (mounted) {
          setState(() {
            connectionStatus = 'Connected (Audio unavailable)';
          });
        }
      }
    } catch (e) {
      log('❌ SoLoud initialization error: $e');
      _audioInitSucceeded = false;
      if (mounted) {
        setState(() {
          connectionStatus = 'Connected (SoLoud initialization failed)';
        });
      }
    }
  }

  bool get _isAudioAvailable {
    try {
      // Use SoLoud for both web and native platforms
      final soloudInit = SoLoud.instance.isInitialized;
      final available = _audioInitSucceeded && soloudInit;
      log('CLIENT AUDIO CHECK: ${kIsWeb ? "Web" : "Native"} SoLoud available: $available (init succeeded: $_audioInitSucceeded, SoLoud init: $soloudInit)');
      return available;
    } catch (e) {
      log('CLIENT AUDIO CHECK: Error checking SoLoud availability: $e');
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
    // Close existing connection if any
    await _closeExistingConnection();

    if (mounted) {
      setState(() {
        connectionStatus = 'Connecting to server...';
      });
    }

    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    while (retryCount < maxRetries && !_disposed) {
      try {
        final wsUrl = _getWebSocketUrl();
        log('Connecting to WebSocket URL: $wsUrl (attempt ${retryCount + 1}/$maxRetries)');

        // Create new connection without protocol headers to avoid handshake issues
        channel = WebSocketChannel.connect(
          Uri.parse(wsUrl),
          // Removed protocols parameter to fix WebSocket handshake issues
        );

        // Test connection with a simple ping
        await _testWebSocketConnection();

        // Set up listeners AFTER connection is established
        _listenForAudioStream();
        _listenToSoLoudEvents();

        if (mounted) {
          setState(() {
            isConnecting = false;
            connectionStatus = 'Connected';
            serverResponse = '';
          });
        }

        log('WebSocket connected successfully');
        return; // Exit retry loop on success
      } catch (e) {
        retryCount++;
        log('Connection attempt $retryCount failed: $e');

        // Close failed connection
        await _closeExistingConnection();

        if (retryCount < maxRetries && !_disposed) {
          if (mounted) {
            setState(() {
              connectionStatus =
                  'Connection failed, retrying... ($retryCount/$maxRetries)';
            });
          }
          await Future.delayed(retryDelay);
        } else {
          log('All connection attempts failed - switching to fallback mode');
          if (mounted) {
            setState(() {
              isConnecting = false;
              connectionStatus =
                  'Connected in offline mode - Basic functionality available';
            });
          }

          // Test the simple backend as fallback
          try {
            final backendWorking = await _simpleBackend.testConnection();
            if (backendWorking && mounted) {
              setState(() {
                connectionStatus = 'Connected (Offline mode) - Ready to help!';
              });
            }
          } catch (e) {
            log('Fallback backend also failed: $e');
          }
        }
      }
    }
  }

  Future<void> _closeExistingConnection() async {
    if (channel != null) {
      try {
        log('Closing existing WebSocket connection');
        await channel!.sink.close();
      } catch (e) {
        log('Error closing existing connection: $e');
      } finally {
        channel = null;
      }
    }
  }

  Future<void> _testWebSocketConnection() async {
    if (channel == null) {
      throw Exception('WebSocket channel is null');
    }

    try {
      // Wait a short time for connection to establish
      await Future.delayed(const Duration(milliseconds: 500));

      // Test if we can send a simple message
      channel!.sink.add(jsonEncode({
        'type': 'ping',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));

      log('WebSocket connection test successful');

      // Additional wait for server response
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      log('WebSocket connection test failed: $e');
      rethrow;
    }
  }

  String _getWebSocketUrl() {
    String url;
    if (kIsWeb) {
      url = 'ws://localhost:9083';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      url = 'ws://10.0.2.2:9083';
    } else {
      url = 'ws://localhost:9083';
    }
    log('WebSocket URL determined: $url for platform: ${kIsWeb ? 'Web' : defaultTargetPlatform.toString()}');
    return url;
  }

  @override
  void dispose() {
    // Mark as disposed to prevent further operations
    _disposed = true;

    // Dispose debug instance
    DebugHelper.disposeInstance(_instanceId);
    DebugHelper.logActiveInstances();

    // Dispose animation controllers
    _logoAnimationController.dispose();
    _buttonScaleController.dispose();
    _statusAnimationController.dispose();

    // Cancel timers
    silenceTimer?.cancel();
    sendTimer?.cancel();
    _speakingTimeoutTimer?.cancel();
    _audioStreamSubscription?.cancel();

    // Cleanup camera
    _cameraController?.dispose();

    // Cleanup recording and WebSocket
    if (isRecording) {
      stopStream();
    }

    // Close WebSocket connection
    _closeExistingConnection();

    record.dispose();

    // Cleanup SoLoud resources
    _cleanupAudio();

    log('HomePage disposed');
    super.dispose();
  }

  void _cleanupAudio() {
    if (!_audioInitSucceeded) return;

    // SoLoud cleanup for both web and native platforms
    if (!_isAudioAvailable) return;

    _safeAudioOperation(() async {
      // Stop any currently playing sound first
      if (_currentSoundHandle != null) {
        try {
          SoLoud.instance.stop(_currentSoundHandle!);
          _currentSoundHandle = null;
          log('CLIENT CLEANUP: Stopped SoLoud audio handle');
        } catch (e) {
          log('CLIENT CLEANUP: Error stopping sound handle: $e');
        }
      }

      // Then dispose the source
      if (currentSound != null) {
        try {
          SoLoud.instance.disposeSource(currentSound!);
          currentSound = null;
          log('CLIENT CLEANUP: Disposed SoLoud audio source');
        } catch (e) {
          log('CLIENT CLEANUP: Error disposing source: $e');
        }
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
      backgroundColor: AppTheme.backgroundLight,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Icon(
                Icons.translate,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              Text(
                'NativeFlow',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              Text(
                connectionStatus,
                style: AppTheme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainScreen() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: _buildLogo(),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        actions: [
          // Camera icon button with enhanced styling
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showCameraInterface(),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryBlue.withValues(alpha: 0.05),
              AppTheme.backgroundLight,
              Colors.white,
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Transcription Section with enhanced styling
              _buildTranscriptionSection(),

              // Enhanced Status and Control Section
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 32),

                    // Modern Status Card
                    _buildEnhancedStatusSection(),

                    // Clean centered space for better focus on the floating button
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Simplified visual feedback - just the conversation state
                            _buildConversationVisualFeedback(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildModernVoiceButton(),
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
                color: AppTheme.primaryBlue,
              ),
            ),
            Text(
              'Flow',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptionSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Header with Glassmorphism
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.glassmorphism,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppTheme.shadowMedium,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Conversation',
                        style: AppTheme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Real-time translation & assistance',
                        style: AppTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Connection Status Indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isConnecting
                        ? AppTheme.warning.withValues(alpha: 0.1)
                        : AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isConnecting
                          ? AppTheme.warning.withValues(alpha: 0.3)
                          : AppTheme.success.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isConnecting
                              ? AppTheme.warning
                              : AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isConnecting ? 'Connecting' : 'Online',
                        style: AppTheme.textTheme.labelSmall?.copyWith(
                          color: isConnecting
                              ? AppTheme.warning
                              : AppTheme.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Enhanced Conversation Area
          Container(
            height: 300,
            decoration: AppTheme.modernCard,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.conversationGradient,
                ),
                child: _conversationHistory.isEmpty
                    ? _buildEmptyConversationState()
                    : _buildConversationList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyConversationState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.glassGradient,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.mic_none_rounded,
              size: 48,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Start Your Conversation',
            style: AppTheme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Press the microphone to begin',
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              _buildSuggestionChip('Translate "Hello"', Icons.translate),
              _buildSuggestionChip('Help me learn', Icons.school),
              _buildSuggestionChip('What can you do?', Icons.help_outline),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.borderLight.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTheme.textTheme.labelMedium?.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _conversationHistory.length,
      itemBuilder: (context, index) {
        final message = _conversationHistory[index];
        return _buildModernConversationBubble(message, index);
      },
    );
  }

  Widget _buildModernConversationBubble(
      ConversationMessage message, int index) {
    final isUser = message.sender == MessageSender.user;
    final isLast = index == _conversationHistory.length - 1;

    return Container(
      margin: EdgeInsets.only(
        bottom: isLast ? 0 : 16,
        left: isUser ? 40 : 0,
        right: isUser ? 0 : 40,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: AppTheme.modernGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.shadowSmall,
                  ),
                  child: Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration:
                      isUser ? AppTheme.userBubble : AppTheme.agentBubble,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: AppTheme.textTheme.bodyMedium?.copyWith(
                          color: isUser ? Colors.white : AppTheme.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(message.timestamp),
                        style: AppTheme.textTheme.labelSmall?.copyWith(
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.8)
                              : AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 12),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.shadowSmall,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildModernVoiceButton() {
    return _buildUnifiedVoiceButton();
  }

  // New unified voice button that handles all states sleekly
  Widget _buildUnifiedVoiceButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main conversation button
          GestureDetector(
            onTap: _toggleRecording,
            onLongPress: _toggleConversationMode,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _getButtonSize(),
              height: _getButtonSize(),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _getButtonGradient(),
                boxShadow: _getButtonShadow(),
                border: _getButtonBorder(),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated background pulse
                  if (isRecording || isAiSpeaking || _waitingForUserSpeech)
                    AnimatedBuilder(
                      animation: _buttonScaleController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 +
                              (_buttonScaleController.value *
                                  _getPulseIntensity()),
                          child: Container(
                            width: _getButtonSize() - 20,
                            height: _getButtonSize() - 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getPulseColor().withValues(alpha: 0.3),
                            ),
                          ),
                        );
                      },
                    ),

                  // Main icon
                  Icon(
                    _getButtonIcon(),
                    size: _getIconSize(),
                    color: Colors.white,
                  ),

                  // Conversation mode indicator
                  if (_conversationMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _isPaused ? Colors.orange : Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Status text
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _getStatusText(),
              key: ValueKey(_getStatusText()),
              style: AppTheme.textTheme.bodyMedium?.copyWith(
                color: _getStatusColor(),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 8),

          // Interaction hint
          Text(
            _getInteractionHint(),
            style: AppTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Button appearance helpers
  double _getButtonSize() {
    if (isAiSpeaking) return 100.0;
    if (isRecording) return 95.0;
    if (_waitingForUserSpeech) return 90.0;
    return 85.0;
  }

  double _getIconSize() {
    if (isAiSpeaking) return 45.0;
    if (isRecording) return 40.0;
    return 35.0;
  }

  IconData _getButtonIcon() {
    if (isAiSpeaking) return Icons.volume_up_rounded;
    if (isRecording) return Icons.mic;
    if (_waitingForUserSpeech) return Icons.mic_none_rounded;
    if (_isPaused) return Icons.play_arrow_rounded;
    if (_conversationMode) return Icons.pause_rounded;
    return Icons.mic_rounded;
  }

  Gradient _getButtonGradient() {
    if (isAiSpeaking) {
      return LinearGradient(
        colors: [AppTheme.primaryPurple, AppTheme.accentPurple],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (isRecording) {
      return LinearGradient(
        colors: [AppTheme.primaryBlue, Colors.blue.shade600],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (_waitingForUserSpeech) {
      return LinearGradient(
        colors: [Colors.green.shade400, Colors.green.shade600],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (_isPaused) {
      return LinearGradient(
        colors: [Colors.orange.shade400, Colors.orange.shade600],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return AppTheme.primaryGradient;
  }

  List<BoxShadow> _getButtonShadow() {
    final shadowColor = _getButtonGradient().colors.first;
    return [
      BoxShadow(
        color: shadowColor.withValues(alpha: 0.4),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];
  }

  Border? _getButtonBorder() {
    if (_waitingForUserSpeech) {
      return Border.all(color: Colors.green.shade300, width: 3);
    }
    return null;
  }

  Color _getPulseColor() {
    if (isAiSpeaking) return AppTheme.primaryPurple;
    if (isRecording) return AppTheme.primaryBlue;
    if (_waitingForUserSpeech) return Colors.green;
    return AppTheme.primaryBlue;
  }

  double _getPulseIntensity() {
    if (isAiSpeaking) return 0.15;
    if (isRecording) return 0.2;
    if (_waitingForUserSpeech) return 0.1;
    return 0.1;
  }

  String _getStatusText() {
    if (isConnecting) return 'Connecting...';
    if (isAiSpeaking) return 'AI Speaking';
    if (isRecording) return 'Listening...';
    if (_waitingForUserSpeech) return 'Ready to Listen';
    if (_isPaused) return 'Conversation Paused';
    if (_conversationMode) return 'Continuous Mode';
    return 'Ready';
  }

  Color _getStatusColor() {
    if (isConnecting) return AppTheme.warning;
    if (isAiSpeaking) return AppTheme.primaryPurple;
    if (isRecording) return AppTheme.primaryBlue;
    if (_waitingForUserSpeech) return Colors.green;
    if (_isPaused) return Colors.orange;
    if (_conversationMode) return AppTheme.success;
    return AppTheme.textPrimary;
  }

  String _getInteractionHint() {
    if (_conversationMode) {
      return _isPaused
          ? 'Tap to resume • Hold to exit continuous mode'
          : 'Tap to pause • Hold to exit continuous mode';
    }
    return 'Tap to record • Hold for continuous mode';
  }

  // Simplified visual feedback for conversation state
  Widget _buildConversationVisualFeedback() {
    if (_conversationMode) {
      return Column(
        children: [
          Icon(
            Icons.forum_rounded,
            size: 60,
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Continuous Conversation',
            style: AppTheme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getConversationModeDescription(),
            style: AppTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // Single interaction mode
    return Column(
      children: [
        Icon(
          Icons.record_voice_over_rounded,
          size: 60,
          color: AppTheme.textSecondary.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 12),
        Text(
          'Voice Assistant',
          style: AppTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hold the microphone button for continuous conversation mode',
          style: AppTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getConversationModeDescription() {
    if (_isPaused) return 'Conversation is paused';
    if (isAiSpeaking) return 'AI is responding to your message';
    if (isRecording) return 'Listening to your voice...';
    if (_waitingForUserSpeech) return 'Ready for your next message';
    return 'Active conversation mode - speak naturally';
  }

  Widget _buildEnhancedStatusSection() {
    String message;
    Color statusColor;
    IconData statusIcon;

    if (isConnecting) {
      message = connectionStatus;
      statusColor = AppTheme.warning;
      statusIcon = Icons.sync;
    } else if (serverResponse.isNotEmpty) {
      message = serverResponse;
      statusColor = AppTheme.success;
      statusIcon = Icons.check_circle;
    } else if (isAiSpeaking) {
      message = 'AI is speaking...';
      statusColor = AppTheme.primaryPurple;
      statusIcon = Icons.hearing;
    } else if (isRecording) {
      message = 'Listening to your voice...';
      statusColor = AppTheme.primaryBlue;
      statusIcon = Icons.mic;
    } else {
      message = kIsWeb && !_audioInitAttempted
          ? 'Press microphone to start (Audio will initialize on first use)'
          : !_isAudioAvailable
              ? 'Ready for text-only conversation'
              : 'Ready to help you translate anything';
      statusColor = AppTheme.textSecondary;
      statusIcon = Icons.chat_bubble_outline;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: FadeTransition(
        opacity: _statusFadeAnimation,
        child: SlideTransition(
          position: _statusSlideAnimation,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.modernCard,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: AppTheme.textTheme.labelMedium?.copyWith(
                          color: AppTheme.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: AppTheme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isAiSpeaking || isRecording
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: statusColor == AppTheme.textSecondary
                              ? AppTheme.textPrimary
                              : statusColor,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isRecording) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'REC',
                          style: AppTheme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernRecordingIndicator() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.2),
                AppTheme.primaryBlue.withValues(alpha: 0.05),
                Colors.transparent,
              ],
              stops: [0.4, 0.7, 1.0],
            ),
          ),
          child: AnimatedBuilder(
            animation: _buttonScaleController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_buttonScaleController.value * 0.2),
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Listening...',
          style: AppTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Auto-stop after 3 seconds of silence',
          style: AppTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildModernSpeakingIndicator() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppTheme.primaryPurple.withValues(alpha: 0.2),
                AppTheme.primaryPurple.withValues(alpha: 0.05),
                Colors.transparent,
              ],
              stops: [0.4, 0.7, 1.0],
            ),
          ),
          child: AnimatedBuilder(
            animation: _buttonScaleController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_buttonScaleController.value * 0.15),
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.modernGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'AI Speaking',
          style: AppTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.primaryPurple,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Playing audio response',
          style: AppTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildIdleAnimation() {
    return AnimatedBuilder(
      animation: _logoAnimationController,
      builder: (context, child) {
        return Opacity(
          opacity: 0.6,
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.glassGradient,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: AppTheme.shadowMedium,
                ),
                child: Icon(
                  Icons.translate_rounded,
                  color: AppTheme.primaryBlue,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tap to start conversation',
                style: AppTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Voice recording methods with continuous conversation support
  Future<void> _toggleRecording() async {
    if (_conversationMode) {
      // In conversation mode, button toggles pause/resume
      _toggleConversationPause();
    } else {
      // Traditional mode: single recording
      if (isRecording) {
        await stopStream();
      } else {
        await startStream();
      }
    }
  }

  // Toggle between continuous conversation and single interaction
  void _toggleConversationMode() {
    setState(() {
      _conversationMode = !_conversationMode;
      _isPaused = false;
      _waitingForUserSpeech = false;
    });

    if (_conversationMode) {
      log('🔄 CONTINUOUS: Conversation mode activated');
      if (!isRecording && !isAiSpeaking) {
        startStream(); // Start listening immediately
      }
    } else {
      log('🔄 CONTINUOUS: Conversation mode deactivated');
      if (isRecording) {
        stopStream(); // Stop current recording
      }
    }
  }

  // Pause/resume continuous conversation
  void _toggleConversationPause() {
    setState(() {
      _isPaused = !_isPaused;
      _waitingForUserSpeech = false;
    });

    if (_isPaused) {
      log('⏸️ CONTINUOUS: Conversation paused');
      if (isRecording) {
        stopStream(); // Stop recording when paused
      }
    } else {
      log('▶️ CONTINUOUS: Conversation resumed');
      if (!isRecording && !isAiSpeaking) {
        startStream(); // Resume recording
      }
    }
  }

  Future<bool> _requestMicrophonePermission() async {
    try {
      log('Checking microphone permission...');

      // First check if we already have permission
      final hasPermission = await record.hasPermission();
      if (hasPermission) {
        log('Microphone permission already granted');

        // Initialize audio now that we have confirmed permission
        await _initializeAudioAfterPermission();
        return true;
      }

      // If we don't have permission, show a user-friendly message
      // The actual permission request will happen when we try to start recording
      log('Microphone permission not yet granted - will request when recording starts');

      if (mounted) {
        setState(() {
          connectionStatus =
              'Click the microphone to grant permission and start recording';
        });
      }

      return false;
    } catch (e) {
      log('Error checking microphone permission: $e');
      return false;
    }
  }

  Future<void> _initializeAudioAfterPermission() async {
    // Initialize audio only after user grants permission (user gesture)
    log('CLIENT INIT: _initializeAudioAfterPermission called');
    log('CLIENT INIT: Audio init attempted: $_audioInitAttempted');

    if (!_audioInitAttempted) {
      log('CLIENT INIT: First time audio initialization');
      _audioInitAttempted = true;

      // Use SoLoud for both web and native platforms
      log('CLIENT INIT: Initializing SoLoud for ${kIsWeb ? "web" : "native"} platform...');

      try {
        await SoLoud.instance.init();
        _audioInitSucceeded = SoLoud.instance.isInitialized;

        if (_audioInitSucceeded) {
          SoLoud.instance.setGlobalVolume(1.0);
          log('CLIENT INIT: SoLoud initialized successfully for ${kIsWeb ? "web" : "native"} platform');

          // Test audio connectivity
          await _testAudioConnectivity();

          if (mounted) {
            setState(() {
              connectionStatus = kIsWeb
                  ? 'Connected (Web SoLoud Ready)'
                  : 'Connected (Native SoLoud Ready)';
            });
          }
        } else {
          log('CLIENT INIT: SoLoud initialization failed - audio will not work');
          if (mounted) {
            setState(() {
              connectionStatus = 'Connected (Audio initialization failed)';
            });
          }
        }
      } catch (e) {
        log('CLIENT INIT: SoLoud initialization failed: $e');
        _audioInitSucceeded = false;
        if (mounted) {
          setState(() {
            connectionStatus = 'Connected (Audio initialization failed)';
          });
        }
      }
    } else {
      log('CLIENT INIT: Audio already initialized');
    }
  }

  Future<void> startStream() async {
    log('🎤 CLIENT RECORDING: startStream() called');
    try {
      // Check if we already have permission
      final hasPermission = await _requestMicrophonePermission();
      log('🎤 CLIENT RECORDING: Has permission: $hasPermission');

      if (hasPermission) {
        // Permission already granted, proceed with recording
        log('🎤 CLIENT RECORDING: Permission already granted, starting recording...');
        await _startRecordingWithPermission();
      } else {
        // Permission not granted, try to start recording which will trigger permission dialog
        log('🎤 CLIENT RECORDING: Attempting to start recording to trigger permission dialog...');

        try {
          // This will trigger the browser's permission dialog
          _audioStream = await record.startStream(RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000, // Gemini API requirement
            numChannels: 1, // Mono audio for Gemini
            bitRate: 128000, // 128 kbps for good quality
            autoGain: true, // Automatic gain control
            echoCancel: true, // Echo cancellation
            noiseSuppress: true, // Noise suppression
          ));

          // If we get here, permission was granted!
          log('✅ CLIENT RECORDING: Permission granted by user - initializing audio...');

          // Initialize audio now that user clicked "Allow"
          await _initializeAudioAfterPermission();

          // Set up the audio stream listener with detailed logging
          _audioStreamSubscription = _audioStream!.listen(
            (audioChunk) {
              _lastAudioChunkTime = DateTime.now();
              audioBuffer.addAll(audioChunk);

              // Log audio data details for debugging
              if (audioChunk.isNotEmpty) {
                final maxAmplitude = audioChunk
                    .map((e) => e.abs())
                    .reduce((a, b) => a > b ? a : b);
                final avgAmplitude =
                    audioChunk.map((e) => e.abs()).reduce((a, b) => a + b) /
                        audioChunk.length;
                log('🎤 CLIENT: Audio chunk received - ${audioChunk.length} bytes, Max: $maxAmplitude, Avg: ${avgAmplitude.toStringAsFixed(1)}');

                if (maxAmplitude < 100) {
                  log('⚠️ CLIENT: Low audio levels detected - check microphone');
                }
              }

              // Send audio data to server
              if (!_disposed && channel != null) {
                // 1. Base64 encode the audio chunk
                final audioBase64 = base64Encode(audioChunk);

                // 2. Create the message in the format the server expects
                final message = {
                  "realtime_input": {
                    "media_chunks": [
                      {
                        "mime_type": "audio/pcm",
                        "data": audioBase64,
                      }
                    ]
                  }
                };

                // 3. Send the correctly formatted JSON message
                channel!.sink.add(jsonEncode(message));
              }
            },
            onError: (error) {
              log('❌ CLIENT: Audio stream error: $error');
            },
          );

          setState(() {
            isRecording = true;
            serverResponse = '';
            _waitingForUserSpeech =
                false; // Reset waiting state when recording starts
          });

          // Auto-stop after silence
          _startSilenceDetection();

          log('Started recording with stream after permission grant');
        } catch (permissionError) {
          log('Permission denied by user: $permissionError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Microphone permission is required for voice recording'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }
    } catch (e) {
      log('Failed to start recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _startRecordingWithPermission() async {
    try {
      // Use startStream for real-time audio streaming (record v5.1.2+)
      _audioStream = await record.startStream(RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000, // Gemini API requirement
        numChannels: 1, // Mono audio for Gemini
        bitRate: 128000, // 128 kbps for good quality
        autoGain: true, // Automatic gain control
        echoCancel: true, // Echo cancellation
        noiseSuppress: true, // Noise suppression
      ));

      // Listen to the audio stream with detailed logging
      _audioStreamSubscription = _audioStream!.listen(
        (audioChunk) {
          _lastAudioChunkTime = DateTime.now();
          audioBuffer.addAll(audioChunk);

          // Log audio data details for debugging
          if (audioChunk.isNotEmpty) {
            final maxAmplitude =
                audioChunk.map((e) => e.abs()).reduce((a, b) => a > b ? a : b);
            final avgAmplitude =
                audioChunk.map((e) => e.abs()).reduce((a, b) => a + b) /
                    audioChunk.length;
            log('🎤 CLIENT: Audio chunk received - ${audioChunk.length} bytes, Max: $maxAmplitude, Avg: ${avgAmplitude.toStringAsFixed(1)}');

            if (maxAmplitude < 100) {
              log('⚠️ CLIENT: Low audio levels detected - check microphone');
            }
          }

          // Send audio data to server
          if (!_disposed && channel != null) {
            // 1. Base64 encode the audio chunk
            final audioBase64 = base64Encode(audioChunk);

            // 2. Create the message in the format the server expects
            final message = {
              "realtime_input": {
                "media_chunks": [
                  {
                    "mime_type": "audio/pcm",
                    "data": audioBase64,
                  }
                ]
              }
            };

            // 3. Send the correctly formatted JSON message
            channel!.sink.add(jsonEncode(message));
          }
        },
        onError: (error) {
          log('❌ CLIENT: Audio stream error: $error');
        },
      );

      setState(() {
        isRecording = true;
        serverResponse = '';
        _waitingForUserSpeech =
            false; // Reset waiting state when recording starts
      });

      // Auto-stop after silence
      _startSilenceDetection();

      log('✅ CLIENT: Started recording with existing permission');
    } catch (e) {
      log('❌ CLIENT: Failed to start recording with permission: $e');
      rethrow;
    }
  }

  Future<void> stopStream() async {
    try {
      sendTimer?.cancel();
      silenceTimer?.cancel();
      _audioStreamSubscription?.cancel();

      if (isRecording) {
        await record.stop();
        log('Stopped recording');
      }

      setState(() {
        isRecording = false;
        silentSeconds = 0;
      });

      _sendEndOfStreamSignal();
    } catch (e) {
      log('Failed to stop recording: $e');
    }
  }

  void _startSilenceDetection() {
    silenceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      if (_lastAudioChunkTime == null ||
          now.difference(_lastAudioChunkTime!).inSeconds >= 1) {
        silentSeconds++;
        log('🔇 CLIENT: Silent for $silentSeconds seconds');

        if (silentSeconds >= 3) {
          log('⏹️ CLIENT: Auto-stopping due to silence');
          stopStream();
        }
      } else {
        silentSeconds = 0;
      }
    });

    // Add a maximum recording timeout as safety net
    Timer(const Duration(seconds: 10), () {
      if (isRecording) {
        log('⏰ CLIENT: Maximum recording time reached, force stopping');
        stopStream();
      }
    });
  }

  void _sendEndOfStreamSignal() {
    if (_disposed) {
      log('Cannot send end of stream: disposed');
      return;
    }

    if (channel != null) {
      try {
        channel!.sink.add(jsonEncode({
          'type': 'end_of_stream',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }));
        log('End of stream signal sent');
        return;
      } catch (e) {
        log('Error sending end of stream signal: $e');
      }
    }

    // Fallback: Process with simple backend if WebSocket unavailable
    _processFallbackTranscription();
  }

  Future<void> _processFallbackTranscription() async {
    if (audioBuffer.isEmpty) {
      log('No audio data to process');
      return;
    }

    try {
      // Simulate transcription (in real app, you'd process the audio)
      final mockTranscription = 'Hello, I would like to translate this text';

      // Add user message
      _addConversationMessage(mockTranscription, MessageSender.user);

      setState(() {
        serverResponse = 'Processing your request...';
      });

      // Process with simple backend
      final response =
          await _simpleBackend.processTranscription(mockTranscription);

      // Add AI response
      _addConversationMessage(response['text'], MessageSender.agent);

      setState(() {
        serverResponse = response['text'];
      });

      // Speak via TTS fallback if no server audio is available
      if (!_isAudioAvailable || !_audioInitSucceeded) {
        await _speakWithTts(response['text'] ?? '');
      }

      log('Fallback processing completed');
    } catch (e) {
      log('Error in fallback processing: $e');
      setState(() {
        serverResponse = 'Error processing your request. Please try again.';
      });
    }
  }

  void _listenForAudioStream() {
    // Use the existing channel connection - don't create a new one
    if (channel == null || _disposed) {
      log('Cannot listen to audio stream: channel is null or disposed');
      return;
    }

    log('Setting up WebSocket audio stream listener...');

    channel!.stream.listen(
      (data) async {
        if (_disposed) return; // Don't process messages if disposed

        try {
          log('Raw WebSocket data received (${data.toString().length} chars): ${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}...');
          final Map<String, dynamic> message = jsonDecode(data);
          log('Parsed message keys: ${message.keys.join(', ')}');
          await _handleServerMessage(message);
        } catch (e) {
          log('Error parsing server message: $e');
          log('Raw data that failed to parse: $data');
        }
      },
      onError: (error) {
        if (_disposed) return;

        log('WebSocket error: $error');
        if (mounted) {
          setState(() {
            connectionStatus = 'Connection lost: $error';
            isConnecting = false;
          });
        }
      },
      onDone: () {
        if (_disposed) return;

        log('WebSocket connection closed');
        if (mounted) {
          setState(() {
            connectionStatus = 'Connection closed';
            isConnecting = false;
          });
        }
      },
    );
  }

  Future<void> _handleServerMessage(Map<String, dynamic> message) async {
    log('CLIENT: Received server message: ${message.keys.join(', ')}');
    log('CLIENT: Full message preview: ${message.toString().substring(0, message.toString().length > 300 ? 300 : message.toString().length)}...');

    // Handle different message formats from Gemini server
    if (message.containsKey('audio')) {
      // Audio response from Gemini
      final audioData = message['audio'];
      final audioFormat =
          message['format'] ?? 'mp3'; // Default to MP3 if not specified
      final sampleRate = message['sampleRate'] ?? 24000;

      log('CLIENT: Audio field found in message!');
      log('CLIENT: Audio format: $audioFormat');
      log('CLIENT: Sample rate: $sampleRate');
      log('CLIENT: Audio data type: ${audioData.runtimeType}');
      log('CLIENT: Audio data present: ${audioData != null}');
      log('CLIENT: Audio system available: $_isAudioAvailable');
      log('CLIENT: Platform: ${kIsWeb ? "Web" : "Native"}');
      log('CLIENT: Audio init succeeded: $_audioInitSucceeded');

      if (audioData != null) {
        if (audioData is String) {
          log('CLIENT: Audio data length: ${audioData.length} characters');
          log('CLIENT: Audio data preview: ${audioData.substring(0, audioData.length > 50 ? 50 : audioData.length)}');

          // Check if it looks like valid base64
          try {
            final testDecode = base64Decode(audioData.substring(
                0, audioData.length > 100 ? 100 : audioData.length));
            log('CLIENT: Base64 validation successful, first decoded bytes: ${testDecode.take(10).toList()}');
          } catch (e) {
            log('CLIENT: Base64 validation failed: $e');
          }
        } else {
          log('CLIENT: Audio data is not a string: ${audioData.runtimeType}');
        }

        log('CLIENT: Starting audio playback attempt...');
        try {
          await _playAudioResponse(audioData,
              format: audioFormat, sampleRate: sampleRate);
          log('CLIENT: Audio playback method completed');
        } catch (e) {
          log('CLIENT: Audio playback method failed: $e');
        }
      } else {
        log('CLIENT: Audio data is null - skipping playback');
      }
    } else if (message.containsKey('text')) {
      // Text response from Gemini
      final content = message['text'] ?? '';
      if (content.isNotEmpty) {
        _addConversationMessage(content, MessageSender.agent);
        setState(() {
          serverResponse = content;
        });
        // If no audio was provided, speak via TTS fallback (especially on web)
        if (!_isAudioAvailable || !_audioInitSucceeded) {
          await _speakWithTts(content);
        }
      }
    } else if (message.containsKey('audio_start')) {
      // Audio playback starting signal
      log('Audio playback starting');
      setState(() {
        isAiSpeaking = true;
      });
    } else if (message.containsKey('turn_complete')) {
      // Turn completion signal
      log('Turn completed');
      setState(() {
        isAiSpeaking = false;
      });
    } else if (message.containsKey('transcription')) {
      // Transcription from server
      final transcriptionData = message['transcription'];
      if (transcriptionData is Map && transcriptionData.containsKey('text')) {
        final content = transcriptionData['text'] ?? '';
        if (content.isNotEmpty) {
          _addConversationMessage(content, MessageSender.user);
        }
      }
    } else {
      // Legacy message format support
      final type = message['type'];
      switch (type) {
        case 'transcription':
          final content = message['text'] ?? '';
          _addConversationMessage(content, MessageSender.user);
          break;

        case 'translation':
          final content = message['text'] ?? '';
          _addConversationMessage(content, MessageSender.agent);
          setState(() {
            serverResponse = content;
          });
          break;

        case 'audio_response':
          log('🎵 Legacy audio_response message detected!');
          final audioData = message['audio_data'];
          log('🎵 Legacy audio data type: ${audioData.runtimeType}');
          log('🎵 Legacy audio data present: ${audioData != null}');

          if (audioData != null && audioData is String) {
            log('🎵 Legacy audio data length: ${audioData.length} characters');
            log('🎵 Legacy audio data preview: ${audioData.substring(0, audioData.length > 50 ? 50 : audioData.length)}');
          }

          await _playAudioResponse(audioData, format: 'mp3', sampleRate: 24000);
          break;

        case 'error':
          log('Server error: ${message['message']}');
          setState(() {
            serverResponse = 'Error: ${message['message']}';
          });
          break;

        default:
          log('❓ Unknown message type: $type');
          log('❓ Full message keys: ${message.keys.join(', ')}');
          log('❓ Full message content: $message');

          // Check if this unknown message type contains audio data
          if (message.containsKey('audio_data') ||
              message.containsKey('audio')) {
            log('🔍 Unknown message contains audio data - attempting to play anyway');
            final audioData = message['audio_data'] ?? message['audio'];
            if (audioData != null) {
              await _playAudioResponse(audioData,
                  format: 'mp3', sampleRate: 24000);
            }
          }
      }
    }
  }

  void _addConversationMessage(String content, MessageSender sender) {
    setState(() {
      _conversationHistory.add(ConversationMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        type: MessageType.text,
        sender: sender,
        timestamp: DateTime.now(),
        metadata: {},
      ));
    });

    // Update agentic service context
    _agenticService.processMessage(
      message: content,
      type: MessageType.text,
      metadata: {'sender': sender.toString()},
    );
  }

  Future<void> _playAudioResponse(dynamic audioData,
      {String? format, int? sampleRate}) async {
    log('🎵 CLIENT PLAYBACK: Starting _playAudioResponse');
    log('🎵 CLIENT PLAYBACK: Audio available: $_isAudioAvailable');
    log('🎵 CLIENT PLAYBACK: Audio init attempted: $_audioInitAttempted');
    log('🎵 CLIENT PLAYBACK: Audio init succeeded: $_audioInitSucceeded');
    log('🎵 CLIENT PLAYBACK: Platform: ${kIsWeb ? "Web" : "Native"}');

    if (!_isAudioAvailable) {
      log('❌ CLIENT PLAYBACK: Audio playback not available - using fallback');
      // Show visual feedback even without audio
      setState(() {
        isAiSpeaking = true;
      });
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            isAiSpeaking = false;
          });
        }
      });
      return;
    }

    log('✅ CLIENT PLAYBACK: Audio system available, proceeding with playback');
    setState(() {
      isAiSpeaking = true;
    });

    try {
      Uint8List audioBytes;
      log('🎵 CLIENT PLAYBACK: Processing audio data...');

      // Handle different audio data formats
      if (audioData is String) {
        // Base64 encoded audio from Gemini server
        log('🎵 CLIENT PLAYBACK: Processing base64 audio data: ${audioData.length} characters');
        log('🎵 CLIENT PLAYBACK: First 50 chars: ${audioData.substring(0, audioData.length > 50 ? 50 : audioData.length)}');
        try {
          audioBytes = base64Decode(audioData);
          log('✅ CLIENT PLAYBACK: Successfully decoded audio bytes: ${audioBytes.length}');
          log('🎵 CLIENT PLAYBACK: Audio header: ${audioBytes.take(20).toList()}');
        } catch (e) {
          log('❌ CLIENT PLAYBACK: Error decoding base64 audio: $e');
          setState(() {
            isAiSpeaking = false;
          });
          return;
        }
      } else if (audioData is List) {
        // Raw byte array
        audioBytes = Uint8List.fromList(List<int>.from(audioData));
        log('🎵 CLIENT PLAYBACK: Using raw audio bytes: ${audioBytes.length}');
      } else {
        log('❌ CLIENT PLAYBACK: Unknown audio data format: ${audioData.runtimeType}');
        setState(() {
          isAiSpeaking = false;
        });
        return;
      }

      // Validate audio data size
      if (audioBytes.length < 100) {
        log('❌ CLIENT PLAYBACK: Audio data too small: ${audioBytes.length} bytes');
        setState(() {
          isAiSpeaking = false;
        });
        return;
      }

      log('CLIENT PLAYBACK: Audio data size valid: ${audioBytes.length} bytes');

      // Validate audio format - check for MP3 or WAV header
      final isValidFormat =
          _validateAudioFormat(audioBytes, format: format ?? 'mp3');
      log('CLIENT PLAYBACK: Audio format validation ($format): ${isValidFormat ? "VALID" : "INVALID"}');

      if (!isValidFormat) {
        log('CLIENT PLAYBACK: Audio data doesn\'t appear to be valid $format format - trying anyway...');
      }

      // Web-specific SoLoud optimization
      if (kIsWeb) {
        log('🌐 CLIENT PLAYBACK: Applying web-specific SoLoud optimizations...');

        // Check SoLoud status before attempting playback
        try {
          final volume = SoLoud.instance.getGlobalVolume();
          final isInit = SoLoud.instance.isInitialized;
          log('🌐 CLIENT PLAYBACK: SoLoud web status - Init: $isInit, Volume: $volume');

          if (!isInit) {
            log('❌ CLIENT PLAYBACK: SoLoud not initialized on web - reinitializing...');
            await SoLoud.instance.init();
            await Future.delayed(
                const Duration(milliseconds: 100)); // Web needs time
          }
        } catch (e) {
          log('❌ CLIENT PLAYBACK: SoLoud status check failed on web: $e');
        }
      }

      // Use SoLoud for both web and native platforms
      log('🎵 CLIENT PLAYBACK: Using SoLoud for ${kIsWeb ? "web" : "native"} platform...');
      try {
        // Dispose previous sound if exists
        if (currentSound != null) {
          log('🎵 CLIENT PLAYBACK: Disposing previous sound...');
          try {
            await SoLoud.instance.disposeSource(currentSound!);
            currentSound = null;
            log('✅ CLIENT PLAYBACK: Previous sound disposed');
          } catch (disposeError) {
            log('⚠️ CLIENT PLAYBACK: Error disposing previous sound: $disposeError');
            currentSound = null; // Force reset
          }
        }

        log('CLIENT PLAYBACK: Loading ${format ?? 'MP3'} audio data into SoLoud...');

        // Web-specific audio loading with retry mechanism
        if (kIsWeb) {
          int retryCount = 0;
          const maxRetries = 3;

          while (retryCount < maxRetries) {
            try {
              final fileExt = format == 'wav' ? 'wav' : 'mp3';
              currentSound = await SoLoud.instance.loadMem(
                'gemini_response_${DateTime.now().millisecondsSinceEpoch}.$fileExt',
                audioBytes,
              );
              log('CLIENT PLAYBACK: Audio loaded successfully on attempt ${retryCount + 1}');
              break;
            } catch (loadError) {
              retryCount++;
              log('CLIENT PLAYBACK: Load attempt $retryCount failed: $loadError');

              if (retryCount < maxRetries) {
                await Future.delayed(Duration(milliseconds: 100 * retryCount));
              } else {
                rethrow;
              }
            }
          }
        } else {
          // Native loading (original)
          final fileExt = format == 'wav' ? 'wav' : 'mp3';
          currentSound = await SoLoud.instance.loadMem(
            'gemini_response.$fileExt',
            audioBytes,
          );
        }

        log('✅ CLIENT PLAYBACK: Audio loaded successfully: ${audioBytes.length} bytes');

        log('🎵 CLIENT PLAYBACK: Starting audio playback...');

        // Web-specific playback with error handling
        if (kIsWeb) {
          try {
            // Set optimal volume for web
            SoLoud.instance.setGlobalVolume(0.8); // Slightly lower for web
            await Future.delayed(
                const Duration(milliseconds: 50)); // Give web time

            _currentSoundHandle = await SoLoud.instance.play(currentSound!);
            log('✅ CLIENT PLAYBACK: Web audio playing with handle: $_currentSoundHandle');
          } catch (webPlayError) {
            log('❌ CLIENT PLAYBACK: Web playback failed: $webPlayError');

            // Try alternative web approach
            try {
              log('🔄 CLIENT PLAYBACK: Trying alternative web playback...');
              SoLoud.instance.setGlobalVolume(1.0);
              await Future.delayed(const Duration(milliseconds: 100));
              _currentSoundHandle = await SoLoud.instance.play(currentSound!);
              log('✅ CLIENT PLAYBACK: Alternative web playback succeeded');
            } catch (altWebError) {
              log('❌ CLIENT PLAYBACK: Alternative web playback also failed: $altWebError');
              throw webPlayError; // Throw original error
            }
          }
        } else {
          // Native playback (original)
          _currentSoundHandle = await SoLoud.instance.play(currentSound!);
          log('✅ CLIENT PLAYBACK: Native audio playing with handle: $_currentSoundHandle');
        }

        // Verify the audio is actually playing
        if (_currentSoundHandle != null) {
          final isPlaying =
              SoLoud.instance.getIsValidVoiceHandle(_currentSoundHandle!);
          log('🔍 CLIENT PLAYBACK: Audio handle valid: $isPlaying');

          if (!isPlaying) {
            log('⚠️ CLIENT PLAYBACK: Audio handle not valid - playback may have failed');
          }
        }
      } catch (audioError) {
        log('❌ CLIENT PLAYBACK: SoLoud audio loading/playing error: $audioError');
        log('❌ CLIENT PLAYBACK: Error type: ${audioError.runtimeType}');
        log('❌ CLIENT PLAYBACK: Error details: ${audioError.toString()}');

        setState(() {
          isAiSpeaking = false;
        });

        // Show user-friendly error message with web-specific guidance
        if (mounted) {
          final errorMessage = kIsWeb
              ? 'Web audio playback failed. Try refreshing the page or using Chrome/Firefox.'
              : 'Audio playback failed. Please check your device audio settings.';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Set timeout for speaking state (longer timeout for web)
      _speakingTimeoutTimer?.cancel();
      final timeoutDuration = kIsWeb
          ? const Duration(seconds: 20) // Longer timeout for web
          : const Duration(seconds: 15);

      _speakingTimeoutTimer = Timer(timeoutDuration, () {
        if (mounted) {
          setState(() {
            isAiSpeaking = false;
          });
        }
        log('⏰ CLIENT PLAYBACK: Playback timeout reached');
      });

      // Listen for audio completion
      _listenForAudioCompletion();
    } catch (e) {
      log('❌ CLIENT PLAYBACK: General error playing audio response: $e');
      log('❌ CLIENT PLAYBACK: Stack trace: ${StackTrace.current}');
      setState(() {
        isAiSpeaking = false;
      });
    }
  }

  void _listenForAudioCompletion() {
    // Use SoLoud's built-in capabilities to check if audio is still playing
    // Works for both web and native platforms
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_disposed || !mounted) {
        timer.cancel();
        return;
      }

      try {
        // Check if the sound handle is still valid and playing
        if (_currentSoundHandle != null) {
          final isStillPlaying =
              SoLoud.instance.getIsValidVoiceHandle(_currentSoundHandle!);

          if (!isStillPlaying) {
            // Audio completed
            log('Audio playback completed');
            timer.cancel();

            if (mounted) {
              setState(() {
                isAiSpeaking = false;
              });

              // Continuous conversation: Auto-restart recording after AI finishes
              _handleAudioCompletionForContinuousConversation();
            }

            // Cleanup
            if (currentSound != null) {
              SoLoud.instance.disposeSource(currentSound!);
              currentSound = null;
            }
            _currentSoundHandle = null;
          } else {
            // Still playing - log progress
            final volume = SoLoud.instance.getGlobalVolume();
            log('Audio still playing - volume: $volume');
          }
        } else {
          // No sound handle
          timer.cancel();
          if (mounted) {
            setState(() {
              isAiSpeaking = false;
            });

            // Continuous conversation: Auto-restart recording after AI finishes
            _handleAudioCompletionForContinuousConversation();
          }
        }
      } catch (e) {
        // Audio completed or error occurred
        log('Audio completion check error: $e');
        timer.cancel();
        if (mounted) {
          setState(() {
            isAiSpeaking = false;
          });

          // Continuous conversation: Auto-restart recording after AI finishes
          _handleAudioCompletionForContinuousConversation();
        }
      }
    });
  }

  // Handle continuous conversation flow when AI finishes speaking
  void _handleAudioCompletionForContinuousConversation() {
    if (_conversationMode && !_isPaused && !_disposed && mounted) {
      log('🔄 CONTINUOUS: AI finished speaking, preparing to listen again...');

      setState(() {
        _waitingForUserSpeech = true;
      });

      // Small delay before restarting recording to feel natural
      Timer(const Duration(milliseconds: 800), () {
        if (mounted && _conversationMode && !_isPaused && !isRecording) {
          log('🔄 CONTINUOUS: Auto-restarting recording for continuous conversation');
          startStream();
        }
      });
    }
  }

  void _listenToSoLoudEvents() {
    if (!_isAudioAvailable) return;

    // Note: SoLoud v3.1.10 doesn't have a global soundEvents stream
    // Audio completion is handled via the timeout timer and manual tracking
    log('🎧 CLIENT: SoLoud event listening initialized for ${kIsWeb ? "web" : "native"} platform (using timeout-based tracking)');
  }

  void _testAudioPlayback() {
    // Test audio functionality after initialization
    log('🎧 CLIENT: SoLoud ${kIsWeb ? "web" : "native"} audio system ready for playback');

    // Optional: Test with a simple tone to verify audio is working
    if (_isAudioAvailable) {
      log('✅ CLIENT: SoLoud audio system verified - ready for Gemini responses');
    }
  }

  // Validate audio format by checking headers (MP3 or WAV)
  bool _validateAudioFormat(Uint8List audioBytes, {String format = 'mp3'}) {
    if (audioBytes.length < 4) return false;

    if (format == 'wav') {
      // Check for WAV/RIFF header
      final hasRIFF = audioBytes.length >= 4 &&
          audioBytes[0] == 0x52 && // 'R'
          audioBytes[1] == 0x49 && // 'I'
          audioBytes[2] == 0x46 && // 'F'
          audioBytes[3] == 0x46; // 'F'

      log('WAV validation - RIFF header: $hasRIFF');
      return hasRIFF;
    } else {
      // Check for MP3 frame header (11 bits set to 1: 0xFFE or 0xFFF)
      final firstByte = audioBytes[0];
      final secondByte = audioBytes[1];

      // MP3 frame sync: first 11 bits should be 1
      final hasMP3Sync = (firstByte == 0xFF) && ((secondByte & 0xE0) == 0xE0);

      // Check for ID3 tag (often at the beginning of MP3 files)
      final hasID3Tag = audioBytes.length >= 3 &&
          audioBytes[0] == 0x49 && // 'I'
          audioBytes[1] == 0x44 && // 'D'
          audioBytes[2] == 0x33; // '3'

      log('MP3 validation - Sync: $hasMP3Sync, ID3: $hasID3Tag');
      log('First 4 bytes: [${audioBytes[0].toRadixString(16)}, ${audioBytes[1].toRadixString(16)}, ${audioBytes[2].toRadixString(16)}, ${audioBytes[3].toRadixString(16)}]');

      return hasMP3Sync || hasID3Tag;
    }
  }

  // Add a simple audio connectivity test
  Future<void> _testAudioConnectivity() async {
    if (!_isAudioAvailable) {
      log('❌ CLIENT TEST: Audio not available for connectivity test');
      return;
    }

    // SoLoud testing for both web and native platforms
    try {
      log('🔊 CLIENT TEST: Testing SoLoud connectivity on ${kIsWeb ? "web" : "native"} platform...');
      final volume = SoLoud.instance.getGlobalVolume();
      final isInit = SoLoud.instance.isInitialized;
      log('🔊 CLIENT TEST: SoLoud status - Initialized: $isInit, Volume: $volume');

      // Test if we can load a simple sound (we'll generate minimal audio data)
      try {
        // Create a minimal valid MP3 header for testing
        final testBytes = Uint8List.fromList([
          0xFF, 0xFB, 0x90, 0x00, // MP3 header
          ...List.filled(100, 0x00), // Silent audio data
        ]);

        final testSound = await SoLoud.instance.loadMem('test.mp3', testBytes);
        log('🔊 CLIENT TEST: Test audio load successful');

        // Immediately dispose test sound
        await SoLoud.instance.disposeSource(testSound);
        log('✅ CLIENT TEST: Audio connectivity test passed - SoLoud ready for Gemini audio on ${kIsWeb ? "web" : "native"}');
      } catch (testError) {
        log('⚠️ CLIENT TEST: Test audio load failed: $testError (but SoLoud is initialized)');
      }
    } catch (e) {
      log('❌ CLIENT TEST: Audio connectivity test failed: $e');
    }
  }

  // Simple SoLoud Audio Test
  Future<void> _testSimpleAudio() async {
    log('🔴 CLIENT TEST: Testing simple SoLoud audio on ${kIsWeb ? "web" : "native"} platform...');

    if (!_isAudioAvailable) {
      log('🔴 CLIENT TEST: SoLoud not available for testing');
      return;
    }

    try {
      log('🔴 CLIENT TEST: Testing basic SoLoud functionality...');
      final volume = SoLoud.instance.getGlobalVolume();
      final isInit = SoLoud.instance.isInitialized;
      log('✅ CLIENT TEST: SoLoud basic test - Init: $isInit, Volume: $volume');
    } catch (e) {
      log('❌ CLIENT TEST: SoLoud basic test failed: $e');
    }
  }

  // Test Audio Playback with SoLoud
  Future<void> _testLocalAudioPlayback() async {
    log('🧪 CLIENT TEST: Testing SoLoud audio playback on ${kIsWeb ? "web" : "native"} platform...');

    if (!_isAudioAvailable) {
      log('🧪 CLIENT TEST: SoLoud not available for playback test');
      return;
    }

    try {
      log('🧪 CLIENT TEST: Testing SoLoud audio playback functionality...');
      setState(() {
        isAiSpeaking = true;
      });

      // Create a simple test tone
      try {
        // Generate a simple sine wave test tone
        final testBytes = Uint8List.fromList([
          0xFF, 0xFB, 0x90, 0x00, // MP3 header
          ...List.filled(1000, 0x80), // Some audio data
        ]);

        final testSound =
            await SoLoud.instance.loadMem('test_tone.mp3', testBytes);
        log('🧪 CLIENT TEST: Test sound loaded successfully');

        final handle = await SoLoud.instance.play(testSound);
        log('🧪 CLIENT TEST: Test sound playing with handle: $handle');

        // Wait a moment then stop and cleanup
        Timer(const Duration(seconds: 1), () async {
          await SoLoud.instance.stop(handle);
          await SoLoud.instance.disposeSource(testSound);

          if (mounted) {
            setState(() {
              isAiSpeaking = false;
            });
          }
          log('✅ CLIENT TEST: SoLoud playback test completed successfully');
        });
      } catch (playError) {
        log('❌ CLIENT TEST: SoLoud playback test failed: $playError');
        setState(() {
          isAiSpeaking = false;
        });
      }
    } catch (e) {
      log('❌ CLIENT TEST: SoLoud test setup failed: $e');
      setState(() {
        isAiSpeaking = false;
      });
    }
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
            backgroundColor: AppTheme.error,
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
            boxShadow: AppTheme.shadowLarge,
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Camera',
                      style: AppTheme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
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
                    child: _isCameraInitialized && _cameraController != null
                        ? CameraPreview(_cameraController!)
                        : const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ),
                  ),
                ),
              ),

              // Camera Controls
              if (_isCameraInitialized)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FloatingActionButton(
                        onPressed: _captureImage,
                        backgroundColor: AppTheme.primaryBlue,
                        child:
                            const Icon(Icons.camera_alt, color: Colors.white),
                      ),
                      if (_cameras != null && _cameras!.length > 1)
                        FloatingActionButton(
                          onPressed: _switchCamera,
                          backgroundColor: AppTheme.primaryPurple,
                          child: const Icon(Icons.switch_camera,
                              color: Colors.white),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _captureImage() async {
    if (!_isCameraInitialized || _cameraController == null) return;

    try {
      final image = await _cameraController!.takePicture();
      _lastCapturedImagePath = image.path;
      log('Image captured: ${image.path}');

      // Process the image with AI
      _processImageWithAI(_lastCapturedImagePath!);
    } catch (e) {
      log('Error capturing image: $e');
    }
  }

  Future<void> _processImageWithAI(String imagePath) async {
    log('Processing image with AI: $imagePath');

    // Add user message for image capture
    _addConversationMessage(
        '📸 Image captured and sent for analysis', MessageSender.user);

    try {
      // Use the agentic AI service to process the image
      final response = await _agenticService.processMessage(
        message: 'I captured an image at: $imagePath',
        type: MessageType.image,
        metadata: {
          'imagePath': imagePath,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Add AI response
      _addConversationMessage(
        '🤖 Image analysis: ${response.primaryResponse}',
        MessageSender.agent,
      );

      setState(() {
        serverResponse = response.primaryResponse;
      });
    } catch (e) {
      log('Error processing image with AI: $e');
      _addConversationMessage(
        '❌ Image analysis failed: $e',
        MessageSender.agent,
      );
    }
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

      await _cameraController?.dispose();
      _cameraController = CameraController(
        _cameras![nextIndex],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      log('Error switching camera: $e');
    }
  }

  // Test microphone capture functionality
  Future<void> _testMicrophoneCapture() async {
    log('🧪 CLIENT: Testing microphone capture...');

    try {
      // Check if microphone permission is really granted
      final hasPermission = await record.hasPermission();
      log('🎤 CLIENT TEST: Permission check result: $hasPermission');

      if (!hasPermission) {
        log('❌ CLIENT TEST: Microphone permission not granted');
        return;
      }

      // Test if we can start a recording stream
      Stream<Uint8List>? testStream;
      try {
        testStream = await record.startStream(RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 128000,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ));

        log('✅ CLIENT TEST: Microphone stream started successfully');

        // Listen for a few chunks to test audio data
        int chunkCount = 0;
        final testSubscription = testStream.listen(
          (audioChunk) {
            chunkCount++;
            if (audioChunk.isNotEmpty) {
              final maxAmplitude = audioChunk
                  .map((e) => e.abs())
                  .reduce((a, b) => a > b ? a : b);
              final avgAmplitude =
                  audioChunk.map((e) => e.abs()).reduce((a, b) => a + b) /
                      audioChunk.length;
              log('🎤 CLIENT TEST: Chunk $chunkCount - ${audioChunk.length} bytes, Max: $maxAmplitude, Avg: ${avgAmplitude.toStringAsFixed(1)}');

              if (maxAmplitude > 1000) {
                log('✅ CLIENT TEST: Good audio levels detected!');
              } else if (maxAmplitude > 100) {
                log('⚠️ CLIENT TEST: Moderate audio levels - speak louder or check microphone');
              } else {
                log('❌ CLIENT TEST: Very low audio levels - microphone may not be working');
              }
            } else {
              log('❌ CLIENT TEST: Empty audio chunk received');
            }
          },
          onError: (error) {
            log('❌ CLIENT TEST: Audio stream error: $error');
          },
        );

        // Test for 3 seconds then stop
        Timer(const Duration(seconds: 3), () async {
          testSubscription.cancel();
          await record.stop();
          log('🧪 CLIENT TEST: Microphone test completed');
        });
      } catch (streamError) {
        log('❌ CLIENT TEST: Failed to start audio stream: $streamError');
      }
    } catch (e) {
      log('❌ CLIENT TEST: Microphone test failed: $e');
    }
  }

  // Test browser audio compatibility
  Future<void> _testBrowserAudioCompatibility() async {
    if (!kIsWeb) {
      log('🔍 CLIENT TEST: Not on web platform - skipping browser test');
      return;
    }

    log('🌐 CLIENT TEST: Testing browser audio compatibility...');

    try {
      // Check user agent for known problematic browsers
      final userAgent =
          'Web Platform'; // Flutter web doesn't expose navigator.userAgent directly
      log('🌐 CLIENT TEST: Platform: $userAgent');

      // Test SoLoud basic functionality
      final isInit = SoLoud.instance.isInitialized;
      final volume = SoLoud.instance.getGlobalVolume();
      log('🌐 CLIENT TEST: SoLoud status - Init: $isInit, Volume: $volume');

      if (!isInit) {
        log('❌ CLIENT TEST: SoLoud not initialized - attempting init...');
        try {
          await SoLoud.instance.init();
          log('✅ CLIENT TEST: SoLoud initialization successful');
        } catch (initError) {
          log('❌ CLIENT TEST: SoLoud initialization failed: $initError');
          return;
        }
      }

      // Test with minimal audio data
      try {
        log('🌐 CLIENT TEST: Testing minimal MP3 loading...');

        // Create minimal valid MP3 data
        final testMp3Data = Uint8List.fromList([
          // MP3 header
          0xFF, 0xFB, 0x90, 0x00,
          // Minimal MP3 frame data
          ...List.filled(1000, 0x00),
        ]);

        final testSource = await SoLoud.instance.loadMem(
          'test_browser_${DateTime.now().millisecondsSinceEpoch}.mp3',
          testMp3Data,
        );

        log('✅ CLIENT TEST: Test MP3 loaded successfully');

        // Try to play it
        final testHandle = await SoLoud.instance.play(testSource);
        log('✅ CLIENT TEST: Test audio playback started with handle: $testHandle');

        // Check if it's actually playing
        final isPlaying = SoLoud.instance.getIsValidVoiceHandle(testHandle);
        log('🔍 CLIENT TEST: Test audio handle valid: $isPlaying');

        // Cleanup test audio
        Timer(const Duration(milliseconds: 500), () async {
          try {
            SoLoud.instance.stop(testHandle);
            SoLoud.instance.disposeSource(testSource);
            log('✅ CLIENT TEST: Test audio cleaned up');
          } catch (cleanupError) {
            log('⚠️ CLIENT TEST: Cleanup error: $cleanupError');
          }
        });

        if (isPlaying) {
          log('🎉 CLIENT TEST: Browser audio compatibility test PASSED');
        } else {
          log('⚠️ CLIENT TEST: Browser audio compatibility test QUESTIONABLE - handle not valid');
        }
      } catch (testError) {
        log('❌ CLIENT TEST: Browser audio test failed: $testError');
        log('❌ CLIENT TEST: This may indicate browser-specific audio issues');

        // Show user guidance
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Browser audio test failed. Try Chrome or Firefox, or check if audio is blocked.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      log('❌ CLIENT TEST: Browser compatibility test error: $e');
    }
  }
}
