class BrowserState {
  const BrowserState({
    this.currentUrl = '',
    this.isLoading = false,
    this.progress = 0,
    this.canGoBack = false,
    this.canGoForward = false,
    this.title = '',
  });

  final String currentUrl;
  final bool isLoading;
  final int progress;
  final bool canGoBack;
  final bool canGoForward;
  final String title;

  BrowserState copyWith({
    String? currentUrl,
    bool? isLoading,
    int? progress,
    bool? canGoBack,
    bool? canGoForward,
    String? title,
  }) {
    return BrowserState(
      currentUrl: currentUrl ?? this.currentUrl,
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
      title: title ?? this.title,
    );
  }
}
