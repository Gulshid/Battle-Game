/// Platform-independent input. This struct is also the network payload.
class InputCommand {
  const InputCommand({
    required this.tick,
    required this.seq,
    this.moveX = 0, // -127..127
    this.moveY = 0, // -127..127
    this.buttons = 0, // bit0 attack, bit1 ability1, bit2 ability2, bit3 dash
    this.aimAngle = 0, // 0..255 maps to 0..2*pi
  });

  final int tick;
  final int seq;
  final int moveX;
  final int moveY;
  final int buttons;
  final int aimAngle;

  static const idle = InputCommand(tick: 0, seq: 0);

  /// True if button [bit] (kBtnAttack and friends) is held.
  bool has(int bit) => (buttons >> bit) & 1 == 1;

  /// Same controls, ignoring tick and seq. Used by replay compression.
  bool sameControls(InputCommand o) =>
      moveX == o.moveX &&
      moveY == o.moveY &&
      buttons == o.buttons &&
      aimAngle == o.aimAngle;

  InputCommand copyWith({
    int? tick,
    int? seq,
    int? moveX,
    int? moveY,
    int? buttons,
    int? aimAngle,
  }) =>
      InputCommand(
        tick: tick ?? this.tick,
        seq: seq ?? this.seq,
        moveX: moveX ?? this.moveX,
        moveY: moveY ?? this.moveY,
        buttons: buttons ?? this.buttons,
        aimAngle: aimAngle ?? this.aimAngle,
      );
}
