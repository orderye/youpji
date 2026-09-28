import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../services/ai_service.dart';
import '../core/storage/token_storage.dart';
import 'api_provider.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isSending;
  final String? sessionId;

  ChatState({
    this.messages = const [],
    this.isSending = false,
    this.sessionId,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    String? sessionId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final AiService aiService;
  final TokenStorage tokenStorage;

  ChatNotifier({required this.aiService, required this.tokenStorage})
      : super(ChatState(messages: [
          ChatMessage(
            text: '您好！我是游迹 AI 旅游助手。请告诉我您想去贵州哪里游玩、玩几天、预算多少，我来为您规划！',
            isUser: false,
            suggestions: ['贵阳到安顺两日游', '黄果树瀑布最佳游览时间', '贵阳美食推荐'],
          )
        ])) {
    _initSession();
  }

  Future<void> _initSession() async {
    final sid = await tokenStorage.getChatSessionId();
    if (sid != null) {
      state = state.copyWith(sessionId: sid);
    }
  }

  Future<void> sendMessage(String text, [Map<String, dynamic>? context]) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMsg = ChatMessage(text: trimmed, isUser: true);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isSending: true,
    );

    try {
      final res = await aiService.sendMessage(
        message: trimmed,
        sessionId: state.sessionId,
        context: context,
      );

      if (res.sessionId != null && res.sessionId != state.sessionId) {
        state = state.copyWith(sessionId: res.sessionId);
        await tokenStorage.saveChatSessionId(res.sessionId!);
      }

      final botMsg = ChatMessage(
        text: res.reply,
        isUser: false,
        sources: res.sources,
        suggestions: res.suggestions,
      );

      state = state.copyWith(
        messages: [...state.messages, botMsg],
        isSending: false,
      );
    } catch (e) {
      final errorMsg = ChatMessage(
        text: '连接助手失败，请稍后重试: $e',
        isUser: false,
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isSending: false,
      );
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  final client = ref.watch(apiClientProvider);
  return ChatNotifier(aiService: aiService, tokenStorage: client.tokenStorage);
});
