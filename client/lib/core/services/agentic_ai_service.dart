import 'dart:async';
import 'dart:developer' as dev;
import 'package:equatable/equatable.dart';

/// Core agentic AI service that provides intelligent behaviors,
/// context management, and proactive assistance capabilities
class AgenticAIService {
  static final AgenticAIService _instance = AgenticAIService._internal();
  factory AgenticAIService() => _instance;
  AgenticAIService._internal();

  // Conversation context and memory
  final List<ConversationMessage> _conversationHistory = [];
  final Map<String, dynamic> _userPreferences = {};
  final Map<String, dynamic> _sessionContext = {};

  // Agent state
  AgentState _currentState = AgentState.idle;
  Timer? _proactiveTimer;

  // Streams for reactive updates
  final StreamController<AgentState> _stateController =
      StreamController<AgentState>.broadcast();
  final StreamController<AgenticSuggestion> _suggestionController =
      StreamController<AgenticSuggestion>.broadcast();
  final StreamController<List<ConversationMessage>> _historyController =
      StreamController<List<ConversationMessage>>.broadcast();

  // Getters
  Stream<AgentState> get stateStream => _stateController.stream;
  Stream<AgenticSuggestion> get suggestionStream =>
      _suggestionController.stream;
  Stream<List<ConversationMessage>> get historyStream =>
      _historyController.stream;

  AgentState get currentState => _currentState;
  List<ConversationMessage> get conversationHistory =>
      List.unmodifiable(_conversationHistory);
  Map<String, dynamic> get userPreferences =>
      Map.unmodifiable(_userPreferences);

  /// Initialize the agentic service
  Future<void> initialize() async {
    try {
      await _loadUserPreferences();
      await _loadConversationHistory();
      _startProactiveAssistance();

      _updateState(AgentState.ready);
      dev.log('Agentic AI service initialized', name: 'AgenticAI');
    } catch (e) {
      dev.log('Error initializing agentic AI service: $e', name: 'AgenticAI');
      _updateState(AgentState.error);
    }
  }

  /// Process a new user message and generate intelligent response
  Future<AgenticResponse> processMessage({
    required String message,
    required MessageType type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _updateState(AgentState.thinking);

      // Add user message to history
      final userMessage = ConversationMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: message,
        type: type,
        sender: MessageSender.user,
        timestamp: DateTime.now(),
        metadata: metadata ?? {},
      );

      _addMessageToHistory(userMessage);

      // Analyze message and determine response strategy
      final intent = await _analyzeIntent(message, type);
      final context = _buildContext();

      // Generate response based on intent and context
      final response = await _generateResponse(intent, context, userMessage);

      // Add agent response to history
      final agentMessage = ConversationMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: response.primaryResponse,
        type: MessageType.text,
        sender: MessageSender.agent,
        timestamp: DateTime.now(),
        metadata: {
          'intent': intent.toString(),
          'confidence': response.confidence,
          'suggestions': response.suggestions.map((s) => s.toJson()).toList(),
        },
      );

      _addMessageToHistory(agentMessage);

      // Generate proactive suggestions if appropriate
      if (response.confidence > 0.7) {
        _generateProactiveSuggestions(intent, context);
      }

      _updateState(AgentState.ready);
      return response;
    } catch (e) {
      dev.log('Error processing message: $e', name: 'AgenticAI');
      _updateState(AgentState.error);

      return AgenticResponse(
        primaryResponse:
            'I apologize, but I encountered an error processing your request. Please try again.',
        responseType: ResponseType.error,
        confidence: 0.0,
        suggestions: [],
        actions: [],
      );
    }
  }

  /// Update user preferences
  Future<void> updateUserPreferences(Map<String, dynamic> preferences) async {
    _userPreferences.addAll(preferences);
    await _saveUserPreferences();
    dev.log('User preferences updated', name: 'AgenticAI');
  }

  /// Clear conversation history
  Future<void> clearHistory() async {
    _conversationHistory.clear();
    _sessionContext.clear();
    _historyController.add(_conversationHistory);
    await _saveConversationHistory();
    dev.log('Conversation history cleared', name: 'AgenticAI');
  }

  /// Get contextual suggestions for current state
  List<AgenticSuggestion> getContextualSuggestions() {
    final suggestions = <AgenticSuggestion>[];

    // Base suggestions based on current state
    switch (_currentState) {
      case AgentState.idle:
      case AgentState.ready:
        suggestions.addAll(_getIdleSuggestions());
        break;
      case AgentState.listening:
        suggestions.addAll(_getListeningSuggestions());
        break;
      case AgentState.thinking:
        // No suggestions while thinking
        break;
      case AgentState.speaking:
        suggestions.addAll(_getSpeakingSuggestions());
        break;
      case AgentState.error:
        suggestions.addAll(_getErrorSuggestions());
        break;
    }

    // Add context-based suggestions
    suggestions.addAll(_getContextBasedSuggestions());

    return suggestions;
  }

  /// Dispose resources
  void dispose() {
    _proactiveTimer?.cancel();
    _stateController.close();
    _suggestionController.close();
    _historyController.close();
  }

  // Private methods

  void _updateState(AgentState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
      dev.log('Agent state changed to: $newState', name: 'AgenticAI');
    }
  }

  void _addMessageToHistory(ConversationMessage message) {
    _conversationHistory.add(message);

    // Keep only last 50 messages for performance
    if (_conversationHistory.length > 50) {
      _conversationHistory.removeAt(0);
    }

    _historyController.add(_conversationHistory);
    _saveConversationHistory();
  }

  Future<MessageIntent> _analyzeIntent(String message, MessageType type) async {
    // Simple intent analysis - in production, this would use ML models
    final lowerMessage = message.toLowerCase();

    if (lowerMessage
        .contains(RegExp(r'\btranslate|translation|translate to|say in\b'))) {
      return MessageIntent.translation;
    } else if (lowerMessage
        .contains(RegExp(r'\bremind|reminder|schedule|appointment\b'))) {
      return MessageIntent.reminder;
    } else if (lowerMessage
        .contains(RegExp(r'\bweather|temperature|forecast\b'))) {
      return MessageIntent.weather;
    } else if (lowerMessage
        .contains(RegExp(r'\bsearch|find|look up|what is\b'))) {
      return MessageIntent.search;
    } else if (lowerMessage.contains(RegExp(r'\bhelp|assist|support\b'))) {
      return MessageIntent.help;
    } else if (lowerMessage
        .contains(RegExp(r'\bsettings|preferences|configure\b'))) {
      return MessageIntent.settings;
    } else {
      return MessageIntent.conversation;
    }
  }

  Map<String, dynamic> _buildContext() {
    return {
      'historyLength': _conversationHistory.length,
      'lastIntent': _conversationHistory.isNotEmpty
          ? _conversationHistory.last.metadata['intent']
          : null,
      'userPreferences': _userPreferences,
      'sessionDuration': DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(
              int.tryParse(_sessionContext['startTime']?.toString() ?? '0') ??
                  0))
          .inMinutes,
      'currentTime': DateTime.now().toIso8601String(),
    };
  }

  Future<AgenticResponse> _generateResponse(
    MessageIntent intent,
    Map<String, dynamic> context,
    ConversationMessage userMessage,
  ) async {
    switch (intent) {
      case MessageIntent.translation:
        return _generateTranslationResponse(userMessage, context);
      case MessageIntent.reminder:
        return _generateReminderResponse(userMessage, context);
      case MessageIntent.weather:
        return _generateWeatherResponse(userMessage, context);
      case MessageIntent.search:
        return _generateSearchResponse(userMessage, context);
      case MessageIntent.help:
        return _generateHelpResponse(userMessage, context);
      case MessageIntent.settings:
        return _generateSettingsResponse(userMessage, context);
      case MessageIntent.conversation:
        return _generateConversationResponse(userMessage, context);
    }
  }

  AgenticResponse _generateTranslationResponse(
    ConversationMessage userMessage,
    Map<String, dynamic> context,
  ) {
    return AgenticResponse(
      primaryResponse:
          "I'll help you with translation. Please specify the source and target languages.",
      responseType: ResponseType.translation,
      confidence: 0.9,
      suggestions: [
        AgenticSuggestion(
          id: 'translate_spanish',
          text: 'Translate to Spanish',
          action: AgenticAction.translate,
          priority: SuggestionPriority.high,
        ),
        AgenticSuggestion(
          id: 'translate_french',
          text: 'Translate to French',
          action: AgenticAction.translate,
          priority: SuggestionPriority.medium,
        ),
      ],
      actions: [AgenticAction.translate],
    );
  }

  AgenticResponse _generateReminderResponse(
    ConversationMessage userMessage,
    Map<String, dynamic> context,
  ) {
    return AgenticResponse(
      primaryResponse:
          "I'd be happy to help you set a reminder. When would you like to be reminded?",
      responseType: ResponseType.reminder,
      confidence: 0.85,
      suggestions: [
        AgenticSuggestion(
          id: 'remind_1hour',
          text: 'Remind me in 1 hour',
          action: AgenticAction.setReminder,
          priority: SuggestionPriority.high,
        ),
      ],
      actions: [AgenticAction.setReminder],
    );
  }

  AgenticResponse _generateWeatherResponse(
    ConversationMessage userMessage,
    Map<String, dynamic> context,
  ) {
    return AgenticResponse(
      primaryResponse:
          "I can help you get weather information. Which location are you interested in?",
      responseType: ResponseType.weather,
      confidence: 0.8,
      suggestions: [
        AgenticSuggestion(
          id: 'weather_current',
          text: 'Current location weather',
          action: AgenticAction.getWeather,
          priority: SuggestionPriority.high,
        ),
      ],
      actions: [AgenticAction.getWeather],
    );
  }

  AgenticResponse _generateSearchResponse(
    ConversationMessage userMessage,
    Map<String, dynamic> context,
  ) {
    return AgenticResponse(
      primaryResponse: "I'll search for that information for you.",
      responseType: ResponseType.search,
      confidence: 0.75,
      suggestions: [],
      actions: [AgenticAction.search],
    );
  }

  AgenticResponse _generateHelpResponse(
    ConversationMessage userMessage,
    Map<String, dynamic> context,
  ) {
    return AgenticResponse(
      primaryResponse:
          "I'm here to help! I can assist with translation, reminders, weather, and general questions. What would you like to do?",
      responseType: ResponseType.help,
      confidence: 0.95,
      suggestions: [
        AgenticSuggestion(
          id: 'help_translation',
          text: 'Help with translation',
          action: AgenticAction.showHelp,
          priority: SuggestionPriority.medium,
        ),
        AgenticSuggestion(
          id: 'help_reminders',
          text: 'Help with reminders',
          action: AgenticAction.showHelp,
          priority: SuggestionPriority.medium,
        ),
      ],
      actions: [AgenticAction.showHelp],
    );
  }

  AgenticResponse _generateSettingsResponse(
    ConversationMessage userMessage,
    Map<String, dynamic> context,
  ) {
    return AgenticResponse(
      primaryResponse:
          "I can help you adjust your preferences. What would you like to configure?",
      responseType: ResponseType.settings,
      confidence: 0.9,
      suggestions: [
        AgenticSuggestion(
          id: 'settings_language',
          text: 'Change language preferences',
          action: AgenticAction.openSettings,
          priority: SuggestionPriority.high,
        ),
      ],
      actions: [AgenticAction.openSettings],
    );
  }

  AgenticResponse _generateConversationResponse(
    ConversationMessage userMessage,
    Map<String, dynamic> context,
  ) {
    return AgenticResponse(
      primaryResponse: "I understand. How can I assist you further?",
      responseType: ResponseType.conversation,
      confidence: 0.6,
      suggestions: [
        AgenticSuggestion(
          id: 'ask_translation',
          text: 'Ask for translation help',
          action: AgenticAction.translate,
          priority: SuggestionPriority.low,
        ),
      ],
      actions: [],
    );
  }

  void _generateProactiveSuggestions(
      MessageIntent intent, Map<String, dynamic> context) {
    // Generate proactive suggestions based on usage patterns
    Timer(const Duration(seconds: 2), () {
      final suggestion = AgenticSuggestion(
        id: 'proactive_${DateTime.now().millisecondsSinceEpoch}',
        text: 'Would you like me to save this translation for quick access?',
        action: AgenticAction.saveTranslation,
        priority: SuggestionPriority.low,
      );

      _suggestionController.add(suggestion);
    });
  }

  void _startProactiveAssistance() {
    _proactiveTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_currentState == AgentState.idle && _conversationHistory.isEmpty) {
        final suggestion = AgenticSuggestion(
          id: 'proactive_help',
          text:
              'Hi! I can help with translations, reminders, and more. Just ask!',
          action: AgenticAction.showHelp,
          priority: SuggestionPriority.low,
        );

        _suggestionController.add(suggestion);
      }
    });
  }

  List<AgenticSuggestion> _getIdleSuggestions() {
    return [
      AgenticSuggestion(
        id: 'start_translation',
        text: 'Start a translation',
        action: AgenticAction.translate,
        priority: SuggestionPriority.medium,
      ),
      AgenticSuggestion(
        id: 'ask_question',
        text: 'Ask me anything',
        action: AgenticAction.startConversation,
        priority: SuggestionPriority.low,
      ),
    ];
  }

  List<AgenticSuggestion> _getListeningSuggestions() {
    return [
      AgenticSuggestion(
        id: 'stop_listening',
        text: 'Stop listening',
        action: AgenticAction.stopListening,
        priority: SuggestionPriority.high,
      ),
    ];
  }

  List<AgenticSuggestion> _getSpeakingSuggestions() {
    return [
      AgenticSuggestion(
        id: 'stop_speaking',
        text: 'Stop speaking',
        action: AgenticAction.stopSpeaking,
        priority: SuggestionPriority.high,
      ),
    ];
  }

  List<AgenticSuggestion> _getErrorSuggestions() {
    return [
      AgenticSuggestion(
        id: 'retry',
        text: 'Try again',
        action: AgenticAction.retry,
        priority: SuggestionPriority.high,
      ),
      AgenticSuggestion(
        id: 'get_help',
        text: 'Get help',
        action: AgenticAction.showHelp,
        priority: SuggestionPriority.medium,
      ),
    ];
  }

  List<AgenticSuggestion> _getContextBasedSuggestions() {
    final suggestions = <AgenticSuggestion>[];

    // Add suggestions based on conversation history
    if (_conversationHistory.isNotEmpty) {
      final lastMessage = _conversationHistory.last;
      if (lastMessage.type == MessageType.translation) {
        suggestions.add(
          AgenticSuggestion(
            id: 'repeat_translation',
            text: 'Repeat that translation',
            action: AgenticAction.repeat,
            priority: SuggestionPriority.medium,
          ),
        );
      }
    }

    return suggestions;
  }

  Future<void> _loadUserPreferences() async {
    // In production, load from local storage (Hive)
    _userPreferences.addAll({
      'preferredLanguage': 'en',
      'voiceSpeed': 1.0,
      'autoTranslate': false,
    });
  }

  Future<void> _saveUserPreferences() async {
    // In production, save to local storage (Hive)
    dev.log('User preferences saved', name: 'AgenticAI');
  }

  Future<void> _loadConversationHistory() async {
    // In production, load from local storage (Hive)
    _sessionContext['startTime'] =
        DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<void> _saveConversationHistory() async {
    // In production, save to local storage (Hive)
    // For now, just log
    dev.log(
        'Conversation history saved (${_conversationHistory.length} messages)',
        name: 'AgenticAI');
  }
}

// Data models

enum AgentState {
  idle,
  ready,
  listening,
  thinking,
  speaking,
  error,
}

enum MessageType {
  text,
  audio,
  image,
  translation,
}

enum MessageSender {
  user,
  agent,
}

enum MessageIntent {
  translation,
  reminder,
  weather,
  search,
  help,
  settings,
  conversation,
}

enum ResponseType {
  translation,
  reminder,
  weather,
  search,
  help,
  settings,
  conversation,
  error,
}

enum AgenticAction {
  translate,
  setReminder,
  getWeather,
  search,
  showHelp,
  openSettings,
  saveTranslation,
  startConversation,
  stopListening,
  stopSpeaking,
  retry,
  repeat,
}

enum SuggestionPriority {
  high,
  medium,
  low,
}

class ConversationMessage extends Equatable {
  final String id;
  final String content;
  final MessageType type;
  final MessageSender sender;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const ConversationMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.sender,
    required this.timestamp,
    required this.metadata,
  });

  @override
  List<Object?> get props => [id, content, type, sender, timestamp, metadata];

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'type': type.toString(),
        'sender': sender.toString(),
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };
}

class AgenticResponse extends Equatable {
  final String primaryResponse;
  final ResponseType responseType;
  final double confidence;
  final List<AgenticSuggestion> suggestions;
  final List<AgenticAction> actions;

  const AgenticResponse({
    required this.primaryResponse,
    required this.responseType,
    required this.confidence,
    required this.suggestions,
    required this.actions,
  });

  @override
  List<Object?> get props =>
      [primaryResponse, responseType, confidence, suggestions, actions];
}

class AgenticSuggestion extends Equatable {
  final String id;
  final String text;
  final AgenticAction action;
  final SuggestionPriority priority;
  final Map<String, dynamic>? metadata;

  const AgenticSuggestion({
    required this.id,
    required this.text,
    required this.action,
    required this.priority,
    this.metadata,
  });

  @override
  List<Object?> get props => [id, text, action, priority, metadata];

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'action': action.toString(),
        'priority': priority.toString(),
        'metadata': metadata,
      };
}
