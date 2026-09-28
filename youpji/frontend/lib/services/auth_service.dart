import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';

class AuthService {
  final ApiClient client;

  AuthService({required this.client});

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final resp = await client.dio.post(
      ApiConstants.authLogin,
      data: {'phone': phone, 'password': password},
    );
    final data = resp.data as Map<String, dynamic>;
    if (data['token'] != null) {
      await client.tokenStorage.saveToken(
        data['token'].toString(),
        data['user_id']?.toString() ?? '',
      );
    }
    return data;
  }

  /// 账号安全注销 DELETE /api/v1/auth/me?confirm=DELETE
  Future<bool> deleteAccount({String confirm = 'DELETE'}) async {
    final resp = await client.dio.delete(
      ApiConstants.authMe,
      queryParameters: {'confirm': confirm},
    );
    await client.tokenStorage.clear();
    return resp.data['ok'] == true;
  }
}
