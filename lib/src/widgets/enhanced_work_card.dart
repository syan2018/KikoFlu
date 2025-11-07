import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/work.dart';
import '../providers/auth_provider.dart';
import '../screens/work_detail_screen.dart';
import 'tag_chip.dart';
import 'va_chip.dart';

class EnhancedWorkCard extends ConsumerWidget {
  final Work work;
  final VoidCallback? onTap;
  final int crossAxisCount;

  const EnhancedWorkCard({
    super.key,
    required this.work,
    this.onTap,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final host = authState.host ?? '';
    final token = authState.token ?? '';

    // 如果没有提供自定义onTap，使用默认行为（导航到详情页面）
    final cardOnTap = onTap ??
        () {
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  WorkDetailScreen(work: work),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 0.1);
                const end = Offset.zero;
                const curve = Curves.easeInOut;
                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);
                return SlideTransition(
                  position: offsetAnimation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        };

    // 根据列数决定卡片样式
    if (crossAxisCount == 3) {
      return _buildCompactCard(context, host, token, cardOnTap);
    } else if (crossAxisCount == 2) {
      return _buildMediumCard(context, host, token, cardOnTap);
    } else {
      return _buildFullCard(context, host, token, cardOnTap);
    }
  }

  // 紧凑卡片 (3列布局)
  Widget _buildCompactCard(
      BuildContext context, String host, String token, VoidCallback cardOnTap) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.all(0),
      elevation: 8,
      child: InkWell(
        onTap: cardOnTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // 让 Column 高度自适应
          children: [
            // 封面图片区域
            AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                children: [
                  _buildCoverImage(context, host, token),
                  // RJ号标签 (左上角)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: _buildRjTag(),
                  ),
                  // 日期标签 (右下角)
                  if (work.release != null)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: _buildDateTag(),
                    ),
                ],
              ),
            ),
            // 信息区域 - 自适应高度
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Text(
                    work.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 中等卡片 (2列布局)
  Widget _buildMediumCard(
      BuildContext context, String host, String token, VoidCallback cardOnTap) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.all(0),
      elevation: 8,
      child: InkWell(
        onTap: cardOnTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 封面区域
            AspectRatio(
              aspectRatio: 1.3,
              child: Stack(
                children: [
                  _buildCoverImage(context, host, token),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _buildRjTag(),
                  ),
                  // 字幕标签 (左下角)
                  if (work.hasSubtitle == true)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: _buildSubtitleTag(context),
                    ),
                  if (work.release != null)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: _buildDateTag(),
                    ),
                ],
              ),
            ),
            // 信息区域 - 自适应高度
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Text(
                    work.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          fontSize: 12,
                        ),
                  ),
                  const SizedBox(height: 3),
                  // 社团名称
                  Text(
                    work.name ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                  ),
                  const SizedBox(height: 3),
                  // 价格
                  if (work.price != null)
                    Text(
                      '${work.price} 日元',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                    ),
                  // 评分信息
                  if (work.rateAverage != null &&
                      work.rateCount != null &&
                      work.rateCount! > 0) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: Colors.amber[700],
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${work.rateAverage!.toStringAsFixed(1)} (${work.rateCount})',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.amber[700],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 9,
                                  ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  if (work.tags != null && work.tags!.isNotEmpty)
                    _buildTagsRow(context),
                  const SizedBox(height: 2),
                  if (work.vas != null && work.vas!.isNotEmpty)
                    _buildVoiceActorsRow(context),
                  const SizedBox(height: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 完整卡片 (列表布局)
  Widget _buildFullCard(
      BuildContext context, String host, String token, VoidCallback cardOnTap) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: InkWell(
        onTap: cardOnTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一行：封面和标题
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 封面图片
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildCoverImage(context, host, token),
                        ),
                        // RJ号标签
                        Positioned(
                          top: 2,
                          left: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'RJ${work.id}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // 字幕标签 (左下角)
                        if (work.hasSubtitle == true)
                          Positioned(
                            bottom: 2,
                            left: 2,
                            child: _buildSubtitleTag(context),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 标题
                  Expanded(
                    child: Text(
                      work.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 第二行：其他信息
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 社团和价格行
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          work.name ?? '',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ),
                      if (work.price != null)
                        Text(
                          '${work.price} 日元',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 日期和下载数
                  Row(
                    children: [
                      if (work.release != null)
                        Text(
                          work.release!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                        ),
                      // 评分信息
                      if (work.rateAverage != null &&
                          work.rateCount != null &&
                          work.rateCount! > 0) ...[
                        if (work.release != null) const SizedBox(width: 8),
                        Icon(
                          Icons.star,
                          color: Colors.amber[700],
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${work.rateAverage!.toStringAsFixed(1)} (${work.rateCount})',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.amber[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                      const Spacer(),
                      if (work.dlCount != null)
                        Text(
                          '售出：${work.dlCount}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 标签
                  if (work.tags != null && work.tags!.isNotEmpty)
                    _buildTagsWrap(context),
                  const SizedBox(height: 6),
                  // 声优
                  if (work.vas != null && work.vas!.isNotEmpty)
                    _buildVoiceActorsWrap(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context, String host, String token) {
    // 使用缓存网络图片，减少滚动时的解码与网络开销，提升流畅度
    if (host.isEmpty) {
      return _buildPlaceholder(context);
    }

    final url = work.getCoverImageUrl(host, token: token);
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    // 依据不同布局控制图片缓存尺寸，避免加载超大原图导致卡顿
    int targetWidth;
    switch (crossAxisCount) {
      case 3:
        targetWidth =
            (MediaQuery.of(context).size.width / 3 * devicePixelRatio).round();
        break;
      case 2:
        targetWidth =
            (MediaQuery.of(context).size.width / 2 * devicePixelRatio).round();
        break;
      default:
        targetWidth = (80 * devicePixelRatio).round(); // 列表模式封面固定宽度
    }

    return Hero(
      tag: 'work_cover_${work.id}',
      child: RepaintBoundary(
        child: CachedNetworkImage(
          imageUrl: url,
          cacheKey: 'work_cover_${work.id}',
          memCacheWidth: targetWidth, // 降低解码分辨率，减少 GPU / CPU 压力
          fadeInDuration: const Duration(milliseconds: 120),
          fadeOutDuration: const Duration(milliseconds: 90),
          placeholderFadeInDuration: const Duration(milliseconds: 80),
          placeholder: (context, _) => _buildPlaceholder(context),
          errorWidget: (context, _, __) => _buildPlaceholder(context),
          imageBuilder: (context, imageProvider) => Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low, // 优化滚动时的重采样性能
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(
        Icons.audiotrack,
        color: Colors.grey,
        size: 32,
      ),
    );
  }

  Widget _buildRjTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'RJ${work.id}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDateTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        work.release!,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSubtitleTag(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(
        Icons.closed_caption,
        color: Colors.white,
        size: 14,
      ),
    );
  }

  Widget _buildTagsRow(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 14),
      child: Wrap(
        spacing: 3,
        runSpacing: 2,
        children: work.tags!.map((tag) {
          return TagChip(
            tag: tag,
            fontSize: 10,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            borderRadius: 6,
            fontWeight: FontWeight.w500,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVoiceActorsRow(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 14),
      child: Wrap(
        spacing: 3,
        runSpacing: 2,
        children: work.vas!.map((va) {
          return VaChip(
            va: va,
            fontSize: 10,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            borderRadius: 6,
            fontWeight: FontWeight.w500,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTagsWrap(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: work.tags!.map((tag) {
        return TagChip(
          tag: tag,
          fontSize: 11,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          borderRadius: 12,
          fontWeight: FontWeight.w500,
        );
      }).toList(),
    );
  }

  Widget _buildVoiceActorsWrap(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: work.vas!.map((va) {
        return VaChip(
          va: va,
          fontSize: 11,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          borderRadius: 12,
          fontWeight: FontWeight.w500,
        );
      }).toList(),
    );
  }
}
