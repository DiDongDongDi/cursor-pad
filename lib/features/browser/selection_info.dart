class SelectionInfo {
  const SelectionInfo({
    required this.text,
    required this.isCollapsed,
    required this.length,
  });

  final String text;
  final bool isCollapsed;
  final int length;

  bool get hasText => text.isNotEmpty;

  factory SelectionInfo.fromJson(Map<String, dynamic> json) {
    final text = json['text'];
    return SelectionInfo(
      text: text is String ? text : '',
      isCollapsed: json['isCollapsed'] == true,
      length: json['length'] is num ? (json['length'] as num).toInt() : 0,
    );
  }

  static SelectionInfo? tryParse(dynamic raw) {
    if (raw == null) {
      return null;
    }
    try {
      if (raw is Map<String, dynamic>) {
        return SelectionInfo.fromJson(raw);
      }
      if (raw is Map) {
        return SelectionInfo.fromJson(raw.cast<String, dynamic>());
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
