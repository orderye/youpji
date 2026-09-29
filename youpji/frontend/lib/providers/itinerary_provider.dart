import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/itinerary_model.dart';
import '../models/feedback_model.dart';
import '../services/travel_service.dart';
import 'api_provider.dart';

class ItineraryState {
  final bool isLoading;
  final ItineraryPlanResponse? plan;
  final List<ItineraryPlanResponse> savedPlans;
  final String? errorMessage;
  final bool isTripActive;
  final String? feedbackId;

  ItineraryState({
    this.isLoading = false,
    this.plan,
    this.savedPlans = const [],
    this.errorMessage,
    this.isTripActive = false,
    this.feedbackId,
  });

  ItineraryState copyWith({
    bool? isLoading,
    ItineraryPlanResponse? plan,
    List<ItineraryPlanResponse>? savedPlans,
    String? errorMessage,
    bool? isTripActive,
    String? feedbackId,
  }) {
    return ItineraryState(
      isLoading: isLoading ?? this.isLoading,
      plan: plan ?? this.plan,
      savedPlans: savedPlans ?? this.savedPlans,
      errorMessage: errorMessage,
      isTripActive: isTripActive ?? this.isTripActive,
      feedbackId: feedbackId ?? this.feedbackId,
    );
  }
}

class ItineraryNotifier extends StateNotifier<ItineraryState> {
  static const String _prefSavedPlansKey = 'saved_local_itineraries_v1';
  final TravelService travelService;

  ItineraryNotifier({required this.travelService}) : super(ItineraryState()) {
    _loadLocalSavedPlans();
  }

  /// 本地加载缓存的行程列表
  Future<void> _loadLocalSavedPlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_prefSavedPlansKey);
      if (listJson != null && listJson.isNotEmpty) {
        final plans = listJson.map((str) {
          final map = jsonDecode(str) as Map<String, dynamic>;
          return ItineraryPlanResponse.fromJson(map);
        }).toList();
        state = state.copyWith(savedPlans: plans);
        if (state.plan == null && plans.isNotEmpty) {
          state = state.copyWith(plan: plans.first);
        }
      }
    } catch (_) {}
  }

  /// 保存行程到本地持久缓存
  Future<void> _persistPlanLocally(ItineraryPlanResponse newPlan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = List<ItineraryPlanResponse>.from(state.savedPlans);

      // 若已存在相同 ID 则替换，否则追加到头部
      final idx = currentList.indexWhere((p) => p.itineraryId == newPlan.itineraryId);
      if (idx >= 0) {
        currentList[idx] = newPlan;
      } else {
        currentList.insert(0, newPlan);
      }

      // 保留最近 10 条
      final trimmed = currentList.take(10).toList();
      final stringList = trimmed.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_prefSavedPlansKey, stringList);
      state = state.copyWith(savedPlans: trimmed);
    } catch (_) {}
  }

  /// 选择/切换当前活跃行程
  void selectPlan(ItineraryPlanResponse plan) {
    state = state.copyWith(
      plan: plan,
      errorMessage: null,
      isTripActive: false,
    );
  }

  /// 一键采用经典标杆路线
  Future<void> adoptPresetRoute(ItineraryPlanResponse preset) async {
    selectPlan(preset);
    await _persistPlanLocally(preset);
  }

  /// 生成行程
  Future<void> createPlan({
    required String origin,
    required String destination,
    required String startDate,
    String? endDate,
    int days = 2,
    int people = 2,
    int budget = 2000,
    String transport = 'self_drive',
    List<String> interests = const ['自然风光', '历史文化'],
    String? naturalInput,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await travelService.generatePlan(
        origin: origin,
        destination: destination,
        startDate: startDate,
        endDate: endDate,
        days: days,
        people: people,
        budget: budget,
        transport: transport,
        interests: interests,
        naturalInput: naturalInput,
        save: true,
      );
      state = state.copyWith(isLoading: false, plan: res);
      await _persistPlanLocally(res);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// 局部重排 (reorder_day)
  Future<void> reorderDay({
    required int dayIndex,
    required List<String> orderedAttractionIds,
  }) async {
    final itineraryId = state.plan?.itineraryId;
    if (itineraryId == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await travelService.reorderDay(
        itineraryId: itineraryId,
        dayIndex: dayIndex,
        orderedAttractionIds: orderedAttractionIds,
      );
      // 局部重排成功后刷新最新行程详情
      final updated = await travelService.getItineraryDetail(itineraryId);
      state = state.copyWith(isLoading: false, plan: updated);
      await _persistPlanLocally(updated);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// 根据 ID 从后端拉取行程
  Future<void> loadPlanById(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await travelService.getItineraryDetail(id);
      state = state.copyWith(isLoading: false, plan: res);
      await _persistPlanLocally(res);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// 删除行程
  Future<bool> deletePlan(String id) async {
    // 从后端删除
    await travelService.deleteItinerary(id);

    // 从本地缓存删除
    final currentList = List<ItineraryPlanResponse>.from(state.savedPlans)
      ..removeWhere((p) => p.itineraryId == id);

    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = currentList.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_prefSavedPlansKey, stringList);
    } catch (_) {}

    // 若当前活跃行程被删除，切换到下一个或置空
    ItineraryPlanResponse? nextPlan = state.plan;
    if (state.plan?.itineraryId == id) {
      nextPlan = currentList.isNotEmpty ? currentList.first : null;
    }

    state = state.copyWith(
      savedPlans: currentList,
      plan: nextPlan,
    );
    return true;
  }

  /// 开始旅程 (status: active)
  Future<void> startTrip() async {
    final itineraryId = state.plan?.itineraryId;
    if (itineraryId == null) return;

    try {
      final ok = await travelService.startItinerary(itineraryId);
      if (ok) {
        state = state.copyWith(isTripActive: true);
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// 提交反馈
  Future<void> submitFeedback(int rating, String comment, [List<String> images = const []]) async {
    final itineraryId = state.plan?.itineraryId;
    if (itineraryId == null) return;

    try {
      final fid = await travelService.submitFeedback(
        itineraryId,
        FeedbackRequest(rating: rating, comment: comment, images: images),
      );
      state = state.copyWith(feedbackId: fid);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

final itineraryProvider = StateNotifierProvider<ItineraryNotifier, ItineraryState>((ref) {
  final travelService = ref.watch(travelServiceProvider);
  return ItineraryNotifier(travelService: travelService);
});
