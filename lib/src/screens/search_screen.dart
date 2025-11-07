import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/work.dart';
import '../models/search_type.dart';
import '../providers/auth_provider.dart';
import '../widgets/tag_chip.dart';
import '../widgets/va_chip.dart';
import 'search_result_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();

  List<Tag> _allTags = [];
  List<Va> _allVas = [];
  Tag? _selectedTag;
  Va? _selectedVa;

  SearchType _searchType = SearchType.keyword;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _loadTagsAndVas();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    if (_searchType == SearchType.rjNumber) {
      final text = _searchController.text.trim();
      if (text.length == 6 && int.tryParse(text) != null) {
        _search();
      }
    }
  }

  Future<void> _loadTagsAndVas() async {
    try {
      final apiService = ref.read(kikoeruApiServiceProvider);
      final tags = await apiService.getAllTags();
      final vas = await apiService.getAllVas();

      if (mounted) {
        setState(() {
          _allTags = tags.map((json) => Tag.fromJson(json)).toList();
          _allVas = vas.map((json) => Va.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print('Failed to load tags and vas: -Forcee');
    }
  }

  Future<void> _search() async {
    if (!_validateSearch()) return;

    // 准备搜索参数
    String keyword = '';
    String searchTypeLabel = '';
    Map<String, dynamic> searchParams = {};

    switch (_searchType) {
      case SearchType.rjNumber:
        keyword = _searchController.text.trim();
        searchTypeLabel = 'RJ号';
        searchParams = {'rjNumber': keyword};
        break;
      case SearchType.va:
        if (_selectedVa == null) return;
        keyword = _selectedVa!.name;
        searchTypeLabel = '声优';
        searchParams = {'vaId': _selectedVa!.id, 'vaName': _selectedVa!.name};
        break;
      case SearchType.tag:
        if (_selectedTag == null) return;
        keyword = _selectedTag!.name;
        searchTypeLabel = '标签';
        searchParams = {
          'tagId': _selectedTag!.id,
          'tagName': _selectedTag!.name
        };
        break;
      case SearchType.keyword:
      default:
        keyword = _searchController.text.trim();
        if (keyword.isEmpty) return;
        searchTypeLabel = '关键词';
        searchParams = {'keyword': keyword};
        break;
    }

    // 跳转到搜索结果页面
    print(
        '[Search] Navigating to SearchResultScreen with keyword: $keyword, type: $searchTypeLabel');
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultScreen(
            keyword: keyword,
            searchTypeLabel: searchTypeLabel,
            searchParams: searchParams,
          ),
        ),
      );
      print('[Search] Navigation completed');
    } else {
      print('[Search] Widget not mounted, navigation skipped');
    }
  }

  bool _validateSearch() {
    switch (_searchType) {
      case SearchType.rjNumber:
        final text = _searchController.text.trim();
        if (text.isEmpty) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('请输入RJ号')));
          return false;
        }
        if (text.length != 6 || int.tryParse(text) == null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('RJ号必须是6位数字')));
          return false;
        }
        return true;
      case SearchType.va:
        if (_selectedVa == null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('请选择声优')));
          return false;
        }
        return true;
      case SearchType.tag:
        if (_selectedTag == null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('请选择标签')));
          return false;
        }
        return true;
      case SearchType.keyword:
      default:
        return true;
    }
  }

  void _showSearchTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择搜索类型'),
        children: SearchType.values.map((type) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() {
                _searchType = type;
                _searchController.clear();
                _selectedTag = null;
                _selectedVa = null;
              });
              Navigator.pop(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  if (_searchType == type)
                    const Icon(Icons.check, color: Colors.blue),
                  if (_searchType == type) const SizedBox(width: 8),
                  Text(type.label),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _showTagSelector() async {
    final selected = await showDialog<Tag>(
        context: context,
        builder: (context) => _TagSelectorDialog(tags: _allTags));
    if (selected != null) {
      setState(() {
        _selectedTag = selected;
      });
      _search();
    }
  }

  Future<void> _showVaSelector() async {
    final selected = await showDialog<Va>(
        context: context,
        builder: (context) => _VaSelectorDialog(vas: _allVas));
    if (selected != null) {
      setState(() {
        _selectedVa = selected;
      });
      _search();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_searchType.label),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                    onPressed: _showSearchTypeDialog,
                    icon: const Icon(Icons.tune),
                    tooltip: '切换搜索类型'),
                const SizedBox(width: 8),
                Expanded(child: _buildSearchInput()),
                const SizedBox(width: 8),
                if (_searchType != SearchType.rjNumber)
                  IconButton(
                      onPressed: _search,
                      icon: const Icon(Icons.search),
                      tooltip: '搜索'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_selectedTag != null || _selectedVa != null)
            Container(
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_selectedTag != null)
                      TagChip(
                          tag: _selectedTag!,
                          onDeleted: () {
                            setState(() {
                              _selectedTag = null;
                            });
                          }),
                    if (_selectedVa != null)
                      VaChip(
                          va: _selectedVa!,
                          onDeleted: () {
                            setState(() {
                              _selectedVa = null;
                            });
                          }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchInput() {
    switch (_searchType) {
      case SearchType.rjNumber:
        return TextField(
          controller: _searchController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6)
          ],
          decoration: InputDecoration(
              hintText: _searchType.hint,
              prefixIcon: const Icon(Icons.tag),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
        );
      case SearchType.va:
        return InkWell(
          onTap: _showVaSelector,
          child: InputDecorator(
            decoration: InputDecoration(
                hintText: _searchType.hint,
                prefixIcon: const Icon(Icons.person),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
            child: Text(_selectedVa?.name ?? _searchType.hint,
                style: TextStyle(
                    color: _selectedVa == null
                        ? Theme.of(context).hintColor
                        : Theme.of(context).textTheme.bodyLarge?.color)),
          ),
        );
      case SearchType.tag:
        return InkWell(
          onTap: _showTagSelector,
          child: InputDecorator(
            decoration: InputDecoration(
                hintText: _searchType.hint,
                prefixIcon: const Icon(Icons.label),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
            child: Text(_selectedTag?.name ?? _searchType.hint,
                style: TextStyle(
                    color: _selectedTag == null
                        ? Theme.of(context).hintColor
                        : Theme.of(context).textTheme.bodyLarge?.color)),
          ),
        );
      case SearchType.keyword:
      default:
        return TextField(
          controller: _searchController,
          decoration: InputDecoration(
              hintText: _searchType.hint,
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
          onSubmitted: (_) => _search(),
        );
    }
  }
}

class _TagSelectorDialog extends StatefulWidget {
  final List<Tag> tags;
  const _TagSelectorDialog({required this.tags});
  @override
  State<_TagSelectorDialog> createState() => _TagSelectorDialogState();
}

class _TagSelectorDialogState extends State<_TagSelectorDialog> {
  final _searchController = TextEditingController();
  List<Tag> _filteredTags = [];

  @override
  void initState() {
    super.initState();
    _filteredTags = widget.tags;
    _searchController.addListener(_filterTags);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterTags() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTags = widget.tags;
      } else {
        _filteredTags = widget.tags
            .where((tag) => tag.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        children: [
          Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                      hintText: '搜索标签...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder()))),
          Expanded(
              child: ListView.builder(
                  itemCount: _filteredTags.length,
                  itemBuilder: (context, index) {
                    final tag = _filteredTags[index];
                    return ListTile(
                        title: Text(tag.name),
                        onTap: () => Navigator.pop(context, tag));
                  })),
        ],
      ),
    );
  }
}

class _VaSelectorDialog extends StatefulWidget {
  final List<Va> vas;
  const _VaSelectorDialog({required this.vas});
  @override
  State<_VaSelectorDialog> createState() => _VaSelectorDialogState();
}

class _VaSelectorDialogState extends State<_VaSelectorDialog> {
  final _searchController = TextEditingController();
  List<Va> _filteredVas = [];

  @override
  void initState() {
    super.initState();
    _filteredVas = widget.vas;
    _searchController.addListener(_filterVas);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterVas() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredVas = widget.vas;
      } else {
        _filteredVas = widget.vas
            .where((va) => va.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        children: [
          Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                      hintText: '搜索声优...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder()))),
          Expanded(
              child: ListView.builder(
                  itemCount: _filteredVas.length,
                  itemBuilder: (context, index) {
                    final va = _filteredVas[index];
                    return ListTile(
                        title: Text(va.name),
                        onTap: () => Navigator.pop(context, va));
                  })),
        ],
      ),
    );
  }
}
