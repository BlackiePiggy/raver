import 'dart:ui';

class LearnGenreThemePalette {
  LearnGenreThemePalette._();

  static const Map<String, Color> _genreColors = {
    'House': Color(0xFFE74C3C),
    'Techno': Color(0xFF2C3E50),
    'Trance': Color(0xFF3498DB),
    'Drum & Bass': Color(0xFFE67E22),
    'Dubstep': Color(0xFF8E44AD),
    'Hardstyle': Color(0xFFC0392B),
    'Ambient': Color(0xFF1ABC9C),
    'Breakbeat': Color(0xFFF39C12),
    'Garage': Color(0xFF27AE60),
    'Downtempo': Color(0xFF16A085),
    'Electro': Color(0xFF2980B9),
    'Industrial': Color(0xFF7F8C8D),
    'Jungle': Color(0xFF2ECC71),
    'Hardcore': Color(0xFFD35400),
    'Progressive': Color(0xFF9B59B6),
    'Psytrance': Color(0xFF1ABC9C),
    'Minimal': Color(0xFF95A5A6),
    'Deep House': Color(0xFFE91E63),
    'Tech House': Color(0xFFFF5722),
    'Future Bass': Color(0xFF00BCD4),
  };

  static const List<Color> _fallbackPalette = [
    Color(0xFF6B42DB),
    Color(0xFF8C5CF5),
    Color(0xFFAB7AFF),
    Color(0xFF4A90D9),
    Color(0xFF50E3C2),
    Color(0xFFF5A623),
    Color(0xFFD0021B),
    Color(0xFFBD10E0),
    Color(0xFF7ED321),
    Color(0xFF4A4A4A),
  ];

  static Color colorForGenre(String name, {String? hexColor, int depth = 0}) {
    if (hexColor != null && hexColor.isNotEmpty) {
      final hex = hexColor.replaceFirst('#', '');
      final value = int.tryParse(hex, radix: 16);
      if (value != null) {
        return Color(0xFF000000 | value);
      }
    }

    final mapped = _genreColors[name];
    if (mapped != null) return mapped;

    final hash = name.hashCode.abs();
    return _fallbackPalette[hash % _fallbackPalette.length];
  }

  static Color lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  static Color darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}
