import 'package:flutter/material.dart';

class AppConfig {
  static const String name = 'ConsistIQ';
  static const String tagline = 'Build routines. Protect your streak.';
}

/// Glass design tokens that change with dark/light mode.
@immutable
class GlassColors extends ThemeExtension<GlassColors> {
  final Color tintTop;
  final Color tintBottom;
  final Color border;
  final Color text;
  final Color subText;
  final List<Color> background; // 3 colors

  const GlassColors({
    required this.tintTop,
    required this.tintBottom,
    required this.border,
    required this.text,
    required this.subText,
    required this.background,
  });

  static const dark = GlassColors(
    tintTop: Color(0x2EFFFFFF),
    tintBottom: Color(0x0AFFFFFF),
    border: Color(0x4DFFFFFF),
    text: Colors.white,
    subText: Color(0xA6FFFFFF),
    background: [Color(0xFF050B1F), Color(0xFF0B1B4D), Color(0xFF0A0F2C)],
  );

  static const light = GlassColors(
    tintTop: Color(0xA6FFFFFF),
    tintBottom: Color(0x40FFFFFF),
    border: Color(0xCCFFFFFF),
    text: Color(0xFF0B1B4D),
    subText: Color(0xA60B1B4D),
    background: [Color(0xFFEAF2FF), Color(0xFFD6E6FF), Color(0xFFF1EAFF)],
  );

  @override
  GlassColors copyWith({
    Color? tintTop,
    Color? tintBottom,
    Color? border,
    Color? text,
    Color? subText,
    List<Color>? background,
  }) => GlassColors(
    tintTop: tintTop ?? this.tintTop,
    tintBottom: tintBottom ?? this.tintBottom,
    border: border ?? this.border,
    text: text ?? this.text,
    subText: subText ?? this.subText,
    background: background ?? this.background,
  );

  @override
  GlassColors lerp(ThemeExtension<GlassColors>? other, double t) {
    if (other is! GlassColors) return this;
    return GlassColors(
      tintTop: Color.lerp(tintTop, other.tintTop, t)!,
      tintBottom: Color.lerp(tintBottom, other.tintBottom, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      subText: Color.lerp(subText, other.subText, t)!,
      background: List.generate(
        3,
        (i) => Color.lerp(background[i], other.background[i], t)!,
      ),
    );
  }
}

extension GlassContext on BuildContext {
  GlassColors get glass => Theme.of(this).extension<GlassColors>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  static const Color blue = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color cyan = Color(0xFF06B6D4);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.dark,
    ),
    extensions: const [GlassColors.dark],
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.light,
    ),
    extensions: const [GlassColors.light],
  );
}
