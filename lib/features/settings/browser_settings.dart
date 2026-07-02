class BrowserSettings {
  const BrowserSettings({
    this.viewportWidth = 1280,
    this.cursorSensitivity = defaultCursorSensitivity,
    this.scrollSensitivity = defaultScrollSensitivity,
    this.homeUrl = bookmarksHomeUrl,
  });

  static const String bookmarksHomeUrl = 'cursorpad://bookmarks';
  static const double defaultCursorSensitivity = 1.75;
  static const double defaultScrollSensitivity = 2.0;
  static const double minSensitivity = 0.5;
  static const double maxSensitivity = 4.0;
  static const double sensitivityStep = 0.25;

  final int viewportWidth;
  final double cursorSensitivity;
  final double scrollSensitivity;
  final String homeUrl;

  factory BrowserSettings.fromJson(Map<String, dynamic> json) {
    return BrowserSettings(
      cursorSensitivity: _readDouble(
        json['cursorSensitivity'],
        defaultCursorSensitivity,
      ),
      scrollSensitivity: _readDouble(
        json['scrollSensitivity'],
        defaultScrollSensitivity,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cursorSensitivity': cursorSensitivity,
      'scrollSensitivity': scrollSensitivity,
    };
  }

  static double _readDouble(Object? value, double fallback) {
    if (value is num) {
      return value.toDouble().clamp(minSensitivity, maxSensitivity);
    }
    return fallback;
  }

  BrowserSettings copyWith({
    int? viewportWidth,
    double? cursorSensitivity,
    double? scrollSensitivity,
    String? homeUrl,
  }) {
    return BrowserSettings(
      viewportWidth: viewportWidth ?? this.viewportWidth,
      cursorSensitivity: cursorSensitivity ?? this.cursorSensitivity,
      scrollSensitivity: scrollSensitivity ?? this.scrollSensitivity,
      homeUrl: homeUrl ?? this.homeUrl,
    );
  }
}
