import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/theme_constants.dart';
import '../../models/itinerary_model.dart';
import '../../models/location_model.dart';
import '../../providers/itinerary_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/entity_cover_image.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  void _showCitySwitcherSheet(BuildContext context, WidgetRef ref) {
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
                      '选择当前所在城市',
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
                  '支持贵州 9 大市州，将自动为您计算周边景点距离与推荐自驾路线。',
                  style: TextStyle(fontSize: 12, color: AppTheme.mutedGray),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: GuizhouCities.all.map((city) {
                    final currentCity = ref.read(locationProvider).currentCity;
                    final isCurrent = currentCity.name == city.name;
                    return ChoiceChip(
                      label: Text(city.name),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已切换定位至 ${city.name}')),
                          );
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.my_location, size: 16),
                      label: const Text('重新自动定位'),
                      onPressed: () async {
                        await ref.read(locationProvider.notifier).refreshLocation();
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('GPS 定位已更新')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locState = ref.watch(locationProvider);
    final itineraryState = ref.watch(itineraryProvider);
    final activePlan = itineraryState.plan;

    return Scaffold(
      appBar: AppBar(
        title: const Text('游迹 · 贵州 AI 旅行'),
        actions: [
          // 顶部定位切换按钮
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showCitySwitcherSheet(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 15, color: AppTheme.primaryBlue),
                  const SizedBox(width: 4),
                  Text(
                    '${locState.currentCity.name} · ${locState.currentCity.weather}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.primaryBlue),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'AI 助手',
            onPressed: () => context.push('/chat'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部特色横幅
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.cyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'AI 个性化定制 · 官方事实核验',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '当前基准：${locState.currentCity.shortName}',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '开启可落地的贵州探索之旅',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryBlue,
                        ),
                        onPressed: () => context.push('/plan'),
                        child: const Text('开始智能规划'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                        onPressed: () => context.push('/itineraries'),
                        child: const Text('精选路线库'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 功能快捷入口
            Row(
              children: [
                _buildQuickAction(
                  context: context,
                  icon: Icons.near_me,
                  label: '周边距离',
                  subLabel: '按近到远排序',
                  color: AppTheme.primaryBlue,
                  onTap: () => context.push('/explore'),
                ),
                const SizedBox(width: 12),
                _buildQuickAction(
                  context: context,
                  icon: Icons.alt_route,
                  label: '行程选择',
                  subLabel: '切换与路线库',
                  color: AppTheme.cyan,
                  onTap: () => context.push('/itineraries'),
                ),
                const SizedBox(width: 12),
                _buildQuickAction(
                  context: context,
                  icon: Icons.auto_awesome,
                  label: 'AI 问答',
                  subLabel: '黄果树等门票',
                  color: AppTheme.gold,
                  onTap: () => context.push('/chat'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 当前选中的行程卡片
            const Text(
              '当前行程状态',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkInk),
            ),
            const SizedBox(height: 10),
            if (activePlan != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppTheme.primaryBlue, width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '当前选定生效',
                              style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            '预算 ¥${activePlan.budget.total} / ${activePlan.summary.people}人',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        activePlan.summary.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkInk),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${activePlan.summary.origin} → ${activePlan.summary.destination} · ${activePlan.summary.days}天 · 自驾 ${activePlan.summary.totalDistanceKm.toStringAsFixed(0)}km',
                        style: const TextStyle(fontSize: 12, color: AppTheme.mutedGray),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => context.push('/itineraries'),
                            child: const Text('切换其他行程'),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: const Text('查看详情与调整'),
                            onPressed: () => context.push('/itinerary/detail'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.mutedGray, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '暂未选择活跃行程',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              '您可以直接采用经典闭环路线，或新建智能规划',
                              style: TextStyle(fontSize: 12, color: AppTheme.mutedGray),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => context.push('/itineraries'),
                        child: const Text('挑选路线'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // 标杆首条闭环卡片
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '标杆经典路线',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkInk,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/itineraries'),
                  child: const Text('查看全部 5 条经典路线 >'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.sageAccent.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'V0.1 闭环标杆',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                        const Text(
                          '预算 ¥1850 / 2人',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '贵阳 → 安顺（黄果树/龙宫/天龙屯堡）经典两日游',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '自驾 285km · 包含黄果树大瀑布深度探秘、龙宫地下溶洞游船、平坝天龙屯堡明代地戏体验。',
                      style: TextStyle(fontSize: 12, color: AppTheme.mutedGray),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      children: [
                        Icon(Icons.verified, size: 14, color: AppTheme.verifiedGreen),
                        SizedBox(width: 4),
                        Text(
                          '3大核心景区 100% 官方已核验门票与营业时间',
                          style: TextStyle(fontSize: 11, color: AppTheme.verifiedGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('一键采用并预览'),
                          onPressed: () async {
                            await ref
                                .read(itineraryProvider.notifier)
                                .adoptPresetRoute(CuratedBenchmarkRoutes.anshunBenchmark);
                            if (context.mounted) {
                              context.push('/itinerary/detail');
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subLabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subLabel,
                style: const TextStyle(fontSize: 10, color: AppTheme.mutedGray),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
