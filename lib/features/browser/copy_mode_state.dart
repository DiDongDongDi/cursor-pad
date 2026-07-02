/// Tracks whether the user is in copy mode (entered via triple-tap).
class CopyModeState {
  CopyModeState({this.active = false});

  bool active;

  void enter() {
    active = true;
  }

  void exit() {
    active = false;
  }
}
