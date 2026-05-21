import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF1E3A5F);
  static const Color accent = Color(0xFF2196F3);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);
  static const Color surface = Color(0xFFF5F7FA);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: accent,
          surface: surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );
}

// Status color helpers
Color statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'open':
    case 'new':
    case 'pending':
      return Colors.orange;
    case 'in_progress':
    case 'contacted':
      return Colors.blue;
    case 'resolved':
    case 'completed':
    case 'won':
    case 'deployed':
    case 'active':
      return Colors.green;
    case 'closed':
    case 'cancelled':
    case 'lost':
      return Colors.grey;
    case 'critical':
    case 'escalated':
      return Colors.red;
    case 'high':
      return Colors.deepOrange;
    case 'medium':
      return Colors.orange;
    case 'low':
      return Colors.blue;
    default:
      return Colors.grey;
  }
}

Color priorityColor(String priority) => statusColor(priority);
