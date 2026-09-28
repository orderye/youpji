import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/chat_model.dart';

class AiService {
  final ApiClient client;

  AiService({required this.client});

  /// 发起 AI 对话 POST /api/v1/ai/chat
  Future<ChatResponse> sendMessage({
    required String message,
    String? sessionId,
    Map<String, dynamic>? context,
  }) async {
    final req = ChatRequest(
      message: message,
      sessionId: sessionId,
      context: context,
    );

    final resp = await client.dio.post(
      ApiConstants.aiChat,
      data: req.toJson(),
    );
    return ChatResponse.fromJson(resp.data as Map<String, dynamic>);
  }
}
