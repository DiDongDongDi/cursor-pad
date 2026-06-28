class BrowserSettings {
  const BrowserSettings({
    this.viewportWidth = 1280,
    this.cursorSensitivity = 1.0,
    this.scrollSensitivity = 1.0,
    this.homeUrl = 'https://www.google.com',
  });

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
