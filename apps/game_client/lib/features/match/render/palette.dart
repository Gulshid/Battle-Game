import 'dart:ui';

/// Tint and accent colour per class id (Warrior, Archer, Mage, Dummy).
const List<Color> kClassTint = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFFB8FFB0),
  Color(0xFFE0B8FF),
  Color(0xFFBBBBBB),
];

const List<Color> kClassAccent = <Color>[
  Color(0xFF4FC3F7),
  Color(0xFF81C784),
  Color(0xFFBA68C8),
  Color(0xFF9E9E9E),
];

const Color kLocalRing = Color(0xFF00E5FF);
const Color kEnemyRing = Color(0xFFFF5252);

Color classAccent(int classId) =>
    kClassAccent[classId.clamp(0, kClassAccent.length - 1)];

Color classTint(int classId) =>
    kClassTint[classId.clamp(0, kClassTint.length - 1)];

/// Byte angle (0..255) to radians for canvas drawing.
double angleRad(int a) => a * 6.283185307179586 / 256;
