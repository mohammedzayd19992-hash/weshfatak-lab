import 'package:flutter/material.dart';

import 'app_name.dart';

/// UniNews colors: night green surfaces, the university green and a sand accent.
abstract final class Brand {
  static const night = Color(0xFF050907);
  static const surface = Color(0xFF0B120E);
  static const surfaceHigh = Color(0xFF111B16);
  static const surfaceHigher = Color(0xFF17241D);
  static const line = Color(0xFF1D2B23);
  static const lineStrong = Color(0xFF2B3E33);
  static const green = Color(0xFF1B8354);
  static const greenDeep = Color(0xFF0E5536);
  static const mint = Color(0xFF66D49C);
  static const sand = Color(0xFFD6BD88);
  static const ink = Color(0xFFE9EFEB);
  static const inkSoft = Color(0xFFC3CEC7);
  static const muted = Color(0xFF85958B);
  static const danger = Color(0xFFF2877B);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: Brand.green,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF123D2A),
    onPrimaryContainer: Brand.mint,
    secondary: Brand.sand,
    onSecondary: Color(0xFF231A06),
    surface: Brand.surface,
    onSurface: Brand.ink,
    onSurfaceVariant: Brand.muted,
    surfaceContainerLowest: Brand.night,
    surfaceContainerLow: Brand.surface,
    surfaceContainer: Brand.surfaceHigh,
    surfaceContainerHigh: Brand.surfaceHigher,
    surfaceContainerHighest: Color(0xFF1D2C24),
    outline: Brand.lineStrong,
    outlineVariant: Brand.line,
    error: Brand.danger,
    onError: Color(0xFF2B0A06),
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
  );
  final field = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Brand.line),
  );
  return base.copyWith(
    scaffoldBackgroundColor: Brand.night,
    dividerColor: Brand.line,
    textTheme: base.textTheme.apply(
      bodyColor: Brand.ink,
      displayColor: Brand.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Brand.night,
      foregroundColor: Brand.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Brand.ink,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.green,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Brand.green.withValues(alpha: 0.45),
        minimumSize: const Size(64, 52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Brand.ink,
        minimumSize: const Size(64, 52),
        side: const BorderSide(color: Brand.lineStrong),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Brand.mint,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Brand.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: field,
      enabledBorder: field,
      focusedBorder: field.copyWith(
        borderSide: const BorderSide(color: Brand.mint, width: 1.6),
      ),
      errorBorder: field.copyWith(
        borderSide: const BorderSide(color: Brand.danger),
      ),
      focusedErrorBorder: field.copyWith(
        borderSide: const BorderSide(color: Brand.danger, width: 1.6),
      ),
      labelStyle: const TextStyle(color: Brand.muted),
      hintStyle: const TextStyle(color: Brand.muted),
      prefixIconColor: Brand.muted,
      suffixIconColor: Brand.muted,
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Brand.surfaceHigh,
      selectedColor: Brand.green,
      side: BorderSide(color: Brand.line),
      shape: StadiumBorder(),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: Brand.inkSoft,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Brand.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Brand.lineStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Brand.surfaceHigher,
      contentTextStyle: const TextStyle(color: Brand.ink),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Brand.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Brand.mint),
  );
}

/// A palm tree drawn in an [s] by [s] box: a curved trunk and six fronds.
Path palmPath(double s) {
  final path = Path()
    ..moveTo(s * 0.46, s)
    ..quadraticBezierTo(s * 0.43, s * 0.72, s * 0.48, s * 0.44)
    ..lineTo(s * 0.56, s * 0.44)
    ..quadraticBezierTo(s * 0.52, s * 0.72, s * 0.58, s)
    ..close();
  final crown = Offset(s * 0.52, s * 0.42);
  // Tip position, how high the frond arches, and how wide it is (fractions of s).
  const fronds = [
    (0.00, 0.62, 0.20, 0.09),
    (0.04, 0.30, 0.14, 0.10),
    (0.30, 0.04, 0.06, 0.09),
    (0.74, 0.04, 0.06, 0.09),
    (1.00, 0.30, 0.14, 0.10),
    (1.02, 0.62, 0.20, 0.09),
  ];
  for (final (x, y, arch, width) in fronds) {
    final tip = Offset(s * x, s * y);
    final middle = Offset(
      (crown.dx + tip.dx) / 2,
      (crown.dy + tip.dy) / 2 - s * arch,
    );
    path
      ..moveTo(crown.dx, crown.dy)
      ..quadraticBezierTo(middle.dx, middle.dy - s * width, tip.dx, tip.dy)
      ..quadraticBezierTo(middle.dx, middle.dy + s * width, crown.dx, crown.dy)
      ..close();
  }
  return path;
}

/// The faint palm pattern behind every screen.
class PalmBackdrop extends StatelessWidget {
  const PalmBackdrop({super.key, required this.child, this.opacity = 0.05});

  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(painter: _PalmPatternPainter(opacity)),
        ),
      ),
      child,
    ],
  );
}

class _PalmPatternPainter extends CustomPainter {
  const _PalmPatternPainter(this.opacity);

  final double opacity;
  static const _tile = 120.0;
  static const _palm = 28.0;
  // Two palms per tile, each turned a little, so the pattern feels hand placed.
  static const _spots = [(0.2, 0.22, -0.28), (0.66, 0.68, 0.22)];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Brand.sand.withValues(alpha: opacity);
    final palm = palmPath(_palm);
    for (var row = 0; row * _tile < size.height + _tile; row++) {
      final shift = row.isOdd ? _tile / 2 : 0.0;
      for (var x = -_tile; x < size.width + _tile; x += _tile) {
        for (final (dx, dy, turn) in _spots) {
          canvas
            ..save()
            ..translate(x + shift + dx * _tile, row * _tile + dy * _tile)
            ..rotate(turn)
            ..translate(-_palm / 2, -_palm / 2)
            ..drawPath(palm, paint)
            ..restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PalmPatternPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

/// The UniNews app icon (the same artwork as the launcher icon).
class UniLogo extends StatelessWidget {
  const UniLogo({super.key, this.size = 36, this.glow = false});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: glow
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.22),
            boxShadow: [
              BoxShadow(
                color: Brand.green.withValues(alpha: 0.45),
                blurRadius: size * 0.6,
                spreadRadius: size * 0.04,
              ),
            ],
          )
        : null,
    child: Image.asset(
      'assets/icon/uninews.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: appName(context),
    ),
  );
}

/// The news source's picture, or the UniNews mark when it has none.
class SourceAvatar extends StatelessWidget {
  const SourceAvatar({super.key, this.url, this.size = 44});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url == null) return UniLogo(size: size);
    return Container(
      width: size,
      height: size,
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Brand.sand.withValues(alpha: 0.45)),
      ),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Brand.greenDeep,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => UniLogo(size: size),
      ),
    );
  }
}

/// A member's first initial on a color picked from their account id.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.name,
    required this.seed,
    this.size = 36,
  });

  final String name;
  final String seed;
  final double size;

  static const _colors = [
    Color(0xFF1B8354),
    Color(0xFF2D6E9B),
    Color(0xFF94622E),
    Color(0xFF6A51A3),
    Color(0xFFA13F55),
    Color(0xFF3B7D6C),
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty
        ? '?'
        : trimmed.characters.first.toUpperCase();
    final color =
        _colors[seed.codeUnits.fold(0, (a, b) => a + b) % _colors.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.15)!, color],
        ),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

const categoryIcons = {
  'Academic': Icons.menu_book_outlined,
  'Administrative': Icons.account_balance_outlined,
  'Activities': Icons.celebration_outlined,
  'Exams': Icons.edit_note_outlined,
};

/// Short audience names so every choice fits in the bottom bar without scrolling.
const audienceLabels = {
  'Students': 'Students',
  'Teaching Staff': 'Faculty',
  'Administrative Staff': 'Staff',
};
