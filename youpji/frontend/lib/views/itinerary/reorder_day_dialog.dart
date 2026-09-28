import 'package:flutter/material.dart';
import '../../core/constants/theme_constants.dart';
import '../../models/itinerary_model.dart';

class ReorderDayDialog extends StatefulWidget {
  final int dayIndex;
  final List<ItineraryItem> items;
  final Future<void> Function(List<String> orderedAttractionIds) onConfirm;

  const ReorderDayDialog({
    super.key,
    required this.dayIndex,
    required this.items,
    required this.onConfirm,
  });

  @override
  State<ReorderDayDialog> createState() => _ReorderDayDialogState();
}

class _ReorderDayDialogState extends State<ReorderDayDialog> {
  late List<ItineraryItem> _attractions;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // 铁律：仅景区分支节点参与拖拽重排，餐饮与住宿不拖拽
    _attractions = widget.items
        .filter((it) => it.itemType == 'attraction')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('调整第 ${widget.dayIndex + 1} 天游览顺序'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: _attractions.isEmpty
            ? const Center(child: Text('当天无独立景点可拖拽调整'))
            : ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: _attractions.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _attractions.removeAt(oldIndex);
                    _attractions.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final it = _attractions[index];
                  return ListTile(
                    key: ValueKey(it.refId ?? it.title),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      child: Text('${index + 1}', style: const TextStyle(color: AppTheme.primaryBlue)),
                    ),
                    title: Text(it.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${it.startTime ?? ""} ~ ${it.endTime ?? ""} · 预计 ¥${it.cost}'),
                    trailing: const Icon(Icons.drag_handle, color: AppTheme.mutedGray),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting || _attractions.isEmpty
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  final ids = _attractions
                      .map((e) => e.refId)
                      .whereType<String>()
                      .toList();
                  await widget.onConfirm(ids);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('确认并局部重算'),
        ),
      ],
    );
  }
}

extension IterableExtension<T> on Iterable<T> {
  List<T> filter(bool Function(T element) test) {
    return where(test).toList();
  }
}
