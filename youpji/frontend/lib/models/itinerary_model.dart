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

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (ref != null) 'ref': ref,
      };
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

  Map<String, dynamic> toJson() => {
        'item_type': itemType,
        if (startTime != null) 'start_time': startTime,
        if (endTime != null) 'end_time': endTime,
        'title': title,
        if (location != null) 'location': location,
        if (longitude != null) 'longitude': longitude,
        if (latitude != null) 'latitude': latitude,
        if (refId != null) 'ref_id': refId,
        if (distanceKm != null) 'distance_km': distanceKm,
        if (durationMin != null) 'duration_min': durationMin,
        'cost': cost,
        if (reason != null) 'reason': reason,
        if (notice != null) 'notice': notice,
        if (verificationStatus != null) 'verification_status': verificationStatus,
      };
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

  Map<String, dynamic> toJson() => {
        'day_index': dayIndex,
        if (date != null) 'date': date,
        if (title != null) 'title': title,
        'items': items.map((e) => e.toJson()).toList(),
      };
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

  Map<String, dynamic> toJson() => {
        'limit': limit,
        'transport': transport,
        'lodging': lodging,
        'tickets': tickets,
        'food': food,
        'parking': parking,
        'other': other,
        'reserve': reserve,
        'total': total,
      };
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

  Map<String, dynamic> toJson() => {
        'title': title,
        'origin': origin,
        'destination': destination,
        'days': days,
        'people': people,
        'mode': mode,
        'total_distance_km': totalDistanceKm,
        'drive_hours': driveHours,
        'ticket_cost': ticketCost,
      };
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

  Map<String, dynamic> toJson() => {
        if (itineraryId != null) 'itinerary_id': itineraryId,
        'summary': summary.toJson(),
        'days': days.map((e) => e.toJson()).toList(),
        'budget': budget.toJson(),
        'warnings': warnings.map((e) => e.toJson()).toList(),
        'algo_version': algoVersion,
      };
}

/// 官方精选标杆行程库（与 DESIGN.md 真实已核验事实严格对齐）
class CuratedBenchmarkRoutes {
  /// 路线 1：贵阳 → 安顺（黄果树/龙宫/天龙屯堡）2日自驾标杆（铁律 2）
  static final ItineraryPlanResponse anshunBenchmark = ItineraryPlanResponse(
    itineraryId: 'curated-anshun-2day-001',
    summary: PlanSummary(
      title: '贵阳 → 安顺（黄果树/龙宫/天龙屯堡）2日经典自驾',
      origin: '贵阳',
      destination: '安顺',
      days: 2,
      people: 2,
      mode: 'standard',
      totalDistanceKm: 285.0,
      driveHours: 4.5,
      ticketCost: 880,
    ),
    budget: BudgetBreakdown(
      limit: 2000,
      transport: 280,
      lodging: 360,
      tickets: 880,
      food: 330,
      parking: 30,
      other: 0,
      reserve: 120,
      total: 1850,
    ),
    warnings: [
      WarningItem(
        code: 'W_TICKET_ADVANCE',
        message: '黄果树景区实行全网实名制分时预约，请至少提前 1 天在官方公众号预约门票与观光车。',
      ),
      WarningItem(
        code: 'W_WEATHER_WATERPROOF',
        message: '黄果树大瀑布水帘洞及天星桥景区水汽丰沛，建议备好雨衣及防滑鞋。',
      ),
    ],
    algoVersion: 'v0.1.0-rules',
    days: [
      ItineraryDay(
        dayIndex: 1,
        date: '2026-10-01',
        title: 'Day 1: 探访大明屯堡活化石与喀斯特地下龙宫',
        items: [
          ItineraryItem(
            itemType: 'transit',
            startTime: '08:30',
            endTime: '09:40',
            title: '贵阳市区出发自驾前往天龙屯堡',
            distanceKm: 72.0,
            durationMin: 70,
            cost: 0,
            notice: '经由沪昆高速，平坝下高速即达',
          ),
          ItineraryItem(
            itemType: 'attraction',
            startTime: '09:40',
            endTime: '11:40',
            title: '平坝天龙屯堡古镇',
            location: '安顺市平坝区天龙镇',
            cost: 90,
            reason: '明初朱元璋调北征南屯军后裔聚居地，石板房筑堡，保存完整的明代服饰与地戏非遗演艺。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'meal',
            startTime: '12:00',
            endTime: '13:00',
            title: '屯堡家常风味午餐（平坝灰鹅、糟辣肉片）',
            location: '天龙镇食坊',
            cost: 90,
            reason: '安顺地道屯堡军屯菜，肉质鲜嫩，酸辣开胃。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'transit',
            startTime: '13:00',
            endTime: '13:45',
            title: '自驾前往安顺龙宫景区',
            distanceKm: 38.0,
            durationMin: 45,
            cost: 0,
          ),
          ItineraryItem(
            itemType: 'attraction',
            startTime: '13:45',
            endTime: '16:45',
            title: '龙宫风景名胜区 (5A)',
            location: '安顺市西秀区龙宫镇',
            cost: 260,
            reason: '地下溶洞暗河泛舟，集溶洞、瀑布、峡谷、峰林与绝美喀斯特于一体。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'hotel',
            startTime: '17:30',
            endTime: '18:30',
            title: '入住安顺市区品质酒店 / 民宿',
            location: '安顺市西秀区',
            cost: 360,
            reason: '靠近儒林路文化街区，方便品尝安顺夜市名小吃。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'meal',
            startTime: '18:40',
            endTime: '20:00',
            title: '安顺儒林路风味晚餐（破酥包、裹卷、小锅凉粉）',
            location: '安顺老城街区',
            cost: 80,
            reason: '安顺被誉为贵州小吃之都，地道老街夜宵体验。',
            verificationStatus: 'verified',
          ),
        ],
      ),
      ItineraryDay(
        dayIndex: 2,
        date: '2026-10-02',
        title: 'Day 2: 亚洲第一大瀑布深度巡礼',
        items: [
          ItineraryItem(
            itemType: 'transit',
            startTime: '08:00',
            endTime: '08:45',
            title: '酒店出发自驾前往黄果树景区',
            distanceKm: 45.0,
            durationMin: 45,
            cost: 0,
          ),
          ItineraryItem(
            itemType: 'attraction',
            startTime: '08:45',
            endTime: '13:00',
            title: '黄果树风景名胜区 · 大瀑布与天星桥 (5A)',
            location: '安顺市关岭布依族苗族自治县',
            cost: 530,
            reason: '亚洲第一大瀑布，穿行水帘洞近距离感受飞瀑轰鸣，探索天星桥奇石秀水。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'meal',
            startTime: '13:00',
            endTime: '14:00',
            title: '布依风味午餐（酸汤鱼、折耳根拌木耳）',
            location: '黄果树新城食街',
            cost: 160,
            reason: '地道红酸汤现煮野生江团，酸辣爽口解乏。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'attraction',
            startTime: '14:15',
            endTime: '16:00',
            title: '黄果树 · 陡坡塘瀑布',
            location: '黄果树景区内',
            cost: 0,
            reason: '86版《西游记》片尾曲师徒四人牵马走过的壮丽瀑顶实景。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'transit',
            startTime: '16:30',
            endTime: '18:30',
            title: '启程经沪昆高速返回贵阳市区',
            distanceKm: 130.0,
            durationMin: 120,
            cost: 0,
            notice: '全程高速顺畅，结束愉悦的两天安顺之行',
          ),
        ],
      ),
    ],
  );

  /// 路线 2：贵阳市区人文生态 1 日经典游
  static final ItineraryPlanResponse guiyangOneDay = ItineraryPlanResponse(
    itineraryId: 'curated-guiyang-1day-002',
    summary: PlanSummary(
      title: '贵阳市区人文生态 1 日经典游',
      origin: '贵阳',
      destination: '贵阳',
      days: 1,
      people: 2,
      mode: 'standard',
      totalDistanceKm: 42.0,
      driveHours: 1.5,
      ticketCost: 70,
    ),
    budget: BudgetBreakdown(
      limit: 600,
      transport: 50,
      lodging: 0,
      tickets: 70,
      food: 180,
      parking: 20,
      other: 0,
      reserve: 60,
      total: 380,
    ),
    warnings: [
      WarningItem(
        code: 'W_MONKEY_NOTICE',
        message: '黔灵山公园内野生猕猴活泼，游览时请勿手提塑料袋或主动逗弄猴群。',
      ),
    ],
    algoVersion: 'v0.1.0-rules',
    days: [
      ItineraryDay(
        dayIndex: 1,
        date: '2026-10-01',
        title: 'Day 1: 黔灵灵山、南明甲秀与青岩古韵',
        items: [
          ItineraryItem(
            itemType: 'attraction',
            startTime: '08:30',
            endTime: '11:00',
            title: '黔灵山公园 (4A)',
            location: '贵阳市云岩区枣山路',
            cost: 10,
            reason: '黔南第一山，弘福寺晨钟、灵猴嬉戏与麒麟洞历史人文。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'attraction',
            startTime: '11:30',
            endTime: '13:00',
            title: '甲秀楼与翠微园 (3A)',
            location: '贵阳市南明区翠微巷',
            cost: 0,
            reason: '明代古楼雄踞南明河鳌矶石上，贵阳城池历史地标，浮玉桥长廊。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'meal',
            startTime: '13:00',
            endTime: '14:00',
            title: '贵阳老字号丝娃娃与恋爱豆腐果午餐',
            location: '南明河畔特色餐馆',
            cost: 80,
            reason: '薄饼卷十数种鲜蔬蘸折耳根脆哨酸辣汁，经典必吃。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'transit',
            startTime: '14:00',
            endTime: '14:50',
            title: '自驾前往花溪青岩古镇',
            distanceKm: 32.0,
            durationMin: 50,
            cost: 0,
          ),
          ItineraryItem(
            itemType: 'attraction',
            startTime: '14:50',
            endTime: '17:30',
            title: '青岩古镇 (5A)',
            location: '贵阳市花溪区青岩镇',
            cost: 60,
            reason: '贵州四大古镇之一，石板街巷交错，赵以炯状元故居，背街石墙摄影胜地。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'meal',
            startTime: '17:30',
            endTime: '18:40',
            title: '青岩特色晚餐（状元卤猪蹄、糕粑稀饭、玫瑰冰粉）',
            location: '青岩古镇美食街',
            cost: 100,
            reason: '卤香软糯的状元蹄配青岩双花醋，传统工艺传承百年。',
            verificationStatus: 'verified',
          ),
        ],
      ),
    ],
  );

  /// 路线 3：荔波大小七孔 + 西江千户苗寨 3 日山水民俗游
  static final ItineraryPlanResponse liboXijiangThreeDay = ItineraryPlanResponse(
    itineraryId: 'curated-libo-xijiang-3day-003',
    summary: PlanSummary(
      title: '荔波大小七孔 + 西江千户苗寨 3 日山水民俗游',
      origin: '贵阳',
      destination: '黔东南/黔南',
      days: 3,
      people: 2,
      mode: 'standard',
      totalDistanceKm: 580.0,
      driveHours: 7.5,
      ticketCost: 1100,
    ),
    budget: BudgetBreakdown(
      limit: 3000,
      transport: 480,
      lodging: 760,
      tickets: 1100,
      food: 420,
      parking: 40,
      other: 0,
      reserve: 0,
      total: 2800,
    ),
    warnings: [
      WarningItem(
        code: 'W_SCENIC_SHUTTLE',
        message: '小七孔景区狭长（12公里），建议东进西出或西进东出，乘坐观光车更节省体力。',
      ),
      WarningItem(
        code: 'W_LODGING_ADVANCE',
        message: '西江千户苗寨半山吊脚楼景观房旺季紧张，建议尽早预订。',
      ),
    ],
    algoVersion: 'v0.1.0-rules',
    days: [
      ItineraryDay(
        dayIndex: 1,
        date: '2026-10-01',
        title: 'Day 1: 奔赴地球腰带上的绿宝石——荔波小七孔',
        items: [
          ItineraryItem(
            itemType: 'transit',
            startTime: '08:00',
            endTime: '11:00',
            title: '贵阳自驾经贵荔高速前往荔波小七孔',
            distanceKm: 250.0,
            durationMin: 180,
            cost: 0,
          ),
          ItineraryItem(
            itemType: 'attraction',
            startTime: '11:30',
            endTime: '17:00',
            title: '荔波小七孔景区 (5A)',
            location: '黔南州荔波县',
            cost: 440,
            reason: '卧龙潭蒂芙尼蓝、六十八级跌水瀑布、拉雅瀑布与水上森林仙境。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'hotel',
            startTime: '17:30',
            endTime: '18:30',
            title: '入住荔波古镇精品客栈',
            location: '荔波古镇',
            cost: 380,
            reason: '环境幽静，夜晚漫步古镇尝樟江烤鱼。',
            verificationStatus: 'verified',
          ),
        ],
      ),
      ItineraryDay(
        dayIndex: 2,
        date: '2026-10-02',
        title: 'Day 2: 探秘大七孔恐怖峡，入驻西江千户苗寨',
        items: [
          ItineraryItem(
            itemType: 'attraction',
            startTime: '09:00',
            endTime: '11:30',
            title: '荔波大七孔景区 (天生桥与恐怖峡)',
            location: '黔南州荔波县',
            cost: 160,
            reason: '喀斯特天生桥天工造物，原始森林与险峻峡谷。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'transit',
            startTime: '12:30',
            endTime: '15:30',
            title: '自驾前往雷山西江千户苗寨',
            distanceKm: 190.0,
            durationMin: 180,
            cost: 0,
          ),
          ItineraryItem(
            itemType: 'attraction',
            startTime: '16:00',
            endTime: '21:30',
            title: '西江千户苗寨 (5A)',
            location: '黔东南州雷山县西江镇',
            cost: 500,
            reason: '全球最大苗族聚居村寨，万家灯火观景台夜景，芦笙场原生态歌舞。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'hotel',
            startTime: '21:30',
            endTime: '22:30',
            title: '入住苗寨半山观景吊脚楼客栈',
            location: '西江苗寨内',
            cost: 380,
            reason: '凭窗远眺万家灯火，夜听苗岭微风。',
            verificationStatus: 'verified',
          ),
        ],
      ),
      ItineraryDay(
        dayIndex: 3,
        date: '2026-10-03',
        title: 'Day 3: 体验苗族非遗银饰刺绣，返程贵阳',
        items: [
          ItineraryItem(
            itemType: 'attraction',
            startTime: '09:00',
            endTime: '12:00',
            title: '西江嘎歌古巷非遗文化体验',
            location: '西江苗寨内',
            cost: 0,
            reason: '近距离体验国家级非物质文化遗产苗族银饰锻制技艺与蜡染刺绣。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'transit',
            startTime: '13:00',
            endTime: '16:00',
            title: '返程贵阳',
            distanceKm: 200.0,
            durationMin: 180,
            cost: 0,
          ),
        ],
      ),
    ],
  );

  /// 路线 4：遵义会议会址 + 赤水丹霞 2 日红色生态游
  static final ItineraryPlanResponse zunyiChishuiTwoDay = ItineraryPlanResponse(
    itineraryId: 'curated-zunyi-chishui-2day-004',
    summary: PlanSummary(
      title: '遵义会议会址 + 赤水丹霞 2 日红色生态游',
      origin: '贵阳',
      destination: '遵义/赤水',
      days: 2,
      people: 2,
      mode: 'standard',
      totalDistanceKm: 460.0,
      driveHours: 6.0,
      ticketCost: 480,
    ),
    budget: BudgetBreakdown(
      limit: 2000,
      transport: 380,
      lodging: 340,
      tickets: 480,
      food: 320,
      parking: 30,
      other: 0,
      reserve: 50,
      total: 1600,
    ),
    warnings: [
      WarningItem(
        code: 'W_RED_CULTURE_RESPECT',
        message: '遵义会议会址为全国重点文物保护单位，请在馆内保持安静庄重。',
      ),
    ],
    algoVersion: 'v0.1.0-rules',
    days: [
      ItineraryDay(
        dayIndex: 1,
        date: '2026-10-01',
        title: 'Day 1: 重温伟大转折——遵义会议会址巡礼',
        items: [
          ItineraryItem(
            itemType: 'transit',
            startTime: '08:30',
            endTime: '10:30',
            title: '贵阳自驾沿兰海高速前往遵义红花岗区',
            distanceKm: 140.0,
            durationMin: 120,
            cost: 0,
          ),
          ItineraryItem(
            itemType: 'attraction',
            startTime: '10:30',
            endTime: '13:00',
            title: '遵义会议会址与纪念馆 (5A)',
            location: '遵义市红花岗区子尹路',
            cost: 0,
            reason: '伟大转折之地，中西合璧二层主楼，历史陈列馆珍藏红军长征珍贵文物。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'meal',
            startTime: '13:00',
            endTime: '14:00',
            title: '遵义捞沙巷特色小吃（刘二妈米皮、羊肉粉）',
            location: '遵义捞沙巷步行街',
            cost: 70,
            reason: '遵义老城最著名的美食街，羊肉汤鲜醇不膻，米皮爽滑筋道。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'transit',
            startTime: '14:30',
            endTime: '17:00',
            title: '自驾前往赤水市区',
            distanceKm: 210.0,
            durationMin: 150,
            cost: 0,
          ),
          ItineraryItem(
            itemType: 'hotel',
            startTime: '17:30',
            endTime: '18:30',
            title: '入住赤水精品酒店',
            location: '赤水市区',
            cost: 340,
            reason: '近赤水河畔，环境幽静舒适。',
            verificationStatus: 'verified',
          ),
        ],
      ),
      ItineraryDay(
        dayIndex: 2,
        date: '2026-10-02',
        title: 'Day 2: 赤水大瀑布与世界自然遗产丹霞奇观',
        items: [
          ItineraryItem(
            itemType: 'attraction',
            startTime: '08:30',
            endTime: '12:30',
            title: '赤水大瀑布景区 (5A)',
            location: '遵义市赤水市风溪镇',
            cost: 320,
            reason: '高76米、宽80米，我国丹霞地貌区最大的瀑布，水帘飞泻，如雷贯耳。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'attraction',
            startTime: '13:30',
            endTime: '16:00',
            title: '赤水佛光岩 (世界自然遗产)',
            location: '遵义市赤水市元厚镇',
            cost: 160,
            reason: '赤水丹霞的核心精华，高达385米、宽逾1000米的红色弧形丹霞绝壁。',
            verificationStatus: 'verified',
          ),
          ItineraryItem(
            itemType: 'transit',
            startTime: '16:30',
            endTime: '20:30',
            title: '经蓉遵高速返程贵阳',
            distanceKm: 320.0,
            durationMin: 240,
            cost: 0,
          ),
        ],
      ),
    ],
  );

  static final List<ItineraryPlanResponse> all = [
    anshunBenchmark,
    guiyangOneDay,
    liboXijiangThreeDay,
    zunyiChishuiTwoDay,
  ];
}
