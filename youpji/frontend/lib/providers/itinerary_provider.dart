import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/itinerary_model.dart';
import '../models/feedback_model.dart';
import '../services/travel_service.dart';
import 'api_provider.dart';

class ItineraryState {
  final bool isLoading;
  final ItineraryPlanResponse? plan;
  final String? errorMessage;
  final bool isTripActive;
  final String? feedbackId;

  ItineraryState({
    this.isLoading = false,
    this.plan,
    this.errorMessage,
    this.isTripActive = false,
    this.feedbackId,
  });

  ItineraryState copyWith({
    bool? isLoading,
    ItineraryPlanResponse? plan,
    String? errorMessage,
    bool? isTripActive,
    String? feedbackId,
  }) {
    return ItineraryState(
      isLoading: isLoading ?? this.isLoading,
      plan: plan ?? this.plan,
      errorMessage: errorMessage,
      isTripActive: isTripActive ?? this.isTripActive,
      feedbackId: feedbackId ?? this.feedbackId,
    );
  }
}

class ItineraryNotifier extends StateNotifier<ItineraryState> {
  final TravelService travelService;

  ItineraryNotifier({required this.travelService}) : super(ItineraryState());

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
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
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
