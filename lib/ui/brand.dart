/// Toolage Works brand: the same tokens as toolageworks.com (public/css/site.css),
/// so every Toolage app looks like part of one family.
library;

import 'package:flutter/material.dart';

class ToolageColors {
  static const navy = Color(0xFF1F2D3A);
  static const slate = Color(0xFF3E5C76);
  static const cyan = Color(0xFF4EB9C9);

  /// Cyan dark enough for text on light backgrounds.
  static const cyanInk = Color(0xFF1D7F8E);
  static const cyanWash = Color(0xFFE6F5F7);
  static const coral = Color(0xFFE8604C);

  /// Coral dark enough for small text on light backgrounds.
  static const coralInk = Color(0xFFC2412D);
  static const bg = Color(0xFFF7FAFB);
  static const paper = Color(0xFFFFFFFF);
  static const muted = Color(0xFF55636F);
  static const line = Color(0xFFD9E4EA);

  // Dark theme, as on the site.
  static const bgDark = Color(0xFF0F1820);
  static const paperDark = Color(0xFF16222D);
  static const inkDark = Color(0xFFE8EEF2);
  static const mutedDark = Color(0xFFA3B1BC);
  static const lineDark = Color(0xFF2A3A48);
  static const cyanInkDark = Color(0xFF6FCAD7);
  static const cyanWashDark = Color(0xFF13303A);
}

/// Font families bundled in assets/fonts (SIL Open Font License).
class ToolageFonts {
  /// Headings, buttons and all app UI.
  static const display = 'Inter';

  /// Longer reading text, like the site's body copy.
  static const body = 'SourceSerif4';
}

/// Colors with a meaning in Pill Time, tuned for light and dark mode.
@immutable
class StatusPalette extends ThemeExtension<StatusPalette> {
  const StatusPalette({
    required this.due,
    required this.tooEarly,
    required this.warning,
    required this.takeBg,
    required this.takeFg,
    required this.idleBg,
    required this.idleFg,
    required this.wash,
  });

  /// "Due now" text and ticks.
  final Color due;

  /// "Not yet / too early" text and icons.
  final Color tooEarly;

  /// Things that need attention, such as an unconfirmed gap.
  final Color warning;

  /// The big TAKE MEDS / SAVE button when a dose is due.
  final Color takeBg;
  final Color takeFg;

  /// The big button when nothing is due.
  final Color idleBg;
  final Color idleFg;

  /// Soft background for banners.
  final Color wash;

  static const light = StatusPalette(
    due: ToolageColors.cyanInk,
    tooEarly: ToolageColors.coralInk,
    warning: ToolageColors.coralInk,
    takeBg: ToolageColors.navy,
    takeFg: Colors.white,
    idleBg: ToolageColors.line,
    idleFg: ToolageColors.muted,
    wash: ToolageColors.cyanWash,
  );

  static const dark = StatusPalette(
    due: ToolageColors.cyanInkDark,
    tooEarly: ToolageColors.coral,
    warning: ToolageColors.coral,
    takeBg: ToolageColors.cyan,
    takeFg: ToolageColors.navy,
    idleBg: ToolageColors.lineDark,
    idleFg: ToolageColors.mutedDark,
    wash: ToolageColors.cyanWashDark,
  );

  @override
  StatusPalette copyWith() => this;

  @override
  StatusPalette lerp(StatusPalette? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

extension StatusPaletteContext on BuildContext {
  StatusPalette get status => Theme.of(this).extension<StatusPalette>()!;
}

ThemeData toolageTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: ToolageColors.navy,
        brightness: brightness,
      ).copyWith(
        primary: dark ? ToolageColors.cyan : ToolageColors.navy,
        onPrimary: dark ? ToolageColors.navy : Colors.white,
        secondary: dark ? ToolageColors.cyanInkDark : ToolageColors.cyanInk,
        tertiary: ToolageColors.coral,
        error: dark ? ToolageColors.coral : ToolageColors.coralInk,
        surface: dark ? ToolageColors.paperDark : ToolageColors.paper,
        onSurface: dark ? ToolageColors.inkDark : ToolageColors.navy,
        onSurfaceVariant: dark ? ToolageColors.mutedDark : ToolageColors.muted,
        outline: dark ? ToolageColors.lineDark : ToolageColors.line,
        outlineVariant: dark ? ToolageColors.lineDark : ToolageColors.line,
      );
  final bg = dark ? ToolageColors.bgDark : ToolageColors.bg;
  final line = dark ? ToolageColors.lineDark : ToolageColors.line;

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: ToolageFonts.display,
    scaffoldBackgroundColor: bg,
  );
  final text = base.textTheme;

  return base.copyWith(
    extensions: [dark ? StatusPalette.dark : StatusPalette.light],
    textTheme: text.copyWith(
      headlineLarge: text.headlineLarge?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: line)),
      titleTextStyle: TextStyle(
        fontFamily: ToolageFonts.display,
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: line),
      ),
    ),
    dividerTheme: DividerThemeData(color: line),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: ToolageFonts.display,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.primary, width: 2),
        foregroundColor: scheme.onSurface,
        textStyle: const TextStyle(
          fontFamily: ToolageFonts.display,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: dark
            ? ToolageColors.cyanInkDark
            : ToolageColors.cyanInk,
        textStyle: const TextStyle(
          fontFamily: ToolageFonts.display,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ToolageColors.cyan, width: 3),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: dark
            ? ToolageColors.cyanWashDark
            : ToolageColors.cyanWash,
        selectedForegroundColor: scheme.onSurface,
        side: BorderSide(color: line),
        textStyle: const TextStyle(
          fontFamily: ToolageFonts.display,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ToolageColors.navy,
      contentTextStyle: TextStyle(
        fontFamily: ToolageFonts.display,
        color: Colors.white,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

/// "that WORKS for you", with WORKS styled like the website.
TextSpan _slogan(BuildContext context) => TextSpan(
  children: [
    const TextSpan(text: 'that '),
    TextSpan(
      text: 'WORKS',
      style: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
        color: context.status.due,
      ),
    ),
    const TextSpan(text: ' for you'),
  ],
);

/// App bar title for Toolage apps: the app name, with
/// "by Toolage · that WORKS for you" underneath.
class ToolageTitle extends StatelessWidget {
  const ToolageTitle({super.key, required this.appName, this.slogan = true});
  final String appName;
  final bool slogan;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(appName),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontFamily: ToolageFonts.display,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
                color: muted,
              ),
              children: [
                const TextSpan(text: 'by '),
                const TextSpan(
                  text: 'Toolage',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                if (slogan) ...[
                  const TextSpan(text: '  ·  '),
                  _slogan(context),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Sign-off for the bottom of a settings or about screen:
/// "Pill Time by Toolage", "that WORKS for you", "toolageworks.com".
class ToolageSignoff extends StatelessWidget {
  const ToolageSignoff({super.key, required this.appName});
  final String appName;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: muted),
        textAlign: TextAlign.center,
        child: Column(
          children: [
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 18),
                children: [
                  TextSpan(text: '$appName by '),
                  const TextSpan(
                    text: 'Toolage',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 15),
                children: [_slogan(context)],
              ),
            ),
            const SizedBox(height: 4),
            const Text('toolageworks.com', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
