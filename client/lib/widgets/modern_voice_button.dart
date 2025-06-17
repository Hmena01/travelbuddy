import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/services/performance_service.dart';

/// Modern voice recording button with smooth animations and professional design
class ModernVoiceButton extends StatefulWidget {
  final bool isRecording;
  final bool isAiSpeaking;
  final bool isConnecting;
  final VoidCallback? onPressed;
  final String? tooltip;

  const ModernVoiceButton({
    super.key,
    required this.isRecording,
    required this.isAiSpeaking,
    required this.isConnecting,
    this.onPressed,
    this.tooltip,
  });

  @override
  State<ModernVoiceButton> createState() => _ModernVoiceButtonState();
}

class _ModernVoiceButtonState extends State<ModernVoiceButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late AnimationController _scaleController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<double> _scaleAnimation;

  final PerformanceService _performanceService = PerformanceService();

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    // Get optimal animation durations based on device performance
    final pulseDuration = _performanceService.getOptimalAnimationDuration(
      const Duration(milliseconds: 1500),
    );
    final rippleDuration = _performanceService.getOptimalAnimationDuration(
      const Duration(milliseconds: 800),
    );
    final scaleDuration = _performanceService.getOptimalAnimationDuration(
      const Duration(milliseconds: 200),
    );

    _pulseController = AnimationController(
      duration: pulseDuration,
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: rippleDuration,
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: scaleDuration,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _updateAnimations();
  }

  void _updateAnimations() {
    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
      _rippleController.repeat();
    } else if (widget.isAiSpeaking) {
      _pulseController.repeat(reverse: true);
      _rippleController.stop();
    } else {
      _pulseController.stop();
      _rippleController.stop();
      _pulseController.reset();
      _rippleController.reset();
    }
  }

  @override
  void didUpdateWidget(ModernVoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRecording != widget.isRecording ||
        oldWidget.isAiSpeaking != widget.isAiSpeaking) {
      _updateAnimations();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = !widget.isConnecting && widget.onPressed != null;

    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple effect for recording
          if (widget.isRecording)
            AnimatedBuilder(
              animation: _rippleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_rippleAnimation.value * 0.8),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(
                          alpha: 0.3 - (_rippleAnimation.value * 0.3),
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            ),

          // Pulse effect for recording and speaking
          if (widget.isRecording || widget.isAiSpeaking)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getBackgroundColor().withValues(alpha: 0.2),
                    ),
                  ),
                );
              },
            ),

          // Main button
          GestureDetector(
            onTapDown: isEnabled ? (_) => _scaleController.forward() : null,
            onTapUp: isEnabled ? (_) => _scaleController.reverse() : null,
            onTapCancel: isEnabled ? () => _scaleController.reverse() : null,
            onTap: isEnabled ? widget.onPressed : null,
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _getGradient(),
                      boxShadow: _getShadow(),
                    ),
                    child: Icon(
                      _getIcon(),
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                );
              },
            ),
          ),

          // Loading indicator for connecting state
          if (widget.isConnecting)
            SizedBox(
              width: 90,
              height: 90,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryBlue,
                backgroundColor: AppTheme.textTertiary.withValues(alpha: 0.2),
              ),
            ),
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    if (widget.isRecording) {
      return AppTheme.error;
    } else if (widget.isAiSpeaking) {
      return AppTheme.accentPurple;
    } else {
      return AppTheme.primaryBlue;
    }
  }

  Gradient _getGradient() {
    if (widget.isRecording) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.error,
          AppTheme.error.withValues(alpha: 0.8),
        ],
      );
    } else if (widget.isAiSpeaking) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.accentPurple,
          AppTheme.primaryBlue,
        ],
      );
    } else if (widget.isConnecting) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.textTertiary,
          AppTheme.textSecondary,
        ],
      );
    } else {
      return AppTheme.primaryGradient;
    }
  }

  IconData _getIcon() {
    if (widget.isRecording) {
      return Icons.stop_rounded;
    } else if (widget.isAiSpeaking) {
      return Icons.volume_up_rounded;
    } else if (widget.isConnecting) {
      return Icons.sync_rounded;
    } else {
      return Icons.mic_rounded;
    }
  }

  List<BoxShadow> _getShadow() {
    final color = _getBackgroundColor();

    return [
      BoxShadow(
        color: color.withValues(alpha: 0.3),
        blurRadius: 12,
        offset: const Offset(0, 6),
        spreadRadius: 0,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.1),
        blurRadius: 20,
        offset: const Offset(0, 10),
        spreadRadius: 0,
      ),
    ];
  }
}

/// Compact voice button for smaller spaces
class CompactVoiceButton extends StatelessWidget {
  final bool isRecording;
  final bool isAiSpeaking;
  final VoidCallback? onPressed;
  final double size;

  const CompactVoiceButton({
    super.key,
    required this.isRecording,
    required this.isAiSpeaking,
    this.onPressed,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _getGradient(),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Icon(
            _getIcon(),
            color: Colors.white,
            size: size * 0.4,
          ),
        ),
      ),
    );
  }

  Gradient _getGradient() {
    if (isRecording) {
      return LinearGradient(
        colors: [AppTheme.error, AppTheme.error.withValues(alpha: 0.8)],
      );
    } else if (isAiSpeaking) {
      return LinearGradient(
        colors: [AppTheme.accentPurple, AppTheme.primaryBlue],
      );
    } else {
      return AppTheme.primaryGradient;
    }
  }

  IconData _getIcon() {
    if (isRecording) {
      return Icons.stop_rounded;
    } else if (isAiSpeaking) {
      return Icons.volume_up_rounded;
    } else {
      return Icons.mic_rounded;
    }
  }
}

/// Voice visualization widget for showing audio levels
class VoiceVisualization extends StatefulWidget {
  final bool isActive;
  final double audioLevel; // 0.0 to 1.0

  const VoiceVisualization({
    super.key,
    required this.isActive,
    this.audioLevel = 0.0,
  });

  @override
  State<VoiceVisualization> createState() => _VoiceVisualizationState();
}

class _VoiceVisualizationState extends State<VoiceVisualization>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late List<AnimationController> _barControllers;
  late List<Animation<double>> _barAnimations;

  static const int barCount = 20;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    final duration = PerformanceService().getOptimalAnimationDuration(
      const Duration(milliseconds: 100),
    );

    _animationController = AnimationController(
      duration: duration,
      vsync: this,
    );

    _barControllers = List.generate(
      barCount,
      (index) => AnimationController(
        duration: Duration(milliseconds: 100 + (index * 20)),
        vsync: this,
      ),
    );

    _barAnimations = _barControllers
        .map((controller) => Tween<double>(begin: 0.1, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeInOut)))
        .toList();

    if (widget.isActive) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    for (var i = 0; i < _barControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted && widget.isActive) {
          _barControllers[i].repeat(reverse: true);
        }
      });
    }
  }

  void _stopAnimation() {
    for (final controller in _barControllers) {
      controller.stop();
      controller.reset();
    }
  }

  @override
  void didUpdateWidget(VoiceVisualization oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (final controller in _barControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(barCount, (index) {
          return AnimatedBuilder(
            animation: _barAnimations[index],
            builder: (context, child) {
              final height = widget.isActive
                  ? 4 + (50 * _barAnimations[index].value * widget.audioLevel)
                  : 4.0;

              return Container(
                width: 3,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? AppTheme.primaryBlue.withValues(alpha: 0.8)
                      : AppTheme.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
