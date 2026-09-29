import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/itinerary_model.dart';
import '../models/replan_model.dart';
import '../models/feedback_model.dart';
import '../models/attraction_model.dart';

class TravelService {
  final ApiClient client;

  TravelService({required this.client});

  /// 发起规划请求 POST /api/v1/travel/plan
  Future<ItineraryPlanResponse> generatePlan({
    required String origin,
    required String destination,
    required String startDate,
    String? endDate,
    int days = 2,
    int people = 2,
    int budget = 2000,
    String transport = 'self_drive',
    List<String> interests = const ['自然风光', '历史文化'],
    String intensity = 'moderate',
    String mode = 'standard',
    String lodgingTier = 'comfort',
    String? naturalInput,
    bool save = true,
  }) async {
    final body = {
      'origin': origin,
      'destination': destination,
      'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      'days': days,
      'people': people,
      'budget': budget,
      'transport': transport,
      'interests': interests,
      'avoid': [],
      'intensity': intensity,
      'mode': mode,
      'lodging_tier': lodgingTier,
      if (naturalInput != null) 'natural_input': naturalInput,
      'save': save,
    };

    final resp = await client.dio.post(
      ApiConstants.travelPlan,
      data: body,
    );
    return ItineraryPlanResponse.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 局部重排 POST /api/v1/travel/replan (reorder_day)
  Future<ReplanResponse> reorderDay({
    required String itineraryId,
    required int dayIndex,
    required List<String> orderedAttractionIds,
  }) async {
    final req = ReorderDayRequest(
      itineraryId: itineraryId,
      dayIndex: dayIndex,
      orderedAttractionIds: orderedAttractionIds,
    );

    final resp = await client.dio.post(
      ApiConstants.travelReplan,
      data: req.toJson(),
    );
    return ReplanResponse.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 查询行程详情 GET /api/v1/itineraries/:id
  Future<ItineraryPlanResponse> getItineraryDetail(String id) async {
    final resp = await client.dio.get(ApiConstants.itineraryDetail(id));
    return ItineraryPlanResponse.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 获取当前登录用户的行程列表 GET /api/v1/itineraries
  Future<List<Map<String, dynamic>>> getMyItineraries() async {
    try {
      final resp = await client.dio.get(ApiConstants.itineraries);
      final list = resp.data as List<dynamic>? ?? [];
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  /// 删除行程 DELETE /api/v1/itineraries/:id
  Future<bool> deleteItinerary(String id) async {
    try {
      final resp = await client.dio.delete(ApiConstants.itineraryDetail(id));
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// 启动行程 POST /api/v1/itineraries/:id/start
  Future<bool> startItinerary(String id) async {
    final resp = await client.dio.post(ApiConstants.itineraryStart(id));
    return resp.data['ok'] == true;
  }

  /// 提交反馈 POST /api/v1/itineraries/:id/feedback
  Future<String?> submitFeedback(String id, FeedbackRequest feedback) async {
    final resp = await client.dio.post(
      ApiConstants.itineraryFeedback(id),
      data: feedback.toJson(),
    );
    return resp.data['feedback_id']?.toString();
  }

  /// 查询景区列表（支持经纬度距离排序与周边筛选） GET /api/v1/attractions
  Future<List<AttractionItem>> getAttractions({
    double? lng,
    double? lat,
    String? sortBy,
    String? city,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      if (lng != null) 'lng': lng,
      if (lat != null) 'lat': lat,
      if (sortBy != null) 'sort_by': sortBy,
      if (city != null) 'city': city,
    };

    final resp = await client.dio.get(
      ApiConstants.attractions,
      queryParameters: queryParams,
    );
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((e) => AttractionItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
