import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TextSelectionBar extends StatelessWidget {
  const TextSelectionBar({
    super.key,
    required this.previewText,
    required this.onCopy,
    required this.onSelectAll,
    required this.onDismiss,
  });

  final String previewText;
  final VoidCallback onCopy;
  final VoidCallback onSelectAll;
  final VoidCallback onDismiss;

  static String preview(String text, {int maxLength = 20}) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}…';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 6,
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                preview(previewText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onSelectAll,
              child: const Text('全选'),
            ),
            FilledButton.tonal(
              onPressed: onCopy,
              child: const Text('复制'),
            ),
            IconButton(
              tooltip: '取消选区',
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> copyToClipboard(
    BuildContext context,
    String text,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }
}
