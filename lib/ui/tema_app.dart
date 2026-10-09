import 'package:flutter/material.dart';

import 'colores_app.dart';
import 'tipografia.dart';

const _fuente = 'Inter';

/// Temas de la app; todas las pantallas los heredan de MaterialApp.
ThemeData temaClaro() => _tema(ColoresApp.claro, Brightness.light);
ThemeData temaOscuro() => _tema(ColoresApp.oscuro, Brightness.dark);

ThemeData _tema(ColoresApp c, Brightness brillo) {
  final esquema = ColorScheme.fromSeed(
    seedColor: c.primario,
    brightness: brillo,
    primary: c.primario,
    onPrimary: c.sobrePrimario,
    secondary: c.entra,
    onSecondary: c.sobreEntra,
    error: c.sale,
    onError: c.sobreSale,
    surface: c.superficie,
    onSurface: c.texto,
    onSurfaceVariant: c.textoSecundario,
    outline: c.borde,
    outlineVariant: c.borde,
  );
  final redondeado =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  final redondeadoBoton =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  const textoBoton = TextStyle(
      fontFamily: _fuente, fontSize: 16, fontWeight: FontWeight.w700);
  final bordeCampo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c.borde),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brillo,
    colorScheme: esquema,
    extensions: [c],
    fontFamily: _fuente,
    scaffoldBackgroundColor: c.fondo,
    appBarTheme: AppBarTheme(
      backgroundColor: c.superficie,
      foregroundColor: c.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: estiloTitulo(tamano: 20, color: c.texto),
      shape: Border(bottom: BorderSide(color: c.borde)),
    ),
    cardTheme: CardThemeData(
      color: c.superficie,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.borde),
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
        side: BorderSide(color: c.borde),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: redondeado,
        elevation: 0,
        backgroundColor: c.superficie,
        foregroundColor: c.primario,
        side: BorderSide(color: c.borde),
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
      fillColor: c.superficie,
      border: bordeCampo,
      enabledBorder: bordeCampo,
      focusedBorder: bordeCampo.copyWith(
        borderSide: BorderSide(color: c.primario, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.superficie,
      indicatorColor: c.primarioSuave,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
            fontFamily: _fuente, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.fondoAviso,
      contentTextStyle: TextStyle(
          fontFamily: _fuente, fontSize: 15, color: c.textoAviso),
      actionTextColor: c.accionAviso,
      shape: redondeado,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.superficie,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primario,
      foregroundColor: c.sobrePrimario,
      shape: redondeado,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.textoSecundario,
      minVerticalPadding: 12,
    ),
    dividerTheme: DividerThemeData(color: c.borde, space: 1),
  );
}
