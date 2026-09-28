import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/theme_constants.dart';
import '../../providers/itinerary_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('游迹 · 贵州 AI 旅行'),
        actions: [
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
                  const Text(
                    'AI 个性化定制 · 官方事实核验',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
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
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryBlue,
                    ),
                    onPressed: () => context.push('/plan'),
                    child: const Text('开始智能规划'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 标杆首条闭环卡片
            const Text(
              '标杆推荐路线',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkInk,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  await ref.read(itineraryProvider.notifier).createPlan(
                        origin: '贵阳',
                        destination: '安顺',
                        startDate: '2026-10-01',
                        days: 2,
                        people: 2,
                        budget: 2000,
                        transport: 'self_drive',
                        interests: ['自然风光', '历史文化'],
                      );
                  if (context.mounted) {
                    context.push('/itinerary/detail');
                  }
                },
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
                            '预算 ¥2000 / 2人',
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
                        '自驾 280km · 包含黄果树大瀑布深度探秘、龙宫地下溶洞游船、平坝天龙屯堡明代地戏体验。',
                        style: TextStyle(fontSize: 12, color: AppTheme.mutedGray),
                      ),
                      const SizedBox(height: 12),
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
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('AI 助手'),
        onPressed: () => context.push('/chat'),
      ),
    );
  }
}
