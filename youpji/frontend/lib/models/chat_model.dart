/// AI 智能问答契约模型 (对齐后端 crates/ai/src/chat.rs)

class ChatRequest {
  final String message;
  final String? sessionId;
  final Map<String, dynamic>? context;

  ChatRequest({
    required this.message,
    this.sessionId,
    this.context,
  });

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      if (sessionId != null) 'session_id': sessionId,
      if (context != null) 'context': context,
    };
  }
}

class ChatResponse {
  final String reply;
  final String? sessionId;
  final List<String> sources;
  final List<String> suggestions;

  ChatResponse({
    required this.reply,
    this.sessionId,
    required this.sources,
    required this.suggestions,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    final sList = (json['sources'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    final sugList = (json['suggestions'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    return ChatResponse(
      reply: json['reply']?.toString() ?? '',
      sessionId: json['session_id']?.toString(),
      sources: sList,
      suggestions: sugList,
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final List<String> sources;
  final List<String> suggestions;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.sources = const [],
    this.suggestions = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
