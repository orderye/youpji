import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../services/travel_service.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final travelServiceProvider = Provider<TravelService>((ref) {
  final client = ref.watch(apiClientProvider);
  return TravelService(client: client);
});

final aiServiceProvider = Provider<AiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AiService(client: client);
});

final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthService(client: client);
});
