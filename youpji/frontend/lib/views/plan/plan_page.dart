import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/theme_constants.dart';
import '../../providers/itinerary_provider.dart';

class PlanPage extends ConsumerStatefulWidget {
  const PlanPage({super.key});

  @override
  ConsumerState<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends ConsumerState<PlanPage> {
  final TextEditingController _originCtrl = TextEditingController(text: '贵阳');
  final TextEditingController _destCtrl = TextEditingController(text: '安顺');
  final TextEditingController _naturalCtrl = TextEditingController();

  int _days = 2;
  int _people = 2;
  double _budget = 2000;
  final String _transport = 'self_drive';
  final List<String> _selectedInterests = ['自然风光', '历史文化'];

  final List<String> _allInterests = ['自然风光', '历史文化', '喀斯特溶洞', '特色美食', '古镇古寨', '亲子休闲'];

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _naturalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itineraryState = ref.watch(itineraryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('定制 AI 旅游规划')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 出发与目的地
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _originCtrl,
                    decoration: const InputDecoration(
                      labelText: '出发地',
                      prefixIcon: Icon(Icons.trip_origin),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, color: AppTheme.mutedGray),
                ),
                Expanded(
                  child: TextField(
                    controller: _destCtrl,
                    decoration: const InputDecoration(
                      labelText: '目的地',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
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
                const Text('总预算预算上限', style: TextStyle(fontWeight: FontWeight.w600)),
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
                hintText: '如：想去看黄果树瀑布和龙宫，不想太早起床，喜欢吃屯堡家常菜...',
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
                        await ref.read(itineraryProvider.notifier).createPlan(
                              origin: _originCtrl.text.trim(),
                              destination: _destCtrl.text.trim(),
                              startDate: '2026-10-01',
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
