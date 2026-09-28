import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/theme_constants.dart';
import '../../models/itinerary_model.dart';
import '../../providers/itinerary_provider.dart';
import '../../widgets/budget_bar.dart';
import '../../widgets/fact_badge.dart';
import '../../widgets/warning_banner.dart';
import 'reorder_day_dialog.dart';
import 'feedback_dialog.dart';

class ItineraryDetailPage extends ConsumerStatefulWidget {
  final String? itineraryId;

  const ItineraryDetailPage({super.key, this.itineraryId});

  @override
  ConsumerState<ItineraryDetailPage> createState() => _ItineraryDetailPageState();
}

class _ItineraryDetailPageState extends ConsumerState<ItineraryDetailPage> {
  int _selectedDay = 0;

  @override
  Widget build(BuildContext context) {
    final itineraryState = ref.watch(itineraryProvider);
    final plan = itineraryState.plan;

    if (itineraryState.isLoading && plan == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('AI 规划引擎正在核算最佳路线与预算...'),
            ],
          ),
        ),
      );
    }

    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('行程详情')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(itineraryState.errorMessage ?? '暂无行程数据'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('返回重新规划'),
              ),
            ],
          ),
        ),
      );
    }

    final currentDay = plan.days.isNotEmpty && _selectedDay < plan.days.length
        ? plan.days[_selectedDay]
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.summary.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.rate_review_outlined),
            tooltip: '评价反馈',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => FeedbackDialog(
                  onSubmit: (rating, comment) =>
                      ref.read(itineraryProvider.notifier).submitFeedback(rating, comment),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 警告横幅
            WarningBanner(warnings: plan.warnings),

            // 预算管控条
            BudgetBar(budget: plan.budget),
            const SizedBox(height: 16),

            // 行程状态卡片
            if (itineraryState.isTripActive)
              Container(
                margin: const EdgeInsets.bottom: 16,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.verifiedGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.verifiedGreen),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.directions_car, color: AppTheme.verifiedGreen),
                    SizedBox(width: 8),
                    Text(
                      '旅程正在进行中 (status: active)',
                      style: TextStyle(
                        color: AppTheme.verifiedGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // 天数选择标签
            Row(
              children: List.generate(plan.days.length, (index) {
                final isSelected = index == _selectedDay;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('第 ${index + 1} 天'),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryBlue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.darkInk,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedDay = index);
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),

            // 当前天操作条 (调整顺序)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currentDay?.title ?? '游览节点',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkInk,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.sort, size: 16),
                  label: const Text('调整顺序'),
                  onPressed: currentDay == null
                      ? null
                      : () {
                          showDialog(
                            context: context,
                            builder: (_) => ReorderDayDialog(
                              dayIndex: _selectedDay,
                              items: currentDay.items,
                              onConfirm: (ids) => ref
                                  .read(itineraryProvider.notifier)
                                  .reorderDay(dayIndex: _selectedDay, orderedAttractionIds: ids),
                            ),
                          );
                        },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 时间轴节点列表
            if (currentDay != null)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentDay.items.length,
                itemBuilder: (context, index) {
                  final it = currentDay.items[index];
                  return _buildTimelineItem(it);
                },
              ),

            const SizedBox(height: 24),
            // 开始行程按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.navigation_outlined),
                label: Text(itineraryState.isTripActive ? '旅程进行中' : '开始旅程 (active)'),
                onPressed: itineraryState.isTripActive
                    ? null
                    : () async {
                        await ref.read(itineraryProvider.notifier).startTrip();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('行程已成功启动！进入实地行中执行模式。')),
                          );
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(ItineraryItem it) {
    final isTransit = it.itemType == 'transit';
    if (isTransit) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 20),
        child: Row(
          children: [
            const Icon(Icons.arrow_downward, size: 14, color: AppTheme.mutedGray),
            const SizedBox(width: 8),
            Text(
              '自驾 ${it.distanceKm?.toStringAsFixed(1) ?? ""}km · 约 ${it.durationMin ?? ""} 分钟',
              style: const TextStyle(fontSize: 11, color: AppTheme.mutedGray),
            ),
          ],
        ),
      );
    }

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
                Row(
                  children: [
                    Text(
                      '${it.startTime ?? ""} ~ ${it.endTime ?? ""}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FactBadge(status: it.verificationStatus ?? 'verified'),
                  ],
                ),
                Text(
                  it.cost > 0 ? '¥${it.cost}' : '免费',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              it.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkInk,
              ),
            ),
            if (it.reason != null && it.reason!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                it.reason!,
                style: const TextStyle(fontSize: 12, color: AppTheme.mutedGray),
              ),
            ],
            if (it.notice != null && it.notice!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warmAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '💡 贴士: ${it.notice}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.warmAccent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
