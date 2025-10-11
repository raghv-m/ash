import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../config/app_config.dart';
import '../services/api_service.dart';

// Chat Message Model
class ChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final bool isVoice;
  final String? audioUrl;
  final bool isStreaming;
  final String? sessionId;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isVoice = false,
    this.audioUrl,
    this.isStreaming = false,
    this.sessionId,
  });

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    bool? isVoice,
    String? audioUrl,
    bool? isStreaming,
    String? sessionId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isVoice: isVoice ?? this.isVoice,
      audioUrl: audioUrl ?? this.audioUrl,
      isStreaming: isStreaming ?? this.isStreaming,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isVoice': isVoice,
      'audioUrl': audioUrl,
      'isStreaming': isStreaming,
      'sessionId': sessionId,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      role: json['role'] ?? '',
      content: json['content'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      isVoice: json['isVoice'] ?? false,
      audioUrl: json['audioUrl'],
      isStreaming: json['isStreaming'] ?? false,
      sessionId: json['sessionId'],
    );
  }
}

// Chat State
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isListening;
  final bool isStreaming;
  final String? error;
  final String? currentSessionId;
  final String? streamingMessageId;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isListening = false,
    this.isStreaming = false,
    this.error,
    this.currentSessionId,
    this.streamingMessageId,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isListening,
    bool? isStreaming,
    String? error,
    String? currentSessionId,
    String? streamingMessageId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isListening: isListening ?? this.isListening,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      streamingMessageId: streamingMessageId ?? this.streamingMessageId,
    );
  }
}

// Chat Notifier
class ChatNotifier extends StateNotifier<ChatState> {
  final ApiService _apiService;
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  WebSocketChannel? _webSocketChannel;
  StreamSubscription? _webSocketSubscription;

  ChatNotifier(this._apiService) : super(const ChatState()) {
    _initializeTTS();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _webSocketChannel?.sink.close();
    _webSocketSubscription?.cancel();
    super.dispose();
  }

  // Initialize TTS
  Future<void> _initializeTTS() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  // Add welcome message
  void _addWelcomeMessage() {
    final welcomeMessages = [
      "Hey there! I'm ASH, your AI scheduling sidekick. Let's book that meeting!",
      "Hello! I'm ASH, your intelligent scheduling assistant. How can I help you today?",
      "Hi! I'm ASH. Ready to help you schedule and manage your meetings efficiently.",
      "Welcome back! I'm ASH, your scheduling companion. What can I help you with today?"
    ];
    
    final welcomeMessage = welcomeMessages[
      DateTime.now().millisecondsSinceEpoch % welcomeMessages.length
    ];
    
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'assistant',
      content: welcomeMessage,
      timestamp: DateTime.now(),
    );
    
    state = state.copyWith(messages: [message]);
  }

  // Send text message
  Future<void> sendMessage(String text, String userId) async {
    if (text.trim().isEmpty) return;

    // Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
    );

    try {
      // Create session if needed
      String sessionId = state.currentSessionId ?? '';
      if (sessionId.isEmpty) {
        sessionId = await _createSession(userId);
        state = state.copyWith(currentSessionId: sessionId);
      }

      // Send message to backend
      final response = await _apiService.post(
        '${AppConfig.voiceEndpoint}/process',
        data: {
          'text': text.trim(),
          'sessionId': sessionId,
          'isStreaming': true,
        },
        token: await _getUserToken(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Add assistant response
        final assistantMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'assistant',
          content: data['reply'] ?? 'I apologize, but I couldn\'t process your request.',
          timestamp: DateTime.now(),
          sessionId: sessionId,
        );

        state = state.copyWith(
          messages: [...state.messages, assistantMessage],
          isLoading: false,
        );

        // Play TTS if enabled
        await _playTTS(data['reply']);
      } else {
        throw Exception('Failed to send message');
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send message: ${error.toString()}',
      );
    }
  }

  // Handle voice command
  Future<void> handleVoiceCommand(String userId) async {
    if (state.isListening) {
      await _stopListening();
      return;
    }

    final isInitialized = await _speechToText.initialize();
    if (!isInitialized) {
      state = state.copyWith(error: 'Speech recognition not available');
      return;
    }

    state = state.copyWith(isListening: true, error: null);

    await _speechToText.listen(
      onResult: (result) async {
        if (result.finalResult) {
          await _stopListening();
          if (result.recognizedWords.isNotEmpty) {
            await sendVoiceMessage(result.recognizedWords, userId);
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      // partialResults: true, // Deprecated, using SpeechListenOptions.partialResults instead
      localeId: 'en_US',
      onSoundLevelChange: (level) {
        // Handle sound level changes for visual feedback
      },
    );
  }

  // Send voice message
  Future<void> sendVoiceMessage(String text, String userId) async {
    // Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
      isVoice: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
    );

    try {
      // Create session if needed
      String sessionId = state.currentSessionId ?? '';
      if (sessionId.isEmpty) {
        sessionId = await _createSession(userId);
        state = state.copyWith(currentSessionId: sessionId);
      }

      // Send voice message to backend
      final response = await _apiService.post(
        '${AppConfig.voiceEndpoint}/process',
        data: {
          'text': text,
          'sessionId': sessionId,
          'isStreaming': true,
        },
        token: await _getUserToken(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Add assistant response
        final assistantMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'assistant',
          content: data['reply'] ?? 'I apologize, but I couldn\'t process your request.',
          timestamp: DateTime.now(),
          sessionId: sessionId,
          audioUrl: data['audioUrl'],
        );

        state = state.copyWith(
          messages: [...state.messages, assistantMessage],
          isLoading: false,
        );

        // Play TTS response
        if (data['audioUrl'] != null) {
          await _playAudioFromUrl(data['audioUrl']);
        } else {
          await _playTTS(data['reply']);
        }
      } else {
        throw Exception('Failed to process voice message');
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to process voice message: ${error.toString()}',
      );
    }
  }

  // Stop listening
  Future<void> _stopListening() async {
    await _speechToText.stop();
    state = state.copyWith(isListening: false);
  }

  // Create new session
  Future<String> _createSession(String userId) async {
    try {
      final response = await _apiService.post(
        '${AppConfig.voiceEndpoint}/session',
        token: await _getUserToken(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['sessionId'] ?? '';
      }
    } catch (error) {
      // Error creating session: $error
    }
    return '';
  }

  // Get user token
  Future<String?> _getUserToken() async {
    // This would need to be injected or accessed through a provider
    // For now, return null and handle it in the calling code
    return null;
  }

  // Play TTS
  Future<void> _playTTS(String text) async {
    try {
      await _flutterTts.speak(text);
    } catch (error) {
      // TTS error: $error
    }
  }

  // Play audio from URL
  Future<void> _playAudioFromUrl(String audioUrl) async {
    try {
      // This would need to be implemented with audioplayers package
      // For now, fall back to TTS
      await _playTTS('Audio response received');
    } catch (error) {
      // Audio playback error: $error
    }
  }

  // Load chat history
  Future<void> loadChatHistory(String userId) async {
    try {
      final response = await _apiService.get(
        '${AppConfig.voiceEndpoint}/history',
        token: await _getUserToken(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final chats = data['chats'] as List<dynamic>;
        
        if (chats.isNotEmpty) {
          final latestChat = chats.first;
          final messages = (latestChat['messages'] as List<dynamic>)
              .map((msg) => ChatMessage.fromJson(msg))
              .toList();
          
          state = state.copyWith(
            messages: messages,
            currentSessionId: latestChat['sessionId'],
          );
        }
      }
    } catch (error) {
      // Error loading chat history: $error
    }
  }

  // Clear chat
  void clearChat() {
    state = state.copyWith(
      messages: [],
      currentSessionId: null,
      error: null,
    );
    _addWelcomeMessage();
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Set listening state
  void setListening(bool listening) {
    state = state.copyWith(isListening: listening);
  }
}

// Providers
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return ChatNotifier(apiService);
});

// Convenience providers
final messagesProvider = Provider<List<ChatMessage>>((ref) {
  return ref.watch(chatProvider).messages;
});

final isLoadingProvider = Provider<bool>((ref) {
  return ref.watch(chatProvider).isLoading;
});

final isListeningProvider = Provider<bool>((ref) {
  return ref.watch(chatProvider).isListening;
});

final chatErrorProvider = Provider<String?>((ref) {
  return ref.watch(chatProvider).error;
});
