import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/theme_constants.dart';
import '../../models/location_model.dart';
import '../../providers/itinerary_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/location_service.dart';

class PlanPage extends ConsumerStatefulWidget {
  final String? initialOrigin;
  final String? initialDestination;

  const PlanPage({
    super.key,
    this.initialOrigin,
    this.initialDestination,
  });

  @override
  ConsumerState<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends ConsumerState<PlanPage> {
  late TextEditingController _originCtrl;
  late TextEditingController _destCtrl;
  final TextEditingController _naturalCtrl = TextEditingController();

  DateTime _startDate = DateTime(2026, 10, 1);
  int _days = 2;
  int _people = 2;
  double _budget = 2000;
  final String _transport = 'self_drive';
  final List<String> _selectedInterests = ['自然风光', '历史文化'];

  final List<String> _allInterests = [
    '自然风光',
    '历史文化',
    '文博场馆/博物院',
    '喀斯特溶洞',
    '特色美食',
    '古镇古寨',
    '亲子休闲',
  ];

  @override
  void initState() {
    super.initState();
    final defaultOrigin = widget.initialOrigin ?? ref.read(locationProvider).currentCity.shortName;
    _originCtrl = TextEditingController(text: defaultOrigin);
    _destCtrl = TextEditingController(text: widget.initialDestination ?? '安顺');

    _originCtrl.addListener(_onRouteChanged);
    _destCtrl.addListener(_onRouteChanged);
  }

  void _onRouteChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _originCtrl.removeListener(_onRouteChanged);
    _destCtrl.removeListener(_onRouteChanged);
    _originCtrl.dispose();
    _destCtrl.dispose();
    _naturalCtrl.dispose();
    super.dispose();
  }

  /// 计算出发地与目的地之间的估算距离和耗时
  Map<String, dynamic> _computeRouteEstimate() {
    final originCity = GuizhouCities.findByName(_originCtrl.text.trim());
    final destCity = GuizhouCities.findByName(_destCtrl.text.trim());

    if (originCity.name == destCity.name) {
      return {
        'distance_km': 30.0,
        'duration_text': '市内自驾约 40 分钟',
        'is_same_city': true,
      };
    }

    final roadKm = LocationService.estimateDrivingDistanceKm(
      originCity.latitude,
      originCity.longitude,
      destCity.latitude,
      destCity.longitude,
    );
    final hours = LocationService.estimateDrivingHours(roadKm);

    return {
      'distance_km': roadKm,
      'duration_text': LocationService.formatDrivingTime(hours),
      'is_same_city': false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final itineraryState = ref.watch(itineraryProvider);
    final routeEstimate = _computeRouteEstimate();
    final double distKm = routeEstimate['distance_km'] as double;
    final String durText = routeEstimate['duration_text'] as String;

    return Scaffold(
      appBar: AppBar(title: const Text('定制 AI 旅游规划')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 出发与目的地输入
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _originCtrl,
                    decoration: InputDecoration(
                      labelText: '出发地',
                      prefixIcon: const Icon(Icons.trip_origin, color: AppTheme.primaryBlue),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.my_location, size: 18),
                        tooltip: '使用当前定位城市',
                        onPressed: () {
                          final currentCity = ref.read(locationProvider).currentCity;
                          _originCtrl.text = currentCity.shortName;
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz, color: AppTheme.primaryBlue),
                  tooltip: '对调出发地与目的地',
                  onPressed: () {
                    final temp = _originCtrl.text;
                    _originCtrl.text = _destCtrl.text;
                    _destCtrl.text = temp;
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _destCtrl,
                    decoration: const InputDecoration(
                      labelText: '目的地',
                      prefixIcon: Icon(Icons.location_on, color: AppTheme.dangerRed),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 实时自驾距离与耗时预估卡片
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car, size: 18, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '自驾预估：约 ${distKm.toStringAsFixed(0)} km · $durText · 官方高速路线',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 快捷目的地快选
            Row(
              children: [
                const Text('热门目的地：', style: TextStyle(fontSize: 12, color: AppTheme.mutedGray)),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['安顺', '贵阳文博', '荔波', '西江千户苗寨', '遵义', '赤水', '兴义万峰林', '梵净山'].map((dest) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(dest, style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              if (dest == '贵阳文博') {
                                _destCtrl.text = '贵阳';
                                if (!_selectedInterests.contains('文博场馆/博物院')) {
                                  setState(() {
                                    _selectedInterests.add('文博场馆/博物院');
                                  });
                                }
                              } else {
                                _destCtrl.text = dest;
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 出发日期与时间选择
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2026, 1, 1),
                  lastDate: DateTime(2027, 12, 31),
                );
                if (picked != null) {
                  setState(() => _startDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 20, color: AppTheme.primaryBlue),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('出发日期', style: TextStyle(fontSize: 11, color: AppTheme.mutedGray)),
                        const SizedBox(height: 2),
                        Text(
                          '${_startDate.year}年${_startDate.month}月${_startDate.day}日 (预计出发)',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.darkInk),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text('修改 >', style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 天数与人数选择
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('行程天数', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 1, label: Text('1天')),
                          ButtonSegment(value: 2, label: Text('2天')),
                          ButtonSegment(value: 3, label: Text('3天')),
                        ],
                        selected: {_days},
                        onSelectionChanged: (val) => setState(() => _days = val.first),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('出行人数', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 1, label: Text('1人')),
                          ButtonSegment(value: 2, label: Text('2人')),
                          ButtonSegment(value: 4, label: Text('4人')),
                        ],
                        selected: {_people},
                        onSelectionChanged: (val) => setState(() => _people = val.first),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 预算滑动条
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('总预算上限', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '¥${_budget.toInt()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
            Slider(
              value: _budget,
              min: 500,
              max: 6000,
              divisions: 55,
              label: '¥${_budget.toInt()}',
              activeColor: AppTheme.primaryBlue,
              onChanged: (val) => setState(() => _budget = val),
            ),
            const SizedBox(height: 16),

            // 兴趣标签选择
            const Text('出行偏好', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allInterests.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  checkmarkColor: AppTheme.primaryBlue,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedInterests.add(interest);
                      } else {
                        _selectedInterests.remove(interest);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 自然语言输入框
            const Text('补充需求 (自然语言描述)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _naturalCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: '如：想去贵州省博物馆和地质博物馆看古生物化石，不想太早起床，喜欢吃酸汤鱼...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 28),

            // 生成规划按钮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: itineraryState.isLoading
                    ? null
                    : () async {
                        final natural = _naturalCtrl.text.trim();
                        final startFormatted =
                            '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';
                        await ref.read(itineraryProvider.notifier).createPlan(
                              origin: _originCtrl.text.trim(),
                              destination: _destCtrl.text.trim(),
                              startDate: startFormatted,
                              days: _days,
                              people: _people,
                              budget: _budget.toInt(),
                              transport: _transport,
                              interests: _selectedInterests,
                              naturalInput: natural.isNotEmpty ? natural : null,
                            );

                        final plan = ref.read(itineraryProvider).plan;
                        if (plan != null && context.mounted) {
                          context.push('/itinerary/detail');
                        } else if (context.mounted && ref.read(itineraryProvider).errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('规划失败: ${ref.read(itineraryProvider).errorMessage}'),
                              backgroundColor: AppTheme.dangerRed,
                            ),
                          );
                        }
                      },
                child: itineraryState.isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text('正在规划中...'),
                        ],
                      )
                    : const Text('一键智能生成结构化行程'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
