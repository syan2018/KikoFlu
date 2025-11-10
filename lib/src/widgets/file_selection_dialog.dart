import 'package:flutter/material.dart';
import '../models/work.dart';
import '../services/download_service.dart';
import '../utils/string_utils.dart';
import '../utils/file_icon_utils.dart';

class FileSelectionDialog extends StatefulWidget {
  final Work work;

  const FileSelectionDialog({
    super.key,
    required this.work,
  });

  @override
  State<FileSelectionDialog> createState() => _FileSelectionDialogState();
}

class _FileSelectionDialogState extends State<FileSelectionDialog> {
  final Map<String, bool> _selectedFiles = {}; // hash -> selected
  final Map<String, bool> _downloadedFiles = {}; // hash -> downloaded
  final Set<String> _expandedFolders = {}; // 展开的文件夹路径
  String? _mainFolderPath; // 主文件夹路径
  bool _isCheckingDownloads = true;

  @override
  void initState() {
    super.initState();
    _initializeSelection();
    _identifyAndExpandMainFolder();
    _checkDownloadedFiles();
  }

  void _initializeSelection() {
    void processChildren(List<AudioFile> children) {
      for (final file in children) {
        if (file.type == 'file' && file.hash != null) {
          _selectedFiles[file.hash!] = false;
          _downloadedFiles[file.hash!] = false;
        }
        if (file.children != null) {
          processChildren(file.children!);
        }
      }
    }

    if (widget.work.children != null) {
      processChildren(widget.work.children!);
    }
  }

  // 检查已下载的文件
  Future<void> _checkDownloadedFiles() async {
    final downloadService = DownloadService.instance;

    for (final hash in _downloadedFiles.keys) {
      final filePath =
          await downloadService.getDownloadedFilePath(widget.work.id, hash);
      if (filePath != null) {
        _downloadedFiles[hash] = true;
      }
    }

    if (mounted) {
      setState(() {
        _isCheckingDownloads = false;
      });
    }
  }

  // 识别主文件夹并自动展开
  void _identifyAndExpandMainFolder() {
    if (widget.work.children == null || widget.work.children!.isEmpty) {
      return;
    }

    // 检查根目录是否包含音频文件
    final rootHasAudio =
        widget.work.children!.any((item) => item.type == 'file');
    if (rootHasAudio) {
      _mainFolderPath = '';
      return;
    }

    // 统计各文件夹的音频数量
    final Map<String, Map<String, int>> folderStats = {};

    void analyzeFolders(List<AudioFile> items, String parentPath) {
      for (final item in items) {
        if (item.type == 'folder' && item.children != null) {
          final folderPath = _getItemPath(parentPath, item);
          final stats = _countFilesInFolder(item.children!);
          folderStats[folderPath] = stats;
          analyzeFolders(item.children!, folderPath);
        }
      }
    }

    analyzeFolders(widget.work.children!, '');

    if (folderStats.isEmpty) {
      return;
    }

    // 找出音频数量最多的文件夹
    int maxAudioCount = 0;
    String? mainFolder;

    for (final entry in folderStats.entries) {
      if (entry.value['audioCount']! > maxAudioCount) {
        maxAudioCount = entry.value['audioCount']!;
        mainFolder = entry.key;
      }
    }

    if (mainFolder != null) {
      _mainFolderPath = mainFolder;
      _expandPathToFolder(mainFolder);
    }
  }

  // 统计文件夹中的音频文件数量
  Map<String, int> _countFilesInFolder(List<AudioFile> items) {
    int audioCount = 0;
    for (final child in items) {
      if (child.type == 'file') {
        audioCount++;
      }
    }
    return {'audioCount': audioCount};
  }

  // 展开到指定文件夹的路径
  void _expandPathToFolder(String targetPath) {
    final segments = targetPath.split('/');
    String currentPath = '';

    for (int i = 0; i < segments.length; i++) {
      if (i == 0) {
        currentPath = segments[i];
      } else {
        currentPath = '$currentPath/${segments[i]}';
      }
      _expandedFolders.add(currentPath);
    }
  }

  // 生成文件/文件夹的唯一路径
  String _getItemPath(String parentPath, AudioFile item) {
    final title = item.title;
    return parentPath.isEmpty ? title : '$parentPath/$title';
  }

  // 切换文件夹展开/折叠
  void _toggleFolder(String path) {
    setState(() {
      if (_expandedFolders.contains(path)) {
        _expandedFolders.remove(path);
      } else {
        _expandedFolders.add(path);
      }
    });
  }

  // 切换文件选中状态
  void _toggleFile(String hash) {
    setState(() {
      _selectedFiles[hash] = !(_selectedFiles[hash] ?? false);
    });
  }

  // 切换文件夹选中状态（递归）
  void _toggleFolderSelection(String path, bool selected) {
    void selectInChildren(List<AudioFile> items, String parentPath) {
      for (final item in items) {
        final itemPath = _getItemPath(parentPath, item);

        if (item.type == 'file' && item.hash != null) {
          // 只选择未下载的文件
          final isDownloaded = _downloadedFiles[item.hash!] ?? false;
          if (!isDownloaded) {
            _selectedFiles[item.hash!] = selected;
          }
        } else if (item.type == 'folder' && item.children != null) {
          selectInChildren(item.children!, itemPath);
        }
      }
    }

    // 找到目标文件夹并递归选择其中的所有文件
    void findAndSelect(List<AudioFile> items, String currentPath) {
      for (final item in items) {
        final itemPath = _getItemPath(currentPath, item);

        if (itemPath == path && item.children != null) {
          selectInChildren(item.children!, itemPath);
          return;
        }

        if (item.type == 'folder' && item.children != null) {
          findAndSelect(item.children!, itemPath);
        }
      }
    }

    setState(() {
      if (widget.work.children != null) {
        findAndSelect(widget.work.children!, '');
      }
    });
  }

  // 全选/取消全选
  void _toggleSelectAll() {
    // 只考虑未下载的文件
    final availableFiles = _selectedFiles.keys
        .where((hash) => !(_downloadedFiles[hash] ?? false))
        .toList();

    if (availableFiles.isEmpty) return;

    final allSelected =
        availableFiles.every((hash) => _selectedFiles[hash] ?? false);
    setState(() {
      for (final hash in availableFiles) {
        _selectedFiles[hash] = !allSelected;
      }
    });
  }

  // 获取文件夹的选中状态（全选/部分选中/未选中）
  bool? _getFolderSelectionState(AudioFile folder) {
    if (folder.children == null || folder.children!.isEmpty) {
      return false;
    }

    int selectedCount = 0;
    int totalCount = 0;

    void countSelection(List<AudioFile> items) {
      for (final item in items) {
        if (item.type == 'file' && item.hash != null) {
          // 排除已下载的文件
          final isDownloaded = _downloadedFiles[item.hash!] ?? false;
          if (!isDownloaded) {
            totalCount++;
            if (_selectedFiles[item.hash!] ?? false) {
              selectedCount++;
            }
          }
        }
        if (item.children != null) {
          countSelection(item.children!);
        }
      }
    }

    countSelection(folder.children!);

    if (totalCount == 0) {
      return false; // 文件夹中所有文件都已下载
    } else if (selectedCount == 0) {
      return false;
    } else if (selectedCount == totalCount) {
      return true;
    } else {
      return null; // 部分选中
    }
  }

  List<AudioFile> _getSelectedFiles() {
    final selected = <AudioFile>[];

    void processChildren(List<AudioFile> children) {
      for (final file in children) {
        if (file.type == 'file') {
          if (_selectedFiles[file.hash ?? ''] ?? false) {
            selected.add(file);
          }
        } else if (file.children != null) {
          processChildren(file.children!);
        }
      }
    }

    if (widget.work.children != null) {
      processChildren(widget.work.children!);
    }

    return selected;
  }

  void _startDownload() async {
    final selectedFiles = _getSelectedFiles();
    if (selectedFiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请至少选择一个文件')),
        );
      }
      return;
    }

    final downloadService = DownloadService.instance;

    for (final file in selectedFiles) {
      await downloadService.addTask(
        workId: widget.work.id,
        workTitle: widget.work.title,
        fileName: file.title,
        downloadUrl: file.mediaDownloadUrl ?? '',
        hash: file.hash,
        totalBytes: file.size,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${selectedFiles.length} 个文件到下载队列')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 800,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.download,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择下载文件',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.work.title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withAlpha(179),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),

            // Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.select_all, size: 18),
                    label: const Text('全选'),
                    onPressed: _toggleSelectAll,
                  ),
                  const Spacer(),
                  if (!_isCheckingDownloads) ...[
                    Text(
                      '已下载 ${_downloadedFiles.values.where((v) => v).length} 个',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 1,
                      height: 12,
                      color: theme.dividerColor,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '已选择 ${_selectedFiles.values.where((v) => v).length} 个',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(153),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // File List
            Flexible(
              child: _isCheckingDownloads
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('正在检查已下载文件...'),
                        ],
                      ),
                    )
                  : widget.work.children == null ||
                          widget.work.children!.isEmpty
                      ? const Center(
                          child: Text('没有可下载的文件'),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children:
                              _buildFileTree(widget.work.children!, 0, ''),
                        ),
            ),

            const Divider(height: 1),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _startDownload,
                    icon: const Icon(Icons.download),
                    label: Text('下载 (${_getSelectedFiles().length})'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFileTree(
      List<AudioFile> files, int level, String parentPath) {
    final widgets = <Widget>[];
    final theme = Theme.of(context);

    for (final file in files) {
      final itemPath = _getItemPath(parentPath, file);

      if (file.type == 'folder' && file.children != null) {
        final isExpanded = _expandedFolders.contains(itemPath);
        final selectionState = _getFolderSelectionState(file);

        // 文件夹行
        widgets.add(
          InkWell(
            onTap: () => _toggleFolder(itemPath),
            child: Padding(
              padding: EdgeInsets.only(
                left: 4.0 + (level * 16.0),
                right: 4.0,
              ),
              child: Row(
                children: [
                  // 展开/折叠图标
                  SizedBox(
                    width: 32,
                    height: 40,
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      color: theme.colorScheme.onSurface.withAlpha(153),
                      size: 20,
                    ),
                  ),
                  // 复选框
                  SizedBox(
                    width: 32,
                    height: 40,
                    child: Checkbox(
                      value: selectionState,
                      tristate: true,
                      onChanged: (value) {
                        _toggleFolderSelection(itemPath, value ?? false);
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 文件夹图标
                  Icon(
                    FileIconUtils.getFileIcon(file),
                    color: FileIconUtils.getFileIconColor(file),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  // 文件夹名称
                  Expanded(
                    child: Text(
                      file.title,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // 如果展开,显示子项
        if (isExpanded) {
          widgets.addAll(_buildFileTree(file.children!, level + 1, itemPath));
        }
      } else if (file.type == 'file') {
        // 文件行
        final hash = file.hash ?? '';
        final isDownloaded = _downloadedFiles[hash] ?? false;
        final isSelected = _selectedFiles[hash] ?? false;

        widgets.add(
          InkWell(
            onTap: isDownloaded ? null : () => _toggleFile(hash),
            child: Padding(
              padding: EdgeInsets.only(
                left: 4.0 + (level * 16.0),
                right: 4.0,
              ),
              child: Row(
                children: [
                  // 占位（与文件夹的箭头对齐）
                  const SizedBox(width: 32, height: 40),
                  // 复选框或已下载标识
                  SizedBox(
                    width: 32,
                    height: 40,
                    child: isDownloaded
                        ? Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          )
                        : Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleFile(hash),
                          ),
                  ),
                  const SizedBox(width: 4),
                  // 文件图标
                  Icon(
                    FileIconUtils.getFileIcon(file),
                    color: FileIconUtils.getFileIconColor(file),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  // 文件名和大小
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                file.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDownloaded
                                      ? theme.colorScheme.onSurface
                                          .withAlpha(153)
                                      : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isDownloaded) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withAlpha(51),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '已下载',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.green[700],
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (file.size != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            formatBytes(file.size!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(153),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }
}
