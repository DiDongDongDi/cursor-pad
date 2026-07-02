import 'package:flutter/material.dart';

import 'browser_settings.dart';

class BrowserSettingsSheet extends StatefulWidget {
  const BrowserSettingsSheet({
    super.key,
    required this.initialSettings,
  });

  final BrowserSettings initialSettings;

  @override
  State<BrowserSettingsSheet> createState() => _BrowserSettingsSheetState();
}

class _BrowserSettingsSheetState extends State<BrowserSettingsSheet> {
  late double _cursorSensitivity;
  late double _scrollSensitivity;

  @override
  void initState() {
    super.initState();
    _cursorSensitivity = widget.initialSettings.cursorSensitivity;
    _scrollSensitivity = widget.initialSettings.scrollSensitivity;
  }

  int get _divisions =>
      ((BrowserSettings.maxSensitivity - BrowserSettings.minSensitivity) /
              BrowserSettings.sensitivityStep)
          .round();

  void _resetDefaults() {
    setState(() {
      _cursorSensitivity = BrowserSettings.defaultCursorSensitivity;
      _scrollSensitivity = BrowserSettings.defaultScrollSensitivity;
    });
  }

  void _save() {
    Navigator.of(context).pop(
      widget.initialSettings.copyWith(
        cursorSensitivity: _cursorSensitivity,
        scrollSensitivity: _scrollSensitivity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '设置',
                style: theme.textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                tooltip: '恢复默认',
                onPressed: _resetDefaults,
                icon: const Icon(Icons.restore),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SensitivitySlider(
            label: '鼠标移动速度',
            value: _cursorSensitivity,
            divisions: _divisions,
            onChanged: (value) => setState(() => _cursorSensitivity = value),
          ),
          const SizedBox(height: 16),
          _SensitivitySlider(
            label: '页面拖动速度',
            value: _scrollSensitivity,
            divisions: _divisions,
            onChanged: (value) => setState(() => _scrollSensitivity = value),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _SensitivitySlider extends StatelessWidget {
  const _SensitivitySlider({
    required this.label,
    required this.value,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              value.toStringAsFixed(2),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: BrowserSettings.minSensitivity,
          max: BrowserSettings.maxSensitivity,
          divisions: divisions,
          label: value.toStringAsFixed(2),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
