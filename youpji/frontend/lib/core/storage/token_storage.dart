import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _keyToken = 'jwt_token';
  static const _keyUserId = 'user_id';
  static const _keySessionId = 'ai_chat_session_id';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> saveToken(String token, String userId) async {
    await _secureStorage.write(key: _keyToken, value: token);
    await _secureStorage.write(key: _keyUserId, value: userId);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: _keyToken);
  }

  Future<String?> getUserId() async {
    return await _secureStorage.read(key: _keyUserId);
  }

  Future<void> clear() async {
    await _secureStorage.deleteAll();
  }

  // AI 会话 session_id 存储
  Future<void> saveChatSessionId(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySessionId, sessionId);
  }

  Future<String?> getChatSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySessionId);
  }
}
