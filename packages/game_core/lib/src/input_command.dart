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

  bool has(int bit) => buttons & (1 << bit) != 0;

  InputCommand copyWith({int? tick, int? seq}) => InputCommand(
        tick: tick ?? this.tick,
        seq: seq ?? this.seq,
        moveX: moveX,
        moveY: moveY,
        buttons: buttons,
        aimAngle: aimAngle,
      );
}
