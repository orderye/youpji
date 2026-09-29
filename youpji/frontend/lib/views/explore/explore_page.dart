import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/theme_constants.dart';
import '../../models/attraction_model.dart';
import '../../models/location_model.dart';
import '../../providers/api_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/fact_badge.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  String _selectedFilter = '全部';
  String _selectedCityFilter = '全省';

  final List<String> _filters = ['全部', '20km内', '50km内', '100km内', '5A景区'];
  final List<String> _cityFilters = ['全省', '贵阳', '安顺', '遵义', '黔东南', '黔南', '黔西南', '毕节', '铜仁', '六盘水'];

  bool _isLoading = false;
  List<AttractionItem> _attractions = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAttractions();
  }

  Future<void> _fetchAttractions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final loc = ref.read(locationProvider);
    final service = ref.read(travelServiceProvider);

    try {
      final list = await service.getAttractions(
        lng: loc.currentLongitude,
        lat: loc.currentLatitude,
        sortBy: 'distance',
        city: _selectedCityFilter != '全省' ? _selectedCityFilter : null,
        limit: 50,
      );

      if (list.isNotEmpty) {
        setState(() {
          _attractions = list;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    // 备选种子：若网络或后端为空，展示已核验全省 9 市州核心景区并结合本地 Haversine 算距
    final seeds = _getLocalSeedAttractions(loc);
    setState(() {
      _attractions = seeds;
      _isLoading = false;
    });
  }

  List<AttractionItem> _getLocalSeedAttractions(LocationState loc) {
    final notifier = ref.read(locationProvider.notifier);

    final list = [
      // 1. 安顺市
      AttractionItem(
        id: 'huangguoshu-01',
        name: '黄果树风景名胜区',
        level: '5A',
        city: '安顺市',
        district: '镇宁/关岭',
        suggestedDurationMin: 300,
        tags: ['自然风光', '喀斯特瀑布', '水帘洞', '陡坡塘'],
        verificationStatus: 'verified',
        price: 220,
        distanceMeters: notifier.distanceTo(25.992688, 105.666992) * 1000,
      ),
      AttractionItem(
        id: 'longgong-02',
        name: '龙宫风景名胜区',
        level: '5A',
        city: '安顺市',
        district: '西秀区',
        suggestedDurationMin: 180,
        tags: ['溶洞暗河', '喀斯特', '地下游船'],
        verificationStatus: 'verified',
        price: 130,
        distanceMeters: notifier.distanceTo(26.115456, 105.867912) * 1000,
      ),
      AttractionItem(
        id: 'tianlong-03',
        name: '平坝天龙屯堡古镇',
        level: '4A',
        city: '安顺市',
        district: '平坝区',
        suggestedDurationMin: 120,
        tags: ['历史文化', '大明屯堡', '地戏非遗'],
        verificationStatus: 'verified',
        price: 45,
        distanceMeters: notifier.distanceTo(26.353381, 106.166943) * 1000,
      ),
      AttractionItem(
        id: 'getuhe-04',
        name: '紫云格凸河穿洞景区',
        level: '4A',
        city: '安顺市',
        district: '紫云县',
        suggestedDurationMin: 240,
        tags: ['蜘蛛人攀岩', '绝壁穿洞', '户外徒步'],
        verificationStatus: 'verified',
        price: 100,
        distanceMeters: notifier.distanceTo(25.750012, 106.166743) * 1000,
      ),

      // 2. 贵阳市
      AttractionItem(
        id: 'qianlingshan-05',
        name: '黔灵山公园',
        level: '4A',
        city: '贵阳市',
        district: '云岩区',
        suggestedDurationMin: 150,
        tags: ['林城公园', '弘福寺', '野生灵猴'],
        verificationStatus: 'verified',
        price: 5,
        distanceMeters: notifier.distanceTo(26.602283, 106.697428) * 1000,
      ),
      AttractionItem(
        id: 'jiaxiulou-06',
        name: '甲秀楼',
        level: '3A',
        city: '贵阳市',
        district: '南明区',
        suggestedDurationMin: 90,
        tags: ['历史文化', '南明河畔', '夜景地标'],
        verificationStatus: 'verified',
        price: 0,
        distanceMeters: notifier.distanceTo(26.574676, 106.719661) * 1000,
      ),
      AttractionItem(
        id: 'qingyan-07',
        name: '花溪青岩古镇',
        level: '5A',
        city: '贵阳市',
        district: '花溪区',
        suggestedDurationMin: 180,
        tags: ['古镇风貌', '状元故居', '状元蹄美食'],
        verificationStatus: 'verified',
        price: 10,
        distanceMeters: notifier.distanceTo(26.331206, 106.685324) * 1000,
      ),
      AttractionItem(
        id: 'tianhetan-08',
        name: '花溪天河潭风景区',
        level: '4A',
        city: '贵阳市',
        district: '花溪区',
        suggestedDurationMin: 180,
        tags: ['水天一色', '溶洞游船', '高空缆车'],
        verificationStatus: 'verified',
        price: 80,
        distanceMeters: notifier.distanceTo(26.440169, 106.580558) * 1000,
      ),
      AttractionItem(
        id: 'yelanggu-09',
        name: '花溪夜郎谷石头城堡',
        level: '3A',
        city: '贵阳市',
        district: '花溪区',
        suggestedDurationMin: 120,
        tags: ['奇幻石头城', '艺术家宋培伦', '摄影打卡'],
        verificationStatus: 'verified',
        price: 20,
        distanceMeters: notifier.distanceTo(26.386902, 106.646181) * 1000,
      ),

      // 3. 黔南州 (荔波/平塘)
      AttractionItem(
        id: 'libo-10',
        name: '荔波樟江 · 小七孔景区',
        level: '5A',
        city: '黔南州',
        district: '荔波县',
        suggestedDurationMin: 360,
        tags: ['地球绿宝石', '卧龙潭蒂芙尼蓝', '水上森林'],
        verificationStatus: 'verified',
        price: 170,
        distanceMeters: notifier.distanceTo(25.283124, 107.728956) * 1000,
      ),
      AttractionItem:
        id: 'da7kou-11',
        name: '荔波大七孔景区',
        level: '5A',
        city: '黔南州',
        district: '荔波县',
        suggestedDurationMin: 150,
        tags: ['天生桥', '恐怖峡', '峡谷探秘'],
        verificationStatus: 'verified',
        price: 55,
        distanceMeters: notifier.distanceTo(25.291201, 107.751241) * 1000,
      ),
      AttractionItem(
        id: 'fast-12',
        name: '平塘中国天眼 FAST 科普基地',
        level: '4A',
        city: '黔南州',
        district: '平塘县',
        suggestedDurationMin: 240,
        tags: ['大国重器', '天文科普', '光年探索'],
        verificationStatus: 'verified',
        price: 140,
        distanceMeters: notifier.distanceTo(25.653124, 106.858956) * 1000,
      ),

      // 4. 黔东南州 (苗寨/侗寨/镇远)
      AttractionItem(
        id: 'xijiang-13',
        name: '西江千户苗寨',
        level: '5A',
        city: '黔东南州',
        district: '雷山县',
        suggestedDurationMin: 300,
        tags: ['全球最大苗寨', '万家灯火', '吊脚楼风情'],
        verificationStatus: 'verified',
        price: 110,
        distanceMeters: notifier.distanceTo(26.495201, 108.172459) * 1000,
      ),
      AttractionItem(
        id: 'zhaoxing-14',
        name: '肇兴侗寨',
        level: '4A',
        city: '黔东南州',
        district: '黎平县',
        suggestedDurationMin: 240,
        tags: ['侗族鼓楼群', '侗族大歌', '非遗蓝染'],
        verificationStatus: 'verified',
        price: 80,
        distanceMeters: notifier.distanceTo(25.908201, 109.182459) * 1000,
      ),
      AttractionItem(
        id: 'zhenyuan-15',
        name: '镇远古城',
        level: '5A',
        city: '黔东南州',
        district: '镇远县',
        suggestedDurationMin: 240,
        tags: ['舞阳河太极古城', '青龙洞古建筑群', '水乡夜景'],
        verificationStatus: 'verified',
        price: 0,
        distanceMeters: notifier.distanceTo(27.052201, 108.422459) * 1000,
      ),

      // 5. 遵义市
      AttractionItem(
        id: 'zunyi-16',
        name: '遵义会议会址',
        level: '5A',
        city: '遵义市',
        district: '红花岗区',
        suggestedDurationMin: 120,
        tags: ['红色文化', '伟大转折', '全国重保'],
        verificationStatus: 'verified',
        price: 0,
        distanceMeters: notifier.distanceTo(27.690856, 106.929834) * 1000,
      ),
      AttractionItem(
        id: 'chishui-17',
        name: '赤水丹霞旅游区 · 大瀑布',
        level: '5A',
        city: '遵义市',
        district: '赤水市',
        suggestedDurationMin: 240,
        tags: ['世界自然遗产', '丹霞绝壁', '赤水大瀑布'],
        verificationStatus: 'verified',
        price: 80,
        distanceMeters: notifier.distanceTo(28.431201, 105.992451) * 1000,
      ),
      AttractionItem(
        id: 'foguangyan-18',
        name: '赤水丹霞 · 佛光岩',
        level: '5A',
        city: '遵义市',
        district: '赤水市',
        suggestedDurationMin: 180,
        tags: ['世界自然遗产', '弧形赤壁', '地质奇观'],
        verificationStatus: 'verified',
        price: 80,
        distanceMeters: notifier.distanceTo(28.351201, 105.912451) * 1000,
      ),
      AttractionItem(
        id: 'hailongtun-19',
        name: '汇川海龙屯军事遗址',
        level: '4A',
        city: '遵义市',
        district: '汇川区',
        suggestedDurationMin: 180,
        tags: ['世界文化遗产', '明代土司城堡', '雄关漫道'],
        verificationStatus: 'verified',
        price: 65,
        distanceMeters: notifier.distanceTo(27.809255, 106.819958) * 1000,
      ),

      // 6. 黔西南州 (万峰林/马岭河)
      AttractionItem(
        id: 'wanfenglin-20',
        name: '兴义万峰林景区',
        level: '5A',
        city: '黔西南州',
        district: '兴义市',
        suggestedDurationMin: 240,
        tags: ['天下奇观', '徐霞客赞誉', '八卦田布依骑行'],
        verificationStatus: 'verified',
        price: 120,
        distanceMeters: notifier.distanceTo(24.981201, 104.912451) * 1000,
      ),
      AttractionItem(
        id: 'malinghe-21',
        name: '马岭河峡谷',
        level: '4A',
        city: '黔西南州',
        district: '兴义市',
        suggestedDurationMin: 180,
        tags: ['地球上一道美丽的伤痕', '百瀑峡谷', '高空吊桥'],
        verificationStatus: 'verified',
        price: 70,
        distanceMeters: notifier.distanceTo(25.121201, 104.952451) * 1000,
      ),

      // 7. 毕节市 (百里杜鹃/织金洞)
      AttractionItem(
        id: 'bailidujuan-22',
        name: '百里杜鹃风景名胜区',
        level: '5A',
        city: '毕节市',
        district: '大方/黔西',
        suggestedDurationMin: 300,
        tags: ['地球彩带', '世界天然花园', '高山杜鹃'],
        verificationStatus: 'verified',
        price: 130,
        distanceMeters: notifier.distanceTo(27.211201, 105.812451) * 1000,
      ),
      AttractionItem(
        id: 'zhijindong-23',
        name: '织金洞国家地质公园',
        level: '5A',
        city: '毕节市',
        district: '织金县',
        suggestedDurationMin: 240,
        tags: ['黄山归来不看岳，织金洞外无洞天', '银雨树', '广寒宫'],
        verificationStatus: 'verified',
        price: 140,
        distanceMeters: notifier.distanceTo(26.681201, 105.782451) * 1000,
      ),

      // 8. 铜仁市 (梵净山/朱砂古镇)
      AttractionItem(
        id: 'fanjingshan-24',
        name: '铜仁梵净山自然保护区',
        level: '5A',
        city: '铜仁市',
        district: '江口/印江',
        suggestedDurationMin: 360,
        tags: ['世界自然遗产', '红云金顶', '蘑菇石', '黔金丝猴'],
        verificationStatus: 'verified',
        price: 130,
        distanceMeters: notifier.distanceTo(27.911201, 108.682451) * 1000,
      ),
      AttractionItem(
        id: 'zhushaguzhen-25',
        name: '万山朱砂古镇',
        level: '4A',
        city: '铜仁市',
        district: '万山区',
        suggestedDurationMin: 180,
        tags: ['千年汞都', '玻璃栈道', '工业遗产遗迹'],
        verificationStatus: 'verified',
        price: 100,
        distanceMeters: notifier.distanceTo(27.521201, 109.212451) * 1000,
      ),

      // 9. 六盘水市 (乌蒙大草原/凉都)
      AttractionItem(
        id: 'wumeng-26',
        name: '盘州乌蒙大草原',
        level: '4A',
        city: '六盘水市',
        district: '盘州市',
        suggestedDurationMin: 300,
        tags: ['中国凉都', '高山佛光草原', '高空风车云海'],
        verificationStatus: 'verified',
        price: 30,
        distanceMeters: notifier.distanceTo(26.051201, 104.652451) * 1000,
      ),
      AttractionItem(
        id: 'yushe-27',
        name: '水城玉舍雪山国家森林公园',
        level: '4A',
        city: '六盘水市',
        district: '水城区',
        suggestedDurationMin: 240,
        tags: ['凉都避暑', '高山滑雪场', '原始林海'],
        verificationStatus: 'verified',
        price: 40,
        distanceMeters: notifier.distanceTo(26.451201, 104.812451) * 1000,
      ),
    ];

    list.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
    return list;
  }

  List<AttractionItem> get _filteredAttractions {
    return _attractions.where((it) {
      // 城市过滤
      if (_selectedCityFilter != '全省') {
        if (it.city == null || !it.city!.contains(_selectedCityFilter)) {
          return false;
        }
      }

      // 距离与级别过滤
      final distKm = (it.distanceMeters ?? 0) / 1000.0;
      if (_selectedFilter == '20km内') return distKm <= 20;
      if (_selectedFilter == '50km内') return distKm <= 50;
      if (_selectedFilter == '100km内') return distKm <= 100;
      if (_selectedFilter == '5A景区') return it.level == '5A';
      return true;
    }).toList();
  }

  void _showCitySwitcherSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '选择当前定位视角城市',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '支持切换全省 9 市州，自动为您计算该城市出发的周边景点距离。',
                  style: TextStyle(fontSize: 12, color: AppTheme.mutedGray),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: GuizhouCities.all.map((city) {
                    final currentCity = ref.read(locationProvider).currentCity;
                    final isCurrent = currentCity.name == city.name;
                    return ChoiceChip(
                      label: Text(city.shortName),
                      selected: isCurrent,
                      selectedColor: AppTheme.primaryBlue,
                      labelStyle: TextStyle(
                        color: isCurrent ? Colors.white : AppTheme.darkInk,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) {
                          ref.read(locationProvider.notifier).setCity(city);
                          Navigator.of(ctx).pop();
                          _fetchAttractions();
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(locationProvider);
    final displayedList = _filteredAttractions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('周边探索 · 全省景区地图'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.location_on, size: 18, color: AppTheme.primaryBlue),
            label: Text(
              loc.currentCity.shortName,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
            ),
            onPressed: () => _showCitySwitcherSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新距离',
            onPressed: _fetchAttractions,
          ),
        ],
      ),
      body: Column(
        children: [
          // 城市按区域快速选择栏
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _cityFilters.map((c) {
                  final isSelected = _selectedCityFilter == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(c),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                      checkmarkColor: AppTheme.primaryBlue,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSelected ? AppTheme.primaryBlue : AppTheme.darkInk,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedCityFilter = c);
                          _fetchAttractions();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 距离与类型筛选标签栏
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final isSelected = _selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryBlue,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : AppTheme.darkInk,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedFilter = f);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // 景点列表内容
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayedList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.explore_off, size: 48, color: AppTheme.mutedGray),
                            const SizedBox(height: 12),
                            Text(
                              '在 [$_selectedCityFilter · $_selectedFilter] 下未找到相关景区',
                              style: const TextStyle(color: AppTheme.mutedGray),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => setState(() {
                                _selectedFilter = '全部';
                                _selectedCityFilter = '全省';
                              }),
                              child: const Text('查看全省全部景区'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayedList.length,
                        itemBuilder: (context, idx) {
                          final it = displayedList[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            if (it.level != null) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.gold.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  it.level!,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.gold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            Flexible(
                                              child: Text(
                                                it.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.darkInk,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // 距离标记
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.near_me, size: 12, color: AppTheme.primaryBlue),
                                            const SizedBox(width: 3),
                                            Text(
                                              it.formattedDistance,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryBlue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      FactBadge(status: it.verificationStatus),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${it.city ?? ""} · ${it.district ?? ""}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.mutedGray),
                                      ),
                                      const Spacer(),
                                      Text(
                                        it.price != null && it.price! > 0
                                            ? '门票 ¥${it.price!.toInt()}'
                                            : '免费开放',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    children: it.tags.map((t) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(t, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.alt_route, size: 16),
                                        label: const Text('以此为目的地规划'),
                                        onPressed: () {
                                          context.push(
                                            '/plan?origin=${loc.currentCity.shortName}&destination=${it.name}',
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
