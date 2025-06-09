import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Performance monitoring and optimization service
/// Implements Flutter performance best practices for smooth 60fps experience
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  // Performance metrics
  final Map<String, double> _performanceMetrics = {};
  final List<PerformanceEvent> _performanceEvents = [];
  Timer? _monitoringTimer;

  // Device capabilities
  DeviceCapabilities? _deviceCapabilities;
  bool _isHighPerformanceDevice = true;

  // Stream for performance updates
  final StreamController<PerformanceMetrics> _metricsController =
      StreamController<PerformanceMetrics>.broadcast();

  Stream<PerformanceMetrics> get metricsStream => _metricsController.stream;

  bool get isHighPerformanceDevice => _isHighPerformanceDevice;
  DeviceCapabilities? get deviceCapabilities => _deviceCapabilities;
  Map<String, double> get currentMetrics =>
      Map.unmodifiable(_performanceMetrics);

  /// Initialize performance monitoring
  Future<void> initialize() async {
    try {
      await _detectDeviceCapabilities();
      _configureOptimizations();
      _startPerformanceMonitoring();

      dev.log('Performance service initialized', name: 'Performance');
      dev.log(
          'Device performance level: ${_isHighPerformanceDevice ? "High" : "Low"}',
          name: 'Performance');
    } catch (e) {
      dev.log('Error initializing performance service: $e',
          name: 'Performance');
    }
  }

  /// Record a performance event
  void recordEvent(
    PerformanceEventType type, {
    String? description,
    Duration? duration,
    Map<String, dynamic>? metadata,
  }) {
    final event = PerformanceEvent(
      type: type,
      timestamp: DateTime.now(),
      description: description,
      duration: duration,
      metadata: metadata ?? {},
    );

    _performanceEvents.add(event);

    // Keep only last 100 events
    if (_performanceEvents.length > 100) {
      _performanceEvents.removeAt(0);
    }

    // Update metrics based on event
    _updateMetricsFromEvent(event);

    if (kDebugMode && duration != null) {
      dev.log(
          'Performance event: ${type.toString()} - ${duration.inMilliseconds}ms',
          name: 'Performance');
    }
  }

  /// Start timing an operation
  PerformanceTimer startTimer(String operationName) {
    return PerformanceTimer(operationName, this);
  }

  /// Optimize animations based on device performance
  Duration getOptimalAnimationDuration(Duration defaultDuration) {
    if (!_isHighPerformanceDevice) {
      // Reduce animation duration on low-performance devices
      return Duration(
          milliseconds: (defaultDuration.inMilliseconds * 0.7).round());
    }
    return defaultDuration;
  }

  /// Get optimal image resolution based on device capabilities
  double getOptimalImageScale() {
    if (!_isHighPerformanceDevice) {
      return 0.8; // Reduce image resolution on low-performance devices
    }
    return 1.0;
  }

  /// Check if feature should be enabled based on performance
  bool shouldEnableFeature(PerformanceFeature feature) {
    switch (feature) {
      case PerformanceFeature.complexAnimations:
        return _isHighPerformanceDevice;
      case PerformanceFeature.highQualityImages:
        return _isHighPerformanceDevice;
      case PerformanceFeature.backgroundProcessing:
        return _isHighPerformanceDevice;
      case PerformanceFeature.realtimeEffects:
        return _isHighPerformanceDevice;
      case PerformanceFeature.heavyComputations:
        return _isHighPerformanceDevice;
    }
  }

  /// Optimize memory usage
  Future<void> optimizeMemory() async {
    try {
      // Force garbage collection
      await _forceGarbageCollection();

      // Clear cached images if memory pressure is high
      if (_isMemoryPressureHigh()) {
        await _clearImageCache();
      }

      // Reduce animation controllers if needed
      if (!_isHighPerformanceDevice) {
        _optimizeAnimationControllers();
      }

      recordEvent(PerformanceEventType.memoryOptimization);
      dev.log('Memory optimization completed', name: 'Performance');
    } catch (e) {
      dev.log('Error during memory optimization: $e', name: 'Performance');
    }
  }

  /// Get performance recommendations
  List<PerformanceRecommendation> getRecommendations() {
    final recommendations = <PerformanceRecommendation>[];

    // Check frame rate
    final avgFrameTime = _performanceMetrics['avgFrameTime'] ?? 0;
    if (avgFrameTime > 16.67) {
      // More than 60fps
      recommendations.add(
        PerformanceRecommendation(
          type: RecommendationType.frameRate,
          severity: RecommendationSeverity.high,
          description:
              'Frame rate is below 60fps. Consider reducing animation complexity.',
          action: 'Optimize animations and reduce visual effects',
        ),
      );
    }

    // Check memory usage
    final memoryUsage = _performanceMetrics['memoryUsage'] ?? 0;
    if (memoryUsage > 100) {
      // More than 100MB
      recommendations.add(
        PerformanceRecommendation(
          type: RecommendationType.memory,
          severity: RecommendationSeverity.medium,
          description:
              'Memory usage is high. Consider optimizing image caching.',
          action: 'Reduce image cache size and optimize memory usage',
        ),
      );
    }

    // Check startup time
    final startupTime = _performanceMetrics['startupTime'] ?? 0;
    if (startupTime > 3000) {
      // More than 3 seconds
      recommendations.add(
        PerformanceRecommendation(
          type: RecommendationType.startup,
          severity: RecommendationSeverity.medium,
          description: 'App startup time is slow. Consider lazy loading.',
          action: 'Implement lazy loading for non-critical components',
        ),
      );
    }

    return recommendations;
  }

  /// Dispose resources
  void dispose() {
    _monitoringTimer?.cancel();
    _metricsController.close();
  }

  // Private methods

  Future<void> _detectDeviceCapabilities() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceCapabilities = DeviceCapabilities(
          platform: 'Android',
          model: androidInfo.model,
          totalMemory: _estimateMemoryFromModel(androidInfo.model),
          processorInfo: androidInfo.hardware,
          osVersion: androidInfo.version.release,
        );

        // Estimate performance based on Android device info
        _isHighPerformanceDevice = _estimateAndroidPerformance(androidInfo);
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceCapabilities = DeviceCapabilities(
          platform: 'iOS',
          model: iosInfo.model,
          totalMemory: _estimateMemoryFromIOSModel(iosInfo.model),
          processorInfo: iosInfo.utsname.machine,
          osVersion: iosInfo.systemVersion,
        );

        // Estimate performance based on iOS device info
        _isHighPerformanceDevice = _estimateIOSPerformance(iosInfo);
      } else {
        // Web or other platforms
        _deviceCapabilities = DeviceCapabilities(
          platform: kIsWeb ? 'Web' : 'Desktop',
          model: 'Unknown',
          totalMemory: 4096, // Assume 4GB
          processorInfo: 'Unknown',
          osVersion: 'Unknown',
        );
        _isHighPerformanceDevice =
            true; // Assume high performance for web/desktop
      }
    } catch (e) {
      dev.log('Error detecting device capabilities: $e', name: 'Performance');
      _isHighPerformanceDevice = true; // Default to high performance
    }
  }

  void _configureOptimizations() {
    // Configure optimizations based on device performance
    if (!_isHighPerformanceDevice) {
      dev.log('Low-performance optimizations enabled', name: 'Performance');
    } else {
      dev.log('High-performance mode enabled', name: 'Performance');
    }
  }

  void _startPerformanceMonitoring() {
    _monitoringTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _updatePerformanceMetrics();
    });
  }

  void _updatePerformanceMetrics() {
    // Update various performance metrics
    final metrics = PerformanceMetrics(
      frameRate: _calculateFrameRate(),
      memoryUsage: _estimateMemoryUsage(),
      cpuUsage: _estimateCPUUsage(),
      batteryImpact: _estimateBatteryImpact(),
      networkLatency: _estimateNetworkLatency(),
      timestamp: DateTime.now(),
    );

    // Store metrics
    _performanceMetrics['frameRate'] = metrics.frameRate;
    _performanceMetrics['memoryUsage'] = metrics.memoryUsage;
    _performanceMetrics['cpuUsage'] = metrics.cpuUsage;
    _performanceMetrics['batteryImpact'] = metrics.batteryImpact;
    _performanceMetrics['networkLatency'] = metrics.networkLatency;

    // Send to stream
    _metricsController.add(metrics);
  }

  void _updateMetricsFromEvent(PerformanceEvent event) {
    switch (event.type) {
      case PerformanceEventType.appStartup:
        if (event.duration != null) {
          _performanceMetrics['startupTime'] =
              event.duration!.inMilliseconds.toDouble();
        }
        break;
      case PerformanceEventType.frameRender:
        if (event.duration != null) {
          _performanceMetrics['avgFrameTime'] =
              event.duration!.inMilliseconds.toDouble();
        }
        break;
      case PerformanceEventType.networkRequest:
        if (event.duration != null) {
          _performanceMetrics['avgNetworkTime'] =
              event.duration!.inMilliseconds.toDouble();
        }
        break;
      default:
        break;
    }
  }

  double _calculateFrameRate() {
    // In a real implementation, this would track actual frame rendering
    // For now, return estimated frame rate based on device performance
    return _isHighPerformanceDevice ? 60.0 : 45.0;
  }

  double _estimateMemoryUsage() {
    // Estimate current memory usage (in MB)
    // This is a simplified estimation
    final baseUsage = 40.0; // Base app memory usage
    final audioBufferUsage = 10.0; // Audio processing memory
    final uiMemory = _isHighPerformanceDevice ? 15.0 : 8.0;

    return baseUsage + audioBufferUsage + uiMemory;
  }

  double _estimateCPUUsage() {
    // Estimate CPU usage percentage
    // This would be more accurate with native platform channels
    return _isHighPerformanceDevice ? 15.0 : 25.0;
  }

  double _estimateBatteryImpact() {
    // Estimate battery impact (scale 1-10)
    return _isHighPerformanceDevice ? 3.0 : 5.0;
  }

  double _estimateNetworkLatency() {
    // Estimate network latency in milliseconds
    return 50.0; // Placeholder
  }

  bool _estimateAndroidPerformance(AndroidDeviceInfo info) {
    // Estimate performance based on Android device characteristics
    final sdkInt = info.version.sdkInt;
    final totalMemory = _estimateMemoryFromModel(info.model);

    // Devices with Android 8+ (API 26) and 4GB+ RAM are considered high performance
    return sdkInt >= 26 && totalMemory >= 4096;
  }

  bool _estimateIOSPerformance(IosDeviceInfo info) {
    // iOS devices are generally high performance
    // Consider devices with iOS 13+ as high performance
    final majorVersion = int.tryParse(info.systemVersion.split('.').first) ?? 0;
    return majorVersion >= 13;
  }

  int _estimateMemoryFromModel(String model) {
    // Simplified memory estimation based on model name
    final lowerModel = model.toLowerCase();

    if (lowerModel.contains('pro') || lowerModel.contains('max')) {
      return 8192; // 8GB
    } else if (lowerModel.contains('plus') || lowerModel.contains('xl')) {
      return 6144; // 6GB
    } else {
      return 4096; // 4GB
    }
  }

  int _estimateMemoryFromIOSModel(String model) {
    // iOS memory estimation
    final lowerModel = model.toLowerCase();

    if (lowerModel.contains('pro') || lowerModel.contains('max')) {
      return 8192; // 8GB
    } else if (lowerModel.contains('plus')) {
      return 6144; // 6GB
    } else {
      return 4096; // 4GB
    }
  }

  Future<void> _forceGarbageCollection() async {
    // Request garbage collection (platform-specific implementation would be better)
    await Future.delayed(const Duration(milliseconds: 100));
  }

  bool _isMemoryPressureHigh() {
    final memoryUsage = _performanceMetrics['memoryUsage'] ?? 0;
    return memoryUsage > 150; // More than 150MB
  }

  Future<void> _clearImageCache() async {
    // Clear image cache to free memory
    // In a real implementation, this would clear cached images
    await Future.delayed(const Duration(milliseconds: 50));
  }

  void _optimizeAnimationControllers() {
    // Reduce animation complexity on low-performance devices
    // This would involve reducing animation frame rates or simplifying animations
  }
}

// Performance Timer helper class
class PerformanceTimer {
  final String operationName;
  final PerformanceService _service;
  final Stopwatch _stopwatch = Stopwatch();

  PerformanceTimer(this.operationName, this._service) {
    _stopwatch.start();
  }

  void stop({String? description, Map<String, dynamic>? metadata}) {
    _stopwatch.stop();
    _service.recordEvent(
      PerformanceEventType.customOperation,
      description: description ?? operationName,
      duration: _stopwatch.elapsed,
      metadata: metadata,
    );
  }
}

// Data models

enum PerformanceEventType {
  appStartup,
  frameRender,
  networkRequest,
  memoryOptimization,
  imageLoad,
  audioProcess,
  customOperation,
}

enum PerformanceFeature {
  complexAnimations,
  highQualityImages,
  backgroundProcessing,
  realtimeEffects,
  heavyComputations,
}

enum RecommendationType {
  frameRate,
  memory,
  startup,
  network,
  battery,
}

enum RecommendationSeverity {
  low,
  medium,
  high,
  critical,
}

class PerformanceEvent {
  final PerformanceEventType type;
  final DateTime timestamp;
  final String? description;
  final Duration? duration;
  final Map<String, dynamic> metadata;

  PerformanceEvent({
    required this.type,
    required this.timestamp,
    this.description,
    this.duration,
    required this.metadata,
  });
}

class PerformanceMetrics {
  final double frameRate;
  final double memoryUsage;
  final double cpuUsage;
  final double batteryImpact;
  final double networkLatency;
  final DateTime timestamp;

  PerformanceMetrics({
    required this.frameRate,
    required this.memoryUsage,
    required this.cpuUsage,
    required this.batteryImpact,
    required this.networkLatency,
    required this.timestamp,
  });
}

class DeviceCapabilities {
  final String platform;
  final String model;
  final int totalMemory; // in MB
  final String processorInfo;
  final String osVersion;

  DeviceCapabilities({
    required this.platform,
    required this.model,
    required this.totalMemory,
    required this.processorInfo,
    required this.osVersion,
  });
}

class PerformanceRecommendation {
  final RecommendationType type;
  final RecommendationSeverity severity;
  final String description;
  final String action;

  PerformanceRecommendation({
    required this.type,
    required this.severity,
    required this.description,
    required this.action,
  });
}
