import 'package:flutter/material.dart';
import '../core/constants/theme_constants.dart';

/// 游迹统一实体头图展示组件
///
/// 具备能力：
/// 1. 自动适配网络图片加载与超时/失败重试
/// 2. 加载中骨架动画占位
/// 3. 当 URL 为空或网络异常时，提供符合设计规范的分类渐变图标兜底：
///    - city: 城市地标蓝青渐变
///    - attraction: 喀斯特山水青翠渐变
///    - museum: 文化场馆/博物馆人文紫金渐变
///    - restaurant: 餐饮美食活力暖橙渐变
///    - hotel: 酒店住宿雅致靛蓝渐变
class EntityCoverImage extends StatelessWidget {
  final String? imageUrl;
  final String category; // 'city' | 'attraction' | 'museum' | 'restaurant' | 'hotel'
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const EntityCoverImage({
    super.key,
    required this.imageUrl,
    this.category = 'attraction',
    this.width,
    this.height = 140,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(10);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        color: const Color(0xFFF1F5F9),
        child: (imageUrl != null && imageUrl!.trim().isNotEmpty)
            ? Image.network(
                imageUrl!.trim(),
                fit: fit,
                width: width ?? double.infinity,
                height: height,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: const Color(0xFFE2E8F0),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallback();
                },
              )
            : _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    IconData icon;
    LinearGradient gradient;
    String label;

    final normCat = category.toLowerCase();
    if (normCat.contains('museum') || normCat.contains('馆') || normCat.contains('博')) {
      icon = Icons.account_balance;
      gradient = const LinearGradient(
        colors: [Color(0xFF6B21A8), Color(0xFF9333EA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      label = '文化场馆 · 博物馆';
    } else if (normCat.contains('restaurant') ||
        normCat.contains('meal') ||
        normCat.contains('餐') ||
        normCat.contains('食')) {
      icon = Icons.restaurant;
      gradient = const LinearGradient(
        colors: [Color(0xFFEA580C), Color(0xFFF97316)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      label = '特色餐饮 · 美食';
    } else if (normCat.contains('hotel') ||
        normCat.contains('住') ||
        normCat.contains('宿') ||
        normCat.contains('店')) {
      icon = Icons.hotel;
      gradient = const LinearGradient(
        colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      label = '品质住宿 · 酒店';
    } else if (normCat.contains('city') || normCat.contains('市') || normCat.contains('州')) {
      icon = Icons.location_city;
      gradient = const LinearGradient(
        colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      label = '地市风貌';
    } else {
      // 景区自然风貌
      icon = Icons.landscape;
      gradient = const LinearGradient(
        colors: [Color(0xFF047857), Color(0xFF10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      label = '自然人文名胜';
    }

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        children: [
          Center(
            child: Icon(
              icon,
              size: (height != null && height! < 100) ? 28 : 42,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          Positioned(
            bottom: 6,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
