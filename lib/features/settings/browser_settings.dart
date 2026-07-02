class BrowserSettings {
  const BrowserSettings({
    this.viewportWidth = 1280,
    this.cursorSensitivity = 1.75,
    this.scrollSensitivity = 2.0,
    this.homeUrl = bookmarksHomeUrl,
  });

  static const String bookmarksHomeUrl = 'cursorpad://bookmarks';

  final int viewportWidth;
  final double cursorSensitivity;
  final double scrollSensitivity;
  final String homeUrl;

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
