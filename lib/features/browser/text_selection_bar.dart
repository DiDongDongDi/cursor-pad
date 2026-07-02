import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TextSelectionBar extends StatelessWidget {
  const TextSelectionBar({
    super.key,
    required this.previewText,
    required this.onCopy,
    required this.onSelectAll,
    required this.onDismiss,
    this.hintText = '拖动扩展选区',
  });

  final String previewText;
  final String hintText;
  final VoidCallback onCopy;
  final VoidCallback onSelectAll;
  final VoidCallback onDismiss;

  static String preview(String text, {int maxLength = 20}) {
    if (text.isEmpty) {
      return '';
    }
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}…';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasText = previewText.isNotEmpty;
    final displayText = hasText ? preview(previewText) : hintText;

    return Material(
      elevation: 6,
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.content_copy,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '复制模式',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    displayText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: hasText
                              ? null
                              : colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onSelectAll,
              child: const Text('全选'),
            ),
            FilledButton.tonal(
              onPressed: hasText ? onCopy : null,
              child: const Text('复制'),
            ),
            IconButton(
              tooltip: '退出复制模式',
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
