import 'package:flutter/material.dart';

class TimelineCardTheme {
  static const Color contentPanelTop = Color(0xFF1E2640);
  static const Color contentPanelBottom = Color(0xFF141B30);

  static const Color cardTop = Color(0xFF27314F);
  static const Color cardBottom = Color(0xFF1A2238);
  static const Color cardBorder = Color(0xFF334166);
  static const Color cardShadow = Color(0xFF09101E);

  static const Color imageFallback = Color(0xFF1B2438);
  static const Color mapSurface = Color(0xFF182136);

  static const Color title = Color(0xFFF4F7FF);
  static const Color body = Color(0xFFB4BED8);
  static const Color muted = Color(0xFF7F8BA8);

  static const Color chipBackground = Color(0xFF2E3F67);
  static const Color chipBorder = Color(0xFF4F669C);
  static const Color chipText = Color(0xFFDCE7FF);

  static const Color accent = Color(0xFF6E8CFF);
  static const Color accentSoft = Color(0xFF8CA6FF);
  static const Color overlayDeep = Color(0xE6111725);

  static BoxDecoration cardDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [cardTop, cardBottom],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: cardBorder.withValues(alpha: 0.88),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: cardShadow.withValues(alpha: 0.34),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  static BoxDecoration chipDecoration() {
    return BoxDecoration(
      color: chipBackground.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: chipBorder.withValues(alpha: 0.9),
        width: 0.8,
      ),
    );
  }
}
