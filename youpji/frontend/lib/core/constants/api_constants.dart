/// 游迹 API 路由与契约常量
class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8081',
  );

  // 规划与重规划
  static const String travelParse = '/api/v1/travel/parse';
  static const String travelPlan = '/api/v1/travel/plan';
  static const String travelReplan = '/api/v1/travel/replan';

  // 行程列表与管理
  static const String itineraries = '/api/v1/itineraries';
  static String itineraryDetail(String id) => '/api/v1/itineraries/$id';
  static String itineraryStart(String id) => '/api/v1/itineraries/$id/start';
  static String itineraryFeedback(String id) => '/api/v1/itineraries/$id/feedback';

  // 景区数据与周边检索
  static const String attractions = '/api/v1/attractions';
  static String attractionDetail(String id) => '/api/v1/attractions/$id';

  // AI 会话
  static const String aiChat = '/api/v1/ai/chat';

  // 认证与用户
  static const String authLogin = '/api/v1/auth/login';
  static const String authRegister = '/api/v1/auth/register';
  static const String authMe = '/api/v1/auth/me';
}
