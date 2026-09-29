import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/theme_constants.dart';
import '../../models/itinerary_model.dart';
import '../../providers/itinerary_provider.dart';

class ItineraryListPage extends ConsumerStatefulWidget {
  const ItineraryListPage({super.key});

  @override
  ConsumerState<ItineraryListPage> createState() => _ItineraryListPageState();
}

class _ItineraryListPageState extends ConsumerState<ItineraryListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itineraryState = ref.watch(itineraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('行程选择与路线库'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryBlue,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: AppTheme.mutedGray,
          tabs: const [
            Tab(text: '我的行程历史'),
            Tab(text: '经典路线精选'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: 我的行程列表
          _buildMyItinerariesTab(context, itineraryState),
          // Tab 2: 经典路线精选
          _buildPresetRoutesTab(context),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('新建规划'),
        onPressed: () => context.push('/plan'),
      ),
    );
  }

  Widget _buildMyItinerariesTab(BuildContext context, ItineraryState state) {
    final list = state.savedPlans;
    final currentActiveId = state.plan?.itineraryId;

    if (list.isEmpty && state.plan == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.route_outlined, size: 56, color: AppTheme.mutedGray),
              const SizedBox(height: 16),
              const Text(
                '暂未保存任何行程',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkInk),
              ),
              const SizedBox(height: 8),
              const Text(
                '您可以选择智能生成专属行程，或从经典路线库中直接挑选。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.mutedGray),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _tabController.animateTo(1),
                child: const Text('查看经典路线精选'),
              ),
            ],
          ),
        ),
      );
    }

    // 合并当前内存活跃与持久缓存列表
    final displayedPlans = <ItineraryPlanResponse>[];
    if (state.plan != null) {
      displayedPlans.add(state.plan!);
    }
    for (final p in list) {
      if (p.itineraryId != currentActiveId) {
        displayedPlans.add(p);
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: displayedPlans.length,
      itemBuilder: (context, index) {
        final plan = displayedPlans[index];
        final isActive = plan.itineraryId == currentActiveId;

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isActive
                ? const BorderSide(color: AppTheme.primaryBlue, width: 1.5)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '当前生效行程',
                          style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '已保存 · ${plan.summary.days}天',
                          style: const TextStyle(fontSize: 11, color: Colors.black84),
                        ),
                      ),
                    Text(
                      '预算 ¥${plan.budget.total}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  plan.summary.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${plan.summary.origin} → ${plan.summary.destination} · ${plan.summary.people}人同行 · 自驾约 ${plan.summary.totalDistanceKm.toStringAsFixed(0)}km',
                  style: const TextStyle(fontSize: 12, color: AppTheme.mutedGray),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isActive)
                      OutlinedButton(
                        onPressed: () {
                          ref.read(itineraryProvider.notifier).selectPlan(plan);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已将「${plan.summary.title}」设为当前活跃行程')),
                          );
                        },
                        child: const Text('设为当前'),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(itineraryProvider.notifier).selectPlan(plan);
                        context.push('/itinerary/detail');
                      },
                      child: const Text('查看详情'),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.mutedGray),
                      tooltip: '删除行程',
                      onPressed: () {
                        _showDeleteConfirm(context, plan);
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

  Widget _buildPresetRoutesTab(BuildContext context) {
    final presets = CuratedBenchmarkRoutes.all;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final item = presets[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
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
                        color: AppTheme.sageAccent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        index == 0 ? 'V0.1 闭环标杆' : '官方核验精选',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    Text(
                      '预估 ¥${item.budget.total} / ${item.summary.people}人',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.summary.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.summary.origin} → ${item.summary.destination} · ${item.summary.days}天行程 · 预估车程 ${item.summary.driveHours}小时 · 自驾 ${item.summary.totalDistanceKm.toStringAsFixed(0)}km',
                  style: const TextStyle(fontSize: 12, color: AppTheme.mutedGray),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.verified, size: 14, color: AppTheme.verifiedGreen),
                    const SizedBox(width: 4),
                    Text(
                      '包含 ${item.days.fold(0, (acc, d) => acc + d.items.where((it) => it.itemType == "attraction").length)} 个官方核验景区节点',
                      style: const TextStyle(fontSize: 11, color: AppTheme.verifiedGreen),
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
                        await ref.read(itineraryProvider.notifier).adoptPresetRoute(item);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已采用标杆路线「${item.summary.title}」！')),
                          );
                          context.push('/itinerary/detail');
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

  void _showDeleteConfirm(BuildContext context, ItineraryPlanResponse plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除行程？'),
        content: Text('确定要删除「${plan.summary.title}」吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (plan.itineraryId != null) {
                await ref.read(itineraryProvider.notifier).deletePlan(plan.itineraryId!);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('行程已成功删除')),
                );
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
