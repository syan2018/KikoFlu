import 'package:flutter/material.dart';
import '../models/sort_options.dart';

class SearchSortDialog extends StatelessWidget {
  final SortOrder currentOption;
  final SortDirection currentDirection;
  final Function(SortOrder, SortDirection) onSort;

  const SearchSortDialog({
    super.key,
    required this.currentOption,
    required this.currentDirection,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('排序'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 动态生成排序选项
            ...SortOrder.values.map((option) {
              return ListTile(
                title: Text(option.label),
                leading: Radio<SortOrder>(
                  value: option,
                  groupValue: currentOption,
                  onChanged: (value) {
                    if (value != null) {
                      onSort(value, currentDirection);
                      Navigator.pop(context);
                    }
                  },
                ),
              );
            }),
            const Divider(),
            // 动态生成排序方向选项
            ...SortDirection.values.map((direction) {
              return ListTile(
                title: Text(direction.label),
                leading: Radio<SortDirection>(
                  value: direction,
                  groupValue: currentDirection,
                  onChanged: (value) {
                    if (value != null) {
                      onSort(currentOption, value);
                      Navigator.pop(context);
                    }
                  },
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
