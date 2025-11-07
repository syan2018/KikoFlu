import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/work.dart';
import '../providers/auth_provider.dart';
import '../widgets/file_explorer_widget.dart';
import '../widgets/global_audio_player_wrapper.dart';
import '../widgets/tag_chip.dart';
import '../widgets/va_chip.dart';

class WorkDetailScreen extends ConsumerStatefulWidget {
  final Work work;

  const WorkDetailScreen({
    super.key,
    required this.work,
  });

  @override
  ConsumerState<WorkDetailScreen> createState() => _WorkDetailScreenState();
}

class _WorkDetailScreenState extends ConsumerState<WorkDetailScreen> {
  Work? _detailedWork;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showHDImage = false; // 控制是否显示高清图片
  ImageProvider? _hdImageProvider; // 预加载的高清图片

  @override
  void initState() {
    super.initState();
    _loadWorkDetail();
    // Hero 动画结束后开始预加载高清图
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _preloadHDImage();
      }
    });
  }

  // 预加载高清图片，完全加载后再切换
  Future<void> _preloadHDImage() async {
    final authState = ref.read(authProvider);
    final host = authState.host ?? '';
    final token = authState.token ?? '';

    if (host.isEmpty) return;

    final imageUrl = widget.work.getCoverImageUrl(host, token: token);
    final imageProvider = NetworkImage(imageUrl);

    try {
      // 预加载图片到内存
      await precacheImage(imageProvider, context);
      // 图片完全加载后才切换显示
      if (mounted) {
        setState(() {
          _hdImageProvider = imageProvider;
          _showHDImage = true;
        });
      }
    } catch (e) {
      // 预加载失败，保持使用缓存图片
      debugPrint('HD image preload failed: $e');
    }
  }

  // 复制文本到剪贴板并显示提示
  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已复制$label：$text'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadWorkDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final apiService = ref.read(kikoeruApiServiceProvider);
      final response = await apiService.getWork(widget.work.id);
      final detailedWork = Work.fromJson(response);

      setState(() {
        _detailedWork = detailedWork;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final work = _detailedWork ?? widget.work;

    return GlobalAudioPlayerWrapper(
      child: Scaffold(
        appBar: AppBar(
          // RJ号作为标题，支持长按复制
          title: GestureDetector(
            onLongPress: () => _copyToClipboard('RJ${widget.work.id}', 'RJ号'),
            child: Text(
              'RJ${widget.work.id}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final authState = ref.watch(authProvider);
    final host = authState.host ?? '';
    final token = authState.token ?? '';

    // 使用已有的work信息（来自列表），详细信息加载后再更新
    final work = _detailedWork ?? widget.work;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面图片 - 使用Stack叠加实现无感切换
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Hero(
              tag: 'work_cover_${widget.work.id}',
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    maxHeight: 500,
                  ),
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      // 底层：缓存图片，始终显示
                      CachedNetworkImage(
                        imageUrl: work.getCoverImageUrl(host, token: token),
                        cacheKey: 'work_cover_${widget.work.id}',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 300,
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 300,
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 64,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      // 顶层：高清图，加载完成后覆盖
                      if (_showHDImage && _hdImageProvider != null)
                        Image(
                          image: _hdImageProvider!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox.shrink(); // 出错时不显示，保持底层缓存图
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题 + 字幕图标 - 长按标题复制
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onLongPress: () => _copyToClipboard(work.title, '标题'),
                        child: Text(
                          work.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                        ),
                      ),
                    ),
                    // 字幕图标紧跟标题
                    if (work.hasSubtitle == true) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.closed_caption,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // 显示加载状态或错误信息
                if (_isLoading)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '正在加载详细信息...',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadWorkDetail,
                          child:
                              const Text('重试', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                // 评分信息 价格和销售信息
                Row(
                  children: [
                    // 评分信息 - 总是显示
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      (work.rateAverage != null &&
                              work.rateCount != null &&
                              work.rateCount! > 0)
                          ? work.rateAverage!.toStringAsFixed(1)
                          : '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${work.rateCount ?? 0})',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),

                    // 价格信息
                    if (work.price != null) ...[
                      const SizedBox(width: 16),
                      Text(
                        '${work.price} 日元',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.red[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                      ),
                      const SizedBox(width: 16),
                    ],

                    // 销售数量信息
                    if (work.dlCount != null && work.dlCount! > 0) ...[
                      Text(
                        '售出：${_formatNumber(work.dlCount!)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // 声优信息
                if (work.vas != null && work.vas!.isNotEmpty) ...[
                  Text(
                    '声优',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: work.vas!.map((va) {
                      return VaChip(
                        va: va,
                        fontSize: 12,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        borderRadius: 6,
                        fontWeight: FontWeight.w500,
                        onLongPress: () => _copyToClipboard(va.name, '声优'),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // 标签信息
                if (work.tags != null && work.tags!.isNotEmpty) ...[
                  Text(
                    '标签',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: work.tags!
                        .map((tag) => TagChip(
                              tag: tag,
                              fontSize: 12,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              borderRadius: 6,
                              fontWeight: FontWeight.w500,
                              onLongPress: () =>
                                  _copyToClipboard(tag.name, '标签'),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // 发布日期
                if (work.release != null) ...[
                  Text(
                    '发布日期',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    work.release!.split('T')[0],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                        ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 播放按钮 - 替换为文件浏览器
                Text(
                  '资源文件',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                ),
                const SizedBox(height: 8),

                // 文件浏览器组件
                Container(
                  height: 400, // 设置固定高度
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FileExplorerWidget(work: work),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(1)}万';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    } else {
      return number.toString();
    }
  }
}
