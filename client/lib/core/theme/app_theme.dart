import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Core Brand Colors
  static const Color primaryBlue = Color(0xFF4D96FF);
  static const Color accentPurple = Color(0xFF6366F1);
  static const Color primaryPurple =
      Color(0xFF6366F1); // Add alias for consistency
  static const Color lightBlue = Color(0xFF8BC7FF);
  static const Color darkBlue = Color(0xFF1E40AF);

  // Neutral Colors
  static const Color backgroundLight = Color(0xFFFAFBFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color borderLight = Color(0xFFE5E7EB);

  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Shadows
  static List<BoxShadow> get shadowSmall => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get shadowMedium => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 15,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowLarge => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  // Text Theme Getter
  static TextTheme get textTheme => _buildTextTheme(textPrimary);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, accentPurple],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.white, backgroundLight],
  );

  // NEW: Enhanced Gradients for Modern UI
  static const LinearGradient modernGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF667eea),
      Color(0xFF764ba2),
      Color(0xFFa18cd1),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x40FFFFFF),
      Color(0x20FFFFFF),
    ],
  );

  static const LinearGradient conversationGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF8FAFF),
      Color(0xFFE8F1FF),
    ],
  );

  // NEW: Glassmorphism Helper
  static BoxDecoration get glassmorphism => BoxDecoration(
        gradient: glassGradient,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  // NEW: Enhanced Card Decoration
  static BoxDecoration get modernCard => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(
          color: borderLight.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      );

  // NEW: Conversation Bubble Decorations
  static BoxDecoration userBubble = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryBlue, lightBlue],
    ),
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(radiusLg),
      topRight: Radius.circular(radiusLg),
      bottomLeft: Radius.circular(radiusLg),
      bottomRight: Radius.circular(radiusSm),
    ),
    boxShadow: [
      BoxShadow(
        color: primaryBlue.withValues(alpha: 0.3),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration agentBubble = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(radiusLg),
      topRight: Radius.circular(radiusLg),
      bottomLeft: Radius.circular(radiusSm),
      bottomRight: Radius.circular(radiusLg),
    ),
    border: Border.all(
      color: borderLight,
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // Typography - temporarily using system font until Inter assets are added
  static const String primaryFontFamily = 'Roboto'; // System font

  static TextTheme _buildTextTheme(Color textColor) {
    return TextTheme(
      // Display
      displayLarge: TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: textColor,
      ),
      displayMedium: TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      displaySmall: TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),

      // Headline
      headlineLarge: TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineMedium: TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineSmall: TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),

      // Title
      titleLarge: TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleMedium: TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textColor,
      ),
      titleSmall: TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textColor,
      ),

      // Body
      bodyLarge: TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        color: textColor,
      ),
      bodyMedium: TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: textColor,
      ),
      bodySmall: TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: textColor,
      ),

      // Label
      labelLarge: TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textColor,
      ),
      labelMedium: TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: textColor,
      ),
      labelSmall: TextStyle(
        fontFamily: primaryFontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: textColor,
      ),
    );
  }

  // Light Theme
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
      primary: primaryBlue,
      secondary: accentPurple,
      surface: surfaceLight,
      // background: backgroundLight, // Deprecated - using surface instead
      error: error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(textPrimary),
      fontFamily: primaryFontFamily,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceLight,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: _buildTextTheme(textPrimary).titleLarge,
        iconTheme: IconThemeData(color: textPrimary),
        actionsIconTheme: IconThemeData(color: textPrimary),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      // Card Theme
      cardTheme: CardTheme(
        color: surfaceLight,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: primaryBlue,
          elevation: 2,
          shadowColor: primaryBlue.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: _buildTextTheme(Colors.white).labelLarge,
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textTertiary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textTertiary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // Icon Theme
      iconTheme: IconThemeData(
        color: textPrimary,
        size: 24,
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryBlue,
        linearTrackColor: textTertiary.withValues(alpha: 0.2),
        circularTrackColor: textTertiary.withValues(alpha: 0.2),
      ),

      // Snack Bar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: _buildTextTheme(Colors.white).bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // Dialog Theme
      dialogTheme: DialogTheme(
        backgroundColor: surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: _buildTextTheme(textPrimary).headlineSmall,
        contentTextStyle: _buildTextTheme(textSecondary).bodyMedium,
      ),
    );
  }

  // Dark Theme (for future implementation)
  static ThemeData get darkTheme {
    // Implement dark theme when needed
    return lightTheme;
  }

  // Semantic Colors Helper
  static Color getSemanticColor(SemanticColorType type) {
    switch (type) {
      case SemanticColorType.success:
        return success;
      case SemanticColorType.warning:
        return warning;
      case SemanticColorType.error:
        return error;
      case SemanticColorType.info:
        return info;
    }
  }

  // Animation Durations
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration slowAnimation = Duration(milliseconds: 600);

  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Border Radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;

  // Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}

enum SemanticColorType {
  success,
  warning,
  error,
  info,
}
