import 'itinerary_model.dart';

/// 局部重排请求与响应模型 (严格对齐 DESIGN.md §8.3 与后端 EditOp::ReorderDay)

class ReorderDayRequest {
  final String itineraryId;
  final int dayIndex;
  final List<String> orderedAttractionIds;

  ReorderDayRequest({
    required this.itineraryId,
    required this.dayIndex,
    required this.orderedAttractionIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'itinerary_id': itineraryId,
      'edit_op': {
        'type': 'reorder_day',
        'day_index': dayIndex,
        'ordered_attraction_ids': orderedAttractionIds,
      },
    };
  }
}

class ReplanResponse {
  final List<int> changedDays;
  final List<int> unchangedDays;
  final List<WarningItem> warnings;
  final Map<String, dynamic>? diff;

  ReplanResponse({
    required this.changedDays,
    required this.unchangedDays,
    required this.warnings,
    this.diff,
  });

  factory ReplanResponse.fromJson(Map<String, dynamic> json) {
    final changed = (json['changed_days'] as List<dynamic>? ?? []).map((e) => (e as num).toInt()).toList();
    final unchanged = (json['unchanged_days'] as List<dynamic>? ?? []).map((e) => (e as num).toInt()).toList();
    final warningsList = (json['warnings'] as List<dynamic>? ?? [])
        .map((e) => WarningItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return ReplanResponse(
      changedDays: changed,
      unchangedDays: unchanged,
      warnings: warningsList,
      diff: json['diff'] as Map<String, dynamic>?,
    );
  }
}
