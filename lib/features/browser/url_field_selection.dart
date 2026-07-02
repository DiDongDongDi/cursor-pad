import 'package:flutter/material.dart';

/// Layout constants matching [BrowserToolbar] URL TextField.
const urlFieldContentPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 10);

const urlFieldHeight = 40.0;

TextStyle urlFieldDisplayStyle(BuildContext context) {
  final theme = Theme.of(context);
  final base = theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
  final linkColor = theme.colorScheme.primary;
  return base.copyWith(
    color: linkColor,
    decoration: TextDecoration.underline,
    decorationColor: linkColor,
    decorationThickness: 1.5,
  );
}

void selectAllUrlText({
  required TextEditingController controller,
  required FocusNode focusNode,
  required bool mounted,
}) {
  final length = controller.text.length;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !focusNode.hasFocus) {
      return;
    }
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: length,
    );
  });
}

void placeUrlCaretAtOffset({
  required TextEditingController controller,
  required int offset,
}) {
  final length = controller.text.length;
  final clamped = offset.clamp(0, length);
  controller.selection = TextSelection.collapsed(offset: clamped);
}

void applyUrlFieldSingleTapSelection({
  required TextEditingController controller,
  required FocusNode focusNode,
  required bool mounted,
  required bool alreadyFocused,
  int? tapOffset,
}) {
  if (!alreadyFocused) {
    selectAllUrlText(
      controller: controller,
      focusNode: focusNode,
      mounted: mounted,
    );
    return;
  }

  final fallback = controller.selection.extentOffset;
  placeUrlCaretAtOffset(
    controller: controller,
    offset: tapOffset ?? fallback,
  );
}

bool isUrlWordChar(String char) {
  if (char.isEmpty) {
    return false;
  }
  final code = char.codeUnitAt(0);
  return (code >= 0x30 && code <= 0x39) ||
      (code >= 0x41 && code <= 0x5A) ||
      (code >= 0x61 && code <= 0x7A) ||
      char == '_' ||
      char == '-';
}

TextSelection wordSelectionAt(String text, int offset) {
  if (text.isEmpty) {
    return const TextSelection.collapsed(offset: 0);
  }

  final clamped = offset.clamp(0, text.length);
  var probe = clamped == text.length ? text.length - 1 : clamped;

  if (!isUrlWordChar(text[probe])) {
    var left = probe;
    while (left > 0 && !isUrlWordChar(text[left])) {
      left--;
    }
    if (isUrlWordChar(text[left])) {
      probe = left;
    } else {
      var right = probe;
      while (right < text.length - 1 && !isUrlWordChar(text[right])) {
        right++;
      }
      if (isUrlWordChar(text[right])) {
        probe = right;
      } else {
        final end = (clamped + 1).clamp(0, text.length);
        return TextSelection(baseOffset: clamped, extentOffset: end);
      }
    }
  }

  var start = probe;
  var end = probe + 1;
  while (start > 0 && isUrlWordChar(text[start - 1])) {
    start--;
  }
  while (end < text.length && isUrlWordChar(text[end])) {
    end++;
  }
  return TextSelection(baseOffset: start, extentOffset: end);
}

int? textOffsetAtGlobalX({
  required String text,
  required Offset globalPoint,
  required RenderBox fieldBox,
  required TextStyle style,
  EdgeInsets contentPadding = urlFieldContentPadding,
}) {
  final local = fieldBox.globalToLocal(globalPoint);
  final innerWidth = (fieldBox.size.width - contentPadding.horizontal)
      .clamp(0.0, double.infinity);
  if (innerWidth <= 0) {
    return text.isEmpty ? 0 : text.length.clamp(0, text.length);
  }

  final textDx = (local.dx - contentPadding.left).clamp(0.0, innerWidth);
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout(maxWidth: innerWidth);

  final verticalCenter = fieldBox.size.height / 2;
  final position = painter.getPositionForOffset(
    Offset(textDx, verticalCenter - painter.height / 2),
  );
  if (text.isEmpty) {
    return 0;
  }
  if (textDx >= painter.width) {
    return text.length;
  }
  return position.offset.clamp(0, text.length);
}

TextSelection selectionFromAnchor(int anchor, int extent, int textLength) {
  final base = anchor.clamp(0, textLength);
  final end = extent.clamp(0, textLength);
  return TextSelection(baseOffset: base, extentOffset: end);
}

String selectedTextFromSelection(String text, TextSelection selection) {
  if (!selection.isValid) {
    return '';
  }
  return selection.textInside(text);
}
