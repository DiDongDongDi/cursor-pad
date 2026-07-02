enum TextSelectionTapAction {
  beginSelection,
  endSelection,
  clickWithoutSelection,
  ignore,
}

enum TextSelectionCancelReason {
  scroll,
  longPress,
  back,
  timeout,
  manual,
  navigation,
}

class TextSelectionState {
  TextSelectionState({
    this.armed = false,
    this.dragged = false,
    this.pendingAutoClick = false,
  });

  bool armed;
  bool dragged;
  bool pendingAutoClick;

  TextSelectionTapAction onTap() {
    if (armed) {
      if (dragged) {
        return TextSelectionTapAction.endSelection;
      }
      return TextSelectionTapAction.clickWithoutSelection;
    }
    return TextSelectionTapAction.beginSelection;
  }

  void onBeginSelection() {
    armed = true;
    dragged = false;
    pendingAutoClick = true;
  }

  void onDrag() {
    if (!armed) {
      return;
    }
    dragged = true;
    pendingAutoClick = false;
  }

  void onAutoClickTimer() {
    if (!armed || dragged) {
      return;
    }
    pendingAutoClick = false;
  }

  void onCancel({TextSelectionCancelReason reason = TextSelectionCancelReason.manual}) {
    armed = false;
    dragged = false;
    pendingAutoClick = false;
  }

  void onSelectionCommitted() {
    armed = false;
    dragged = false;
    pendingAutoClick = false;
  }

  bool get shouldAutoClick =>
      armed && pendingAutoClick && !dragged;
}
