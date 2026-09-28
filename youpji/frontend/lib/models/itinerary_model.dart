/// 行程相关数据契约模型 (对齐 DESIGN.md §5 / §8)

class WarningItem {
  final String code;
  final String message;
  final String? ref;

  WarningItem({required this.code, required this.message, this.ref});

  factory WarningItem.fromJson(Map<String, dynamic> json) {
    return WarningItem(
      code: json['code']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      ref: json['ref']?.toString(),
    );
  }
}

class ItineraryItem {
  final String itemType; // attraction | meal | hotel | transit | free
  final String? startTime;
  final String? endTime;
  final String title;
  final String? location;
  final double? longitude;
  final double? latitude;
  final String? refId;
  final double? distanceKm;
  final int? durationMin;
  final int cost;
  final String? reason;
  final String? notice;
  final String? verificationStatus; // verified | pending | unverified

  ItineraryItem({
    required this.itemType,
    this.startTime,
    this.endTime,
    required this.title,
    this.location,
    this.longitude,
    this.latitude,
    this.refId,
    this.distanceKm,
    this.durationMin,
    required this.cost,
    this.reason,
    this.notice,
    this.verificationStatus,
  });

  factory ItineraryItem.fromJson(Map<String, dynamic> json) {
    return ItineraryItem(
      itemType: json['item_type']?.toString() ?? 'attraction',
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      title: json['title']?.toString() ?? '',
      location: json['location']?.toString(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      refId: json['ref_id']?.toString(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      durationMin: (json['duration_min'] as num?)?.toInt(),
      cost: (json['cost'] as num?)?.toInt() ?? 0,
      reason: json['reason']?.toString(),
      notice: json['notice']?.toString(),
      verificationStatus: json['verification_status']?.toString() ?? 'verified',
    );
  }
}

class ItineraryDay {
  final int dayIndex;
  final String? date;
  final String? title;
  final List<ItineraryItem> items;

  ItineraryDay({
    required this.dayIndex,
    this.date,
    this.title,
    required this.items,
  });

  factory ItineraryDay.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return ItineraryDay(
      dayIndex: (json['day_index'] as num?)?.toInt() ?? 0,
      date: json['date']?.toString(),
      title: json['title']?.toString(),
      items: list.map((e) => ItineraryItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class BudgetBreakdown {
  final int limit;
  final int transport;
  final int lodging;
  final int tickets;
  final int food;
  final int parking;
  final int other;
  final int reserve;
  final int total;

  BudgetBreakdown({
    required this.limit,
    required this.transport,
    required this.lodging,
    required this.tickets,
    required this.food,
    required this.parking,
    required this.other,
    required this.reserve,
    required this.total,
  });

  factory BudgetBreakdown.fromJson(Map<String, dynamic> json) {
    return BudgetBreakdown(
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      transport: (json['transport'] as num?)?.toInt() ?? 0,
      lodging: (json['lodging'] as num?)?.toInt() ?? 0,
      tickets: (json['tickets'] as num?)?.toInt() ?? 0,
      food: (json['food'] as num?)?.toInt() ?? 0,
      parking: (json['parking'] as num?)?.toInt() ?? 0,
      other: (json['other'] as num?)?.toInt() ?? 0,
      reserve: (json['reserve'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlanSummary {
  final String title;
  final String origin;
  final String destination;
  final int days;
  final int people;
  final String mode;
  final double totalDistanceKm;
  final double driveHours;
  final int ticketCost;

  PlanSummary({
    required this.title,
    required this.origin,
    required this.destination,
    required this.days,
    required this.people,
    required this.mode,
    required this.totalDistanceKm,
    required this.driveHours,
    required this.ticketCost,
  });

  factory PlanSummary.fromJson(Map<String, dynamic> json) {
    return PlanSummary(
      title: json['title']?.toString() ?? '',
      origin: json['origin']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      days: (json['days'] as num?)?.toInt() ?? 1,
      people: (json['people'] as num?)?.toInt() ?? 1,
      mode: json['mode']?.toString() ?? 'standard',
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble() ?? 0.0,
      driveHours: (json['drive_hours'] as num?)?.toDouble() ?? 0.0,
      ticketCost: (json['ticket_cost'] as num?)?.toInt() ?? 0,
    );
  }
}

class ItineraryPlanResponse {
  final String? itineraryId;
  final PlanSummary summary;
  final List<ItineraryDay> days;
  final BudgetBreakdown budget;
  final List<WarningItem> warnings;
  final String algoVersion;

  ItineraryPlanResponse({
    this.itineraryId,
    required this.summary,
    required this.days,
    required this.budget,
    required this.warnings,
    required this.algoVersion,
  });

  factory ItineraryPlanResponse.fromJson(Map<String, dynamic> json) {
    final daysList = json['days'] as List<dynamic>? ?? [];
    final warningsList = json['warnings'] as List<dynamic>? ?? [];
    return ItineraryPlanResponse(
      itineraryId: json['itinerary_id']?.toString(),
      summary: PlanSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
      days: daysList.map((e) => ItineraryDay.fromJson(e as Map<String, dynamic>)).toList(),
      budget: BudgetBreakdown.fromJson(json['budget'] as Map<String, dynamic>? ?? {}),
      warnings: warningsList.map((e) => WarningItem.fromJson(e as Map<String, dynamic>)).toList(),
      algoVersion: json['algo_version']?.toString() ?? '',
    );
  }
}
