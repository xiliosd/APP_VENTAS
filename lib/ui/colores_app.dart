import 'package:flutter/material.dart';

/// Tokens de color de la app: uno por modo (claro y oscuro "Azul noche").
/// Las pantallas los leen con `ColoresApp.of(context)`; nunca hex sueltos.
@immutable
class ColoresApp extends ThemeExtension<ColoresApp> {
  const ColoresApp({
    required this.fondo,
    required this.superficie,
    required this.borde,
    required this.texto,
    required this.textoSecundario,
    required this.primario,
    required this.sobrePrimario,
    required this.primarioSuave,
    required this.tarjetaPrincipal,
    required this.sobreTarjetaPrincipal,
    required this.marcaVerde,
    required this.entra,
    required this.rellenoEntra,
    required this.sobreEntra,
    required this.entraSuave,
    required this.sale,
    required this.sobreSale,
    required this.saleSuave,
    required this.fiado,
    required this.fiadoSuave,
    required this.fondoAviso,
    required this.textoAviso,
    required this.accionAviso,
  });

  final Color fondo;
  final Color superficie;
  final Color borde;
  final Color texto;
  final Color textoSecundario;

  /// Marca, selección, enlaces y relleno del botón primario.
  final Color primario;
  final Color sobrePrimario;

  /// Fondos de selección e íconos, indicador de la navegación.
  final Color primarioSuave;

  /// Tarjeta del monto del día y encabezado del Inicio.
  final Color tarjetaPrincipal;
  final Color sobreTarjetaPrincipal;

  /// Verde de la marca (acentos). En claro **nunca para texto** (3.1:1).
  final Color marcaVerde;

  /// Dinero que entra (texto): ventas, ganancia, abonos.
  final Color entra;

  /// Relleno del botón Cobrar / confirmar, y su texto.
  final Color rellenoEntra;
  final Color sobreEntra;
  final Color entraSuave;

  /// Dinero que sale, errores y acciones destructivas.
  final Color sale;
  final Color sobreSale;
  final Color saleSuave;

  /// Fiado y por cobrar.
  final Color fiado;
  final Color fiadoSuave;

  /// Aviso flotante (SnackBar).
  final Color fondoAviso;
  final Color textoAviso;
  final Color accionAviso;

  static const claro = ColoresApp(
    fondo: Color(0xFFF8FAFC),
    superficie: Color(0xFFFFFFFF),
    borde: Color(0xFFE5E7EB),
    texto: Color(0xFF1E293B),
    textoSecundario: Color(0xFF64748B),
    primario: Color(0xFF1A539B),
    sobrePrimario: Color(0xFFFFFFFF),
    primarioSuave: Color(0xFFDDE5F0),
    tarjetaPrincipal: Color(0xFF1A539B),
    sobreTarjetaPrincipal: Color(0xFFFFFFFF),
    marcaVerde: Color(0xFF16A34A),
    entra: Color(0xFF15803D),
    rellenoEntra: Color(0xFF15803D),
    sobreEntra: Color(0xFFFFFFFF),
    entraSuave: Color(0xFFBBF7D0),
    sale: Color(0xFFDC2626),
    sobreSale: Color(0xFFFFFFFF),
    saleSuave: Color(0xFFFECACA),
    fiado: Color(0xFFB45309),
    fiadoSuave: Color(0xFFFEF3C7),
    fondoAviso: Color(0xFF1E293B),
    textoAviso: Color(0xFFFFFFFF),
    accionAviso: Color(0xFF93C5FD),
  );

  static const oscuro = ColoresApp(
    fondo: Color(0xFF0B1220),
    superficie: Color(0xFF131C2E),
    borde: Color(0xFF243049),
    texto: Color(0xFFE2E8F0),
    textoSecundario: Color(0xFF94A3B8),
    primario: Color(0xFF9CC0F0),
    sobrePrimario: Color(0xFF0B1F3F),
    primarioSuave: Color(0xFF1E3A5F),
    tarjetaPrincipal: Color(0xFF1B3A66),
    sobreTarjetaPrincipal: Color(0xFFF1F5F9),
    marcaVerde: Color(0xFF4ADE80),
    entra: Color(0xFF4ADE80),
    rellenoEntra: Color(0xFF22C55E),
    sobreEntra: Color(0xFF052E16),
    entraSuave: Color(0xFF14532D),
    sale: Color(0xFFF87171),
    sobreSale: Color(0xFF450A0A),
    saleSuave: Color(0xFF7F1D1D),
    fiado: Color(0xFFFBBF24),
    fiadoSuave: Color(0xFF2A2010),
    fondoAviso: Color(0xFFE2E8F0),
    textoAviso: Color(0xFF0B1220),
    accionAviso: Color(0xFF1A539B),
  );

  /// Blanco fijo (no cambia por tema): insignia del logo y fondo del QR, que
  /// debe ser blanco para escanearse. También el texto de los avatares.
  static const blancoMarca = Color(0xFFFFFFFF);

  /// Colores de los avatares (iguales en ambos modos, texto [blancoMarca]).
  static const paletaAvatar = [
    Color(0xFF1A539B),
    Color(0xFF0F766E),
    Color(0xFF7C3AED),
    Color(0xFFB45309),
    Color(0xFFBE185D),
    Color(0xFF15803D),
  ];

  static ColoresApp of(BuildContext context) =>
      Theme.of(context).extension<ColoresApp>() ?? claro;

  @override
  ColoresApp copyWith() => this;

  @override
  ColoresApp lerp(ColoresApp? otro, double t) {
    if (otro == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return ColoresApp(
      fondo: l(fondo, otro.fondo),
      superficie: l(superficie, otro.superficie),
      borde: l(borde, otro.borde),
      texto: l(texto, otro.texto),
      textoSecundario: l(textoSecundario, otro.textoSecundario),
      primario: l(primario, otro.primario),
      sobrePrimario: l(sobrePrimario, otro.sobrePrimario),
      primarioSuave: l(primarioSuave, otro.primarioSuave),
      tarjetaPrincipal: l(tarjetaPrincipal, otro.tarjetaPrincipal),
      sobreTarjetaPrincipal: l(sobreTarjetaPrincipal, otro.sobreTarjetaPrincipal),
      marcaVerde: l(marcaVerde, otro.marcaVerde),
      entra: l(entra, otro.entra),
      rellenoEntra: l(rellenoEntra, otro.rellenoEntra),
      sobreEntra: l(sobreEntra, otro.sobreEntra),
      entraSuave: l(entraSuave, otro.entraSuave),
      sale: l(sale, otro.sale),
      sobreSale: l(sobreSale, otro.sobreSale),
      saleSuave: l(saleSuave, otro.saleSuave),
      fiado: l(fiado, otro.fiado),
      fiadoSuave: l(fiadoSuave, otro.fiadoSuave),
      fondoAviso: l(fondoAviso, otro.fondoAviso),
      textoAviso: l(textoAviso, otro.textoAviso),
      accionAviso: l(accionAviso, otro.accionAviso),
    );
  }
}
