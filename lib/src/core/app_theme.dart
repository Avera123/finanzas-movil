import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const themeNames = {
  'auto': 'Sistema',
  'oscuro': 'Oscuro',
  'claro': 'Claro',
  'bosque': 'Bosque',
  'oceano': 'Océano',
  'arena': 'Arena'
};
final themeStoreProvider = Provider((ref) => const FlutterSecureStorage());
final themeProvider = StateNotifierProvider<ThemeController, String>(
    (ref) => ThemeController(ref.watch(themeStoreProvider)));

@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({required this.accent});
  final Color accent;
  @override
  FinanceColors copyWith({Color? accent}) =>
      FinanceColors(accent: accent ?? this.accent);
  @override
  FinanceColors lerp(covariant FinanceColors? other, double t) =>
      FinanceColors(accent: Color.lerp(accent, other?.accent ?? accent, t)!);
}

class ThemeController extends StateNotifier<String> {
  ThemeController(this.storage) : super('auto') {
    restore();
  }
  final FlutterSecureStorage storage;
  int revision = 0;
  Future<void> restore() async {
    final before = revision;
    try {
      final saved = await storage.read(key: 'appearance_v1');
      if (mounted && before == revision && themeNames.containsKey(saved)) {
        state = saved!;
      }
    } catch (_) {/* System theme remains usable when storage is unavailable. */}
  }

  Future<bool> select(String value) async {
    if (!themeNames.containsKey(value)) return false;
    revision++;
    try {
      await storage.write(key: 'appearance_v1', value: value);
      if (mounted) state = value;
      return true;
    } catch (_) {
      return false;
    }
  }
}

ThemeData financeTheme(String id, Brightness system) {
  if (id == 'auto') id = system == Brightness.dark ? 'oscuro' : 'claro';
  final light = id == 'claro' || id == 'arena';
  final palette = switch (id) {
    'claro' => [0xFFF5F6F8, 0xFFFFFFFF, 0xFF171B24, 0xFFF2B84B, 0xFF241A05],
    'bosque' => [0xFF0C1410, 0xFF131E18, 0xFFE9F2EC, 0xFF63C98F, 0xFF06210F],
    'oceano' => [0xFF0B1220, 0xFF111B2E, 0xFFE8EEFB, 0xFF7CB8FF, 0xFF04182F],
    'arena' => [0xFFF6F1E7, 0xFFFFFDF8, 0xFF2A2318, 0xFFD9913A, 0xFF1F1405],
    _ => [0xFF0D1016, 0xFF151A23, 0xFFECEFF5, 0xFFF2B84B, 0xFF241A05],
  };
  final scheme = ColorScheme.fromSeed(
          seedColor: Color(palette[3]),
          brightness: light ? Brightness.light : Brightness.dark)
      .copyWith(
          surface: Color(palette[1]),
          onSurface: Color(palette[2]),
          primary: light ? const Color(0xFF794900) : Color(palette[3]),
          onPrimary: light ? Colors.white : Color(palette[4]));
  return ThemeData(
      extensions: [FinanceColors(accent: Color(palette[3]))],
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Color(palette[0]),
      inputDecorationTheme:
          const InputDecorationTheme(border: OutlineInputBorder()),
      cardTheme: const CardThemeData(
          margin: EdgeInsets.only(bottom: 12), elevation: 0));
}
