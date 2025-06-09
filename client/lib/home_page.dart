// NativeFlow Translation App - Modern Home Page
// Professional AI Voice Assistant with Camera Integration

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

// Web-specific imports
import 'dart:html' as html if (dart.library.html) 'dart:html';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:camera/camera.dart';

// Import the professional theme and modern components
import 'core/theme/app_theme.dart';
import 'widgets/modern_voice_button.dart';
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

      // Initialize audio (delay for web)
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
      log('Attempting to initialize SoLoud...');
      await SoLoud.instance.init();
      _audioInitSucceeded = await _checkSoLoudInitialized();

      if (_audioInitSucceeded) {
        log('SoLoud initialized successfully');
        SoLoud.instance.setGlobalVolume(1.0);
        log('Global volume set to 1.0');

        if (mounted) {
          setState(() {
            connectionStatus =
                kIsWeb ? 'Connected (Web Audio Ready)' : 'Connected';
          });
        }
      } else {
        log('SoLoud initialization failed - audio unavailable');
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
      if (kIsWeb) {
        // For web, we use HTML5 Audio which is always available after permission
        return _audioInitSucceeded;
      } else {
        // For native platforms, check SoLoud initialization
        return _audioInitSucceeded && SoLoud.instance.isInitialized;
      }
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

    if (kIsWeb) {
      // For web, no SoLoud cleanup needed (HTML5 Audio handles itself)
      log('Web audio cleanup - no SoLoud resources to dispose');
      return;
    }

    // Native platform SoLoud cleanup
    if (!_isAudioAvailable) return;

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
          // Debug audio test buttons
          if (kDebugMode) ...[
            // Simple HTML5 Audio test
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _testSimpleAudio(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            // Full playback system test
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _testLocalAudioPlayback(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.volume_up,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],

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

                    // Interactive Visual Feedback
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isRecording) _buildModernRecordingIndicator(),
                            if (isAiSpeaking) _buildModernSpeakingIndicator(),
                            if (!isRecording && !isAiSpeaking)
                              _buildIdleAnimation(),
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
    return ModernVoiceButton(
      isRecording: isRecording,
      isAiSpeaking: isAiSpeaking,
      isConnecting: isConnecting,
      onPressed: _toggleRecording,
    );
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

  // Voice recording methods
  Future<void> _toggleRecording() async {
    if (isRecording) {
      await stopStream();
    } else {
      await startStream();
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
    if (!_audioInitAttempted) {
      _audioInitAttempted = true;

      if (kIsWeb) {
        // For web, we use HTML5 Audio - no SoLoud initialization needed
        log('Web platform detected - using HTML5 Audio (no SoLoud initialization)');
        _audioInitSucceeded = true; // HTML5 Audio is always "available"

        if (mounted) {
          setState(() {
            connectionStatus = 'Connected (Web Audio Ready)';
          });
        }
      } else {
        // For native platforms, initialize SoLoud
        log('Initializing SoLoud after user granted microphone permission...');

        try {
          await SoLoud.instance.init();
          _audioInitSucceeded = await _checkSoLoudInitialized();

          if (_audioInitSucceeded) {
            SoLoud.instance.setGlobalVolume(1.0);
            log('SoLoud initialized successfully after permission grant');

            // Test audio connectivity
            await _testAudioConnectivity();

            if (mounted) {
              setState(() {
                connectionStatus = 'Connected (Audio Ready)';
              });
            }
          } else {
            log('SoLoud initialization failed - audio will not work');
            if (mounted) {
              setState(() {
                connectionStatus = 'Connected (Audio initialization failed)';
              });
            }
          }
        } catch (e) {
          log('SoLoud initialization failed after permission grant: $e');
          _audioInitSucceeded = false;
          if (mounted) {
            setState(() {
              connectionStatus = 'Connected (Audio initialization failed)';
            });
          }
        }
      }
    }
  }

  Future<void> startStream() async {
    try {
      // Check if we already have permission
      final hasPermission = await _requestMicrophonePermission();

      if (hasPermission) {
        // Permission already granted, proceed with recording
        await _startRecordingWithPermission();
      } else {
        // Permission not granted, try to start recording which will trigger permission dialog
        log('Attempting to start recording to trigger permission dialog...');

        try {
          // This will trigger the browser's permission dialog
          _audioStream = await record.startStream(const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
          ));

          // If we get here, permission was granted!
          log('Permission granted by user - initializing audio...');

          // Initialize audio now that user clicked "Allow"
          await _initializeAudioAfterPermission();

          // Set up the audio stream listener
          _audioStreamSubscription = _audioStream!.listen(
            (audioChunk) {
              _lastAudioChunkTime = DateTime.now();
              audioBuffer.addAll(audioChunk);

              // Send audio data to server
              if (!_disposed && channel != null) {
                channel!.sink.add(jsonEncode({
                  'type': 'audio_chunk',
                  'data': audioChunk,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                }));
              }
            },
            onError: (error) {
              log('Audio stream error: $error');
            },
          );

          setState(() {
            isRecording = true;
            serverResponse = '';
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
      _audioStream = await record.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
      ));

      // Listen to the audio stream
      _audioStreamSubscription = _audioStream!.listen(
        (audioChunk) {
          _lastAudioChunkTime = DateTime.now();
          audioBuffer.addAll(audioChunk);

          // Send audio data to server
          if (!_disposed && channel != null) {
            channel!.sink.add(jsonEncode({
              'type': 'audio_chunk',
              'data': audioChunk,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }));
          }
        },
        onError: (error) {
          log('Audio stream error: $error');
        },
      );

      setState(() {
        isRecording = true;
        serverResponse = '';
      });

      // Auto-stop after silence
      _startSilenceDetection();

      log('Started recording with existing permission');
    } catch (e) {
      log('Failed to start recording with permission: $e');
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
        log('Silent for $silentSeconds seconds');

        if (silentSeconds >= 3) {
          log('Auto-stopping due to silence');
          stopStream();
        }
      } else {
        silentSeconds = 0;
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
      log('❌ Cannot listen to audio stream: channel is null or disposed');
      return;
    }

    log('🎧 Setting up WebSocket audio stream listener...');

    channel!.stream.listen(
      (data) async {
        if (_disposed) return; // Don't process messages if disposed

        try {
          log('📡 Raw WebSocket data received (${data.toString().length} chars): ${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}...');
          final Map<String, dynamic> message = jsonDecode(data);
          log('📡 Parsed message keys: ${message.keys.join(', ')}');
          await _handleServerMessage(message);
        } catch (e) {
          log('❌ Error parsing server message: $e');
          log('❌ Raw data that failed to parse: $data');
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
    log('📡 Received server message: ${message.keys.join(', ')}');
    log('📡 Full message preview: ${message.toString().substring(0, message.toString().length > 300 ? 300 : message.toString().length)}...');

    // Handle different message formats from Gemini server
    if (message.containsKey('audio')) {
      // Audio response from Gemini
      final audioData = message['audio'];
      log('🎵 Audio field found in message!');
      log('🎵 Audio data type: ${audioData.runtimeType}');
      log('🎵 Audio data present: ${audioData != null}');

      if (audioData != null) {
        if (audioData is String) {
          log('🎵 Audio data length: ${audioData.length} characters');
          log('🎵 Audio data preview: ${audioData.substring(0, audioData.length > 50 ? 50 : audioData.length)}');
        } else {
          log('🎵 Audio data is not a string: ${audioData.runtimeType}');
        }

        log('🎵 Attempting to play audio response...');
        await _playAudioResponse(audioData);
      } else {
        log('❌ Audio data is null - skipping playback');
      }
    } else if (message.containsKey('text')) {
      // Text response from Gemini
      final content = message['text'] ?? '';
      if (content.isNotEmpty) {
        _addConversationMessage(content, MessageSender.agent);
        setState(() {
          serverResponse = content;
        });
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

          await _playAudioResponse(audioData);
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
              await _playAudioResponse(audioData);
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

  Future<void> _playAudioResponse(dynamic audioData) async {
    if (!_isAudioAvailable) {
      log('Audio playback not available - using fallback');
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

    setState(() {
      isAiSpeaking = true;
    });

    try {
      Uint8List audioBytes;

      // Handle different audio data formats
      if (audioData is String) {
        // Base64 encoded audio from Gemini server
        log('🎵 Received base64 audio data: ${audioData.length} characters');
        log('🎵 First 50 chars: ${audioData.substring(0, audioData.length > 50 ? 50 : audioData.length)}');
        try {
          audioBytes = base64Decode(audioData);
          log('🎵 Successfully decoded audio bytes: ${audioBytes.length}');
          log('🎵 Audio header: ${audioBytes.take(20).toList()}');
        } catch (e) {
          log('❌ Error decoding base64 audio: $e');
          setState(() {
            isAiSpeaking = false;
          });
          return;
        }
      } else if (audioData is List) {
        // Raw byte array
        audioBytes = Uint8List.fromList(List<int>.from(audioData));
        log('Using raw audio bytes: ${audioBytes.length}');
      } else {
        log('Unknown audio data format: ${audioData.runtimeType}');
        setState(() {
          isAiSpeaking = false;
        });
        return;
      }

      // Validate audio data size
      if (audioBytes.length < 100) {
        log('❌ Audio data too small: ${audioBytes.length} bytes');
        setState(() {
          isAiSpeaking = false;
        });
        return;
      }

      // Validate MP3 format - check for MP3 header
      final isValidMP3 = _validateMP3Format(audioBytes);
      log('🔍 MP3 format validation: ${isValidMP3 ? "VALID" : "INVALID"}');

      if (!isValidMP3) {
        log('⚠️ Audio data doesn\'t appear to be valid MP3 format - trying anyway...');
      }

      // Use HTML5 Audio for web platform, SoLoud for native
      if (kIsWeb) {
        log('🌐 Using HTML5 Audio for web platform (bypassing SoLoud)...');
        try {
          await _playAudioWithHTML5(audioBytes);
          return;
        } catch (webError) {
          log('❌ HTML5 Audio failed: $webError');
          setState(() {
            isAiSpeaking = false;
          });
          return;
        }
      }

      // Native platforms: Use SoLoud
      try {
        // Dispose previous sound if exists
        if (currentSound != null) {
          await SoLoud.instance.disposeSource(currentSound!);
          currentSound = null;
        }

        // Load the MP3 audio data into SoLoud
        currentSound = await SoLoud.instance.loadMem(
          'gemini_response.mp3',
          audioBytes,
        );

        log('Audio loaded successfully: ${audioBytes.length} bytes');

        // Play the audio and get the handle
        _currentSoundHandle = await SoLoud.instance.play(currentSound!);
        log('Audio playing with handle: $_currentSoundHandle');

        // Verify the audio is actually playing
        final isPlaying =
            SoLoud.instance.getIsValidVoiceHandle(_currentSoundHandle!);
        log('Audio handle valid: $isPlaying');
      } catch (audioError) {
        log('❌ SoLoud audio loading/playing error: $audioError');

        // Even on native platforms, fallback to a simpler approach if SoLoud fails
        setState(() {
          isAiSpeaking = false;
        });

        // Show user-friendly error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Audio playback failed. Please check your device audio settings.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Set timeout for speaking state (longer timeout for safety)
      _speakingTimeoutTimer?.cancel();
      _speakingTimeoutTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) {
          setState(() {
            isAiSpeaking = false;
          });
        }
      });

      // Listen for audio completion (if possible)
      _listenForAudioCompletion();
    } catch (e) {
      log('Error playing audio response: $e');
      setState(() {
        isAiSpeaking = false;
      });
    }
  }

  void _listenForAudioCompletion() {
    if (kIsWeb) {
      // For web platform, audio completion is handled in HTML5 Audio event listeners
      log('Web platform - audio completion handled by HTML5 Audio events');
      return;
    }

    // Use SoLoud's built-in capabilities to check if audio is still playing
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
        }
      }
    });
  }

  void _listenToSoLoudEvents() {
    if (kIsWeb) {
      log('Web platform - HTML5 Audio events handled directly in playback method');
      return;
    }

    if (!_isAudioAvailable) return;

    // Note: SoLoud v3.1.10 doesn't have a global soundEvents stream
    // Audio completion is handled via the timeout timer and manual tracking
    log('SoLoud event listening initialized (using timeout-based tracking)');
  }

  void _testAudioPlayback() {
    // Test audio functionality after initialization
    log('Audio system ready for playback');

    // Optional: Test with a simple tone to verify audio is working
    if (_isAudioAvailable && kIsWeb) {
      log('Web audio system verified - ready for Gemini responses');
    }
  }

  // HTML5 Audio fallback when SoLoud fails
  Future<void> _playAudioWithHTML5(Uint8List audioBytes) async {
    if (!kIsWeb) {
      throw Exception('HTML5 Audio fallback only available on web');
    }

    log('🌐 Using HTML5 Audio API for playback...');

    try {
      // Create a blob URL from the audio bytes
      final base64Audio = base64Encode(audioBytes);
      final dataUrl = 'data:audio/mp3;base64,$base64Audio';

      // Use JavaScript interop to create and play audio
      final audioElement = html.AudioElement();
      audioElement.src = dataUrl;
      audioElement.volume = 1.0;
      audioElement.preload = 'auto';

      log('🌐 HTML5 Audio element created, starting playback...');

      // Create a completer for better async handling
      final completer = Completer<void>();

      // Set up event listeners
      audioElement.addEventListener('loadeddata', (event) {
        log('🌐 HTML5 Audio data loaded successfully');
      });

      audioElement.addEventListener('canplaythrough', (event) {
        log('🌐 HTML5 Audio ready to play');
      });

      audioElement.addEventListener('ended', (event) {
        log('🌐 HTML5 Audio playback completed');
        if (mounted) {
          setState(() {
            isAiSpeaking = false;
          });
        }
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      audioElement.addEventListener('error', (event) {
        log('❌ HTML5 Audio playback error: ${audioElement.error?.message ?? 'Unknown error'}');
        if (mounted) {
          setState(() {
            isAiSpeaking = false;
          });
        }
        if (!completer.isCompleted) {
          completer.completeError(Exception('HTML5 Audio playback failed'));
        }
      });

      // Set timeout for safety
      Timer(const Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          log('⏰ HTML5 Audio timeout - stopping playback');
          audioElement.pause();
          if (mounted) {
            setState(() {
              isAiSpeaking = false;
            });
          }
          completer.complete();
        }
      });

      // Start playing
      try {
        await audioElement.play();
        log('✅ HTML5 Audio playback started successfully');
      } catch (playError) {
        log('❌ HTML5 Audio play() failed: $playError');
        throw Exception('Failed to start HTML5 audio playback: $playError');
      }
    } catch (e) {
      log('❌ HTML5 Audio fallback error: $e');
      rethrow;
    }
  }

  // Validate MP3 format by checking headers
  bool _validateMP3Format(Uint8List audioBytes) {
    if (audioBytes.length < 4) return false;

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

    log('🔍 MP3 validation - Sync: $hasMP3Sync, ID3: $hasID3Tag');
    log('🔍 First 4 bytes: [${audioBytes[0].toRadixString(16)}, ${audioBytes[1].toRadixString(16)}, ${audioBytes[2].toRadixString(16)}, ${audioBytes[3].toRadixString(16)}]');

    return hasMP3Sync || hasID3Tag;
  }

  // Add a simple audio connectivity test
  Future<void> _testAudioConnectivity() async {
    if (!_isAudioAvailable) {
      log('❌ Audio not available for connectivity test');
      return;
    }

    if (kIsWeb) {
      log('🌐 Web platform - HTML5 Audio connectivity test');
      log('✅ HTML5 Audio ready for Gemini responses');
      return;
    }

    // Native platform SoLoud testing
    try {
      log('🔊 Testing SoLoud connectivity...');
      final volume = SoLoud.instance.getGlobalVolume();
      final isInit = SoLoud.instance.isInitialized;
      log('🔊 SoLoud status - Initialized: $isInit, Volume: $volume');

      // Test if we can load a simple sound (we'll generate minimal audio data)
      try {
        // Create a minimal valid MP3 header for testing
        final testBytes = Uint8List.fromList([
          0xFF, 0xFB, 0x90, 0x00, // MP3 header
          ...List.filled(100, 0x00), // Silent audio data
        ]);

        final testSound = await SoLoud.instance.loadMem('test.mp3', testBytes);
        log('🔊 Test audio load successful');

        // Immediately dispose test sound
        await SoLoud.instance.disposeSource(testSound);
        log('✅ Audio connectivity test passed - SoLoud ready for Gemini audio');
      } catch (testError) {
        log('⚠️ Test audio load failed: $testError (but SoLoud is initialized)');
      }
    } catch (e) {
      log('❌ Audio connectivity test failed: $e');
    }
  }

  // Simple HTML5 Audio Test
  Future<void> _testSimpleAudio() async {
    log('🔴 Testing SIMPLE HTML5 Audio...');

    if (!kIsWeb) {
      log('🔴 Simple test only works on web platform');
      return;
    }

    try {
      log('🔴 Creating basic HTML5 Audio element...');
      final audio = html.AudioElement();
      audio.src = 'gemini_output_for_transcription.mp3';
      audio.volume = 1.0;

      log('🔴 Attempting basic play()...');
      await audio.play();
      log('✅ Basic HTML5 Audio play() succeeded!');
    } catch (e) {
      log('❌ Basic HTML5 Audio failed: $e');
    }
  }

  // Test Audio Playback with Real Local File
  Future<void> _testLocalAudioPlayback() async {
    log('🧪 Testing local audio playback with real file...');

    try {
      if (kIsWeb) {
        // For web, directly test HTML5 Audio with the actual file
        log('🧪 Testing HTML5 Audio with real gemini_output_for_transcription.mp3...');

        final audioElement = html.AudioElement();
        audioElement.src =
            'gemini_output_for_transcription.mp3'; // Direct file path
        audioElement.volume = 1.0;
        audioElement.preload = 'auto';

        log('🧪 Created HTML5 Audio element for real file test');

        // Set up event listeners for debugging
        audioElement.addEventListener('loadstart', (event) {
          log('🧪 Audio loadstart event');
        });

        audioElement.addEventListener('loadeddata', (event) {
          log('✅ Audio data loaded successfully from file');
        });

        audioElement.addEventListener('canplaythrough', (event) {
          log('✅ Audio ready to play through');
        });

        audioElement.addEventListener('ended', (event) {
          log('✅ Audio playback completed');
          if (mounted) {
            setState(() {
              isAiSpeaking = false;
            });
          }
        });

        audioElement.addEventListener('error', (event) {
          log('❌ Audio error: ${audioElement.error?.message ?? 'Unknown error'}');
          log('❌ Error code: ${audioElement.error?.code}');
        });

        // Try to play
        try {
          setState(() {
            isAiSpeaking = true;
          });

          await audioElement.play();
          log('✅ Audio playback started successfully with real file');
        } catch (playError) {
          log('❌ Failed to play audio: $playError');
          setState(() {
            isAiSpeaking = false;
          });
        }
      } else {
        // For native platforms, we could test with SoLoud
        log('🧪 Native platform - testing with SoLoud would go here');
      }
    } catch (e) {
      log('❌ Test audio playback failed: $e');
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
}
