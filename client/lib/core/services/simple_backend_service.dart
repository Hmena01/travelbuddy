import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';

/// Simple backend service that simulates server responses
/// This ensures the app works even when the main WebSocket server is unavailable
class SimpleBackendService {
  static final SimpleBackendService _instance =
      SimpleBackendService._internal();
  factory SimpleBackendService() => _instance;
  SimpleBackendService._internal();

  // Mock responses for testing
  final List<String> _mockTranslations = [
    'Hello - Hola (Spanish)',
    'Thank you - Merci (French)',
    'Good morning - Guten Morgen (German)',
    'How are you? - Come stai? (Italian)',
    'Nice to meet you - 初めまして (Japanese)',
  ];

  final List<String> _mockResponses = [
    'I understand what you\'re saying. How can I help you translate this?',
    'That\'s interesting! Would you like me to translate this to another language?',
    'I can help you with translation. Which language would you prefer?',
    'Great! I can translate that for you. Please specify the target language.',
    'I\'m here to help with your translation needs. What would you like to translate?',
  ];

  /// Simulate processing a transcription and returning a response
  Future<Map<String, dynamic>> processTranscription(
      String transcription) async {
    await Future.delayed(
        const Duration(milliseconds: 500)); // Simulate processing time

    dev.log('Processing transcription: $transcription', name: 'SimpleBackend');

    // Generate mock response based on input
    String response;
    String type = 'translation';

    if (transcription.toLowerCase().contains('translate')) {
      response = _mockTranslations[Random().nextInt(_mockTranslations.length)];
      type = 'translation';
    } else if (transcription.toLowerCase().contains('help')) {
      response =
          'I can help you translate text between many languages. Just tell me what you\'d like to translate!';
      type = 'help';
    } else {
      response = _mockResponses[Random().nextInt(_mockResponses.length)];
      type = 'conversation';
    }

    return {
      'type': type,
      'text': response,
      'confidence': 0.8 + (Random().nextDouble() * 0.2), // 0.8-1.0 confidence
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'source_language': 'en',
      'target_language': 'auto',
    };
  }

  /// Generate mock audio response (just metadata since we don't generate actual audio)
  Future<Map<String, dynamic>> generateAudioResponse(String text) async {
    await Future.delayed(
        const Duration(milliseconds: 300)); // Simulate audio generation

    dev.log('Generating audio for: $text', name: 'SimpleBackend');

    return {
      'type': 'audio_response',
      'text': text,
      'audio_url': 'mock://audio_response.mp3',
      'duration_ms': text.length * 100, // Rough estimate: 100ms per character
      'voice': 'neural_voice',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Simulate connection test
  Future<bool> testConnection() async {
    await Future.delayed(const Duration(milliseconds: 200));
    dev.log('Mock connection test passed', name: 'SimpleBackend');
    return true;
  }

  /// Get mock server status
  Map<String, dynamic> getServerStatus() {
    return {
      'status': 'connected',
      'type': 'mock_server',
      'capabilities': [
        'text_translation',
        'voice_recognition',
        'text_to_speech',
        'conversation',
      ],
      'supported_languages': [
        'en',
        'es',
        'fr',
        'de',
        'it',
        'ja',
        'ko',
        'zh',
      ],
      'mock_mode': true,
    };
  }

  /// Generate contextual suggestions based on conversation
  List<Map<String, dynamic>> generateSuggestions(String lastMessage) {
    List<Map<String, dynamic>> suggestions = [];

    if (lastMessage.toLowerCase().contains('hello') ||
        lastMessage.toLowerCase().contains('hi')) {
      suggestions.addAll([
        {'text': 'Translate to Spanish', 'action': 'translate_es'},
        {'text': 'Translate to French', 'action': 'translate_fr'},
        {'text': 'Learn more greetings', 'action': 'help_greetings'},
      ]);
    } else if (lastMessage.toLowerCase().contains('translate')) {
      suggestions.addAll([
        {'text': 'Choose target language', 'action': 'select_language'},
        {'text': 'Speak pronunciation', 'action': 'pronounce'},
        {'text': 'Save translation', 'action': 'save'},
      ]);
    } else {
      suggestions.addAll([
        {'text': 'Translate this', 'action': 'translate'},
        {'text': 'Get help', 'action': 'help'},
        {'text': 'Try voice input', 'action': 'voice'},
      ]);
    }

    return suggestions;
  }
}
