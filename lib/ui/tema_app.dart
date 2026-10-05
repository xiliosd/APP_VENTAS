import 'package:flutter/material.dart';

import 'colores_app.dart';
import 'tipografia.dart';

const _fuente = 'Inter';

/// Tema central de la app; todas las pantallas lo heredan de MaterialApp.
ThemeData temaApp() {
  final esquema = ColorScheme.fromSeed(
    seedColor: ColoresApp.primario,
    primary: ColoresApp.primario,
    onPrimary: Colors.white,
    secondary: ColoresApp.entra,
    onSecondary: Colors.white,
    error: ColoresApp.sale,
    onError: Colors.white,
    surface: ColoresApp.superficie,
    onSurface: ColoresApp.texto,
    onSurfaceVariant: ColoresApp.textoSecundario,
    outline: ColoresApp.borde,
    outlineVariant: ColoresApp.borde,
  );
  final redondeado =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  final redondeadoBoton =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  const textoBoton = TextStyle(
      fontFamily: _fuente, fontSize: 16, fontWeight: FontWeight.w700);
  final bordeCampo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: ColoresApp.borde),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    fontFamily: _fuente,
    scaffoldBackgroundColor: ColoresApp.fondo,
    appBarTheme: AppBarTheme(
      backgroundColor: ColoresApp.superficie,
      foregroundColor: ColoresApp.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: estiloTitulo(tamano: 20),
      shape: const Border(bottom: BorderSide(color: ColoresApp.borde)),
    ),
    cardTheme: CardThemeData(
      color: ColoresApp.superficie,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ColoresApp.borde),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: redondeadoBoton,
        textStyle: textoBoton,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: redondeadoBoton,
        textStyle: textoBoton,
        side: const BorderSide(color: ColoresApp.borde),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: redondeado,
        elevation: 0,
        backgroundColor: ColoresApp.superficie,
        foregroundColor: ColoresApp.primario,
        side: const BorderSide(color: ColoresApp.borde),
        textStyle: textoBoton,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
            fontFamily: _fuente, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColoresApp.superficie,
      border: bordeCampo,
      enabledBorder: bordeCampo,
      focusedBorder: bordeCampo.copyWith(
        borderSide: const BorderSide(color: ColoresApp.primario, width: 2),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: ColoresApp.superficie,
      indicatorColor: Color(0xFFDBE4FF),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
            fontFamily: _fuente, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ColoresApp.texto,
      contentTextStyle: const TextStyle(
          fontFamily: _fuente, fontSize: 15, color: Colors.white),
      actionTextColor: const Color(0xFF93C5FD),
      shape: redondeado,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ColoresApp.superficie,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ColoresApp.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ColoresApp.primario,
      foregroundColor: Colors.white,
      shape: redondeado,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: ColoresApp.textoSecundario,
      minVerticalPadding: 12,
    ),
    dividerTheme: const DividerThemeData(color: ColoresApp.borde, space: 1),
  );
}
