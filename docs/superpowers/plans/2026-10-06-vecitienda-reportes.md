# Fase 3B — Reportes por semana y por mes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** El administrador abre "Ver reportes" desde Inicio y ve, por semana o por mes, ventas, gastos, ganancia con comparación contra el periodo anterior, efectivo y transferencia, movimiento del fiado y ventas por día.

**Architecture:** Un modelo puro `Periodo` (semana lunes–domingo o mes calendario) calcula límites, navegación y título. Un `ReporteRepository` hace tres consultas por rango (ventas, abonos, gastos, sin lo anulado) y arma un `Reporte` en una pasada; `comparar` arma el actual y el anterior (los mismos días si el actual va a medias). La pantalla `ReportesScreen` se alimenta de un provider por `(periodo, hoy)` que se recalcula con `tableUpdates()`; las barras por día son widgets simples.

**Tech Stack:** Flutter 3.47 / Dart ^3.13, flutter_riverpod 2.6, Drift 2.34, sqlite3 3.5. Sin dependencias nuevas.

**Spec:** `docs/superpowers/specs/2026-10-06-vecitienda-reportes-design.md`

## Global Constraints

- Semana: lunes 00:00 a domingo 23:59:59.999 (hora local). Mes: día 1 al último día del mes.
- Títulos: "Semana del 5 al 11 oct.", "Semana del 28 sep. al 4 oct.", "Semana del 28 dic. al 3 ene. 2027", "Octubre 2026". Meses abreviados: ene., feb., mar., abr., may., jun., jul., ago., sep., oct., nov., dic.
- Nada anulado cuenta (`anulado = false` en las tres consultas).
- Ganancia = ventas − gastos. Venta promedio = ventas ÷ cantidad, redondeado (0 sin ventas).
- Efectivo/Transferencia = ventas de contado con ese medio + abonos con ese medio.
- Cambio % = `redondear((actual − anterior) × 100 ÷ |anterior|)`; `null` si `anterior == 0`.
- Periodo cerrado: se compara completo contra el anterior completo. Periodo actual: hasta hoy, contra los mismos días del anterior (sin pasar de su último día).
- Deuda: `deudaTotalAl(día anterior al inicio)` → `deudaTotalAl(último día contado)`.
- Mejor día: mayores ventas; empate, el primero; sin ventas, ninguno.
- Textos exactos: "Reportes", "Semana", "Mes", "¿Cómo te fue?", "Ventas", "Gastos", "Ganancia", "Caja y banco", "Efectivo", "Transferencia", "Fiado", "Ventas por día", "Ver reportes", "Sin ventas en este periodo", "↑ N % vs. semana pasada" / "↓ N % vs. mes pasado" / "= vs. semana pasada", "N ventas · promedio $X" (con `plural`), "Gastos $X", "Fiaste $X · Cobraste $Y", "Deuda: $X → $Y", "Mejor día: sábado 10 · $X", etiquetas de barra "Lun 5".
- Solo el administrador ve "Ver reportes". Sin librerías de gráficas. UI en español.
- Trabajar en una rama nueva `fase3b-reportes` desde `master`.

## Review Focus

1. Ventas a las 23:59 del domingo y a las 00:00 del lunes → cada una en su semana (prueba en Task 2).
2. Semana que cruza de año → periodo y título correctos al navegar (prueba en Task 1).
3. Periodo con gastos pero sin ventas → no es estado vacío; ganancia negativa en rojo; barras sin división por cero (prueba en Task 4).
4. 31 de marzo (mes actual) comparado con febrero → el anterior llega hasta el 28 (prueba en Task 2).
5. Venta registrada con la pantalla de reportes abierta → las cifras se actualizan solas (prueba en Task 4).

---

### Task 1: Modelo `Periodo`

**Files:**
- Create: `lib/util/periodo.dart`
- Test: `test/util/periodo_test.dart`

**Interfaces:**
- Consumes: `inicioDelDia`, `finDelDia` de `lib/util/fecha_util.dart`.
- Produces: `enum TipoPeriodo { semana, mes }`; `class Periodo` con `factory Periodo.de(TipoPeriodo tipo, DateTime dia)`, `factory Periodo.actual(TipoPeriodo tipo, DateTime hoy)`, `TipoPeriodo tipo`, `DateTime inicio`, `DateTime ultimoDia` (00:00 del último día), `DateTime fin` (último instante), `Periodo anterior`, `Periodo siguiente`, `bool contiene(DateTime momento)`, `String titulo`, igualdad por valor.

- [ ] **Step 1: Crear la rama**

```bash
git checkout master
git checkout -b fase3b-reportes
```

- [ ] **Step 2: Escribir la prueba que falla**

`test/util/periodo_test.dart`:

```dart
import 'package:app_ventas/util/periodo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('semana', () {
    test('la semana de un miércoles va de lunes a domingo', () {
      final p = Periodo.de(TipoPeriodo.semana, DateTime(2026, 10, 7, 15));
      expect(p.inicio, DateTime(2026, 10, 5));
      expect(p.ultimoDia, DateTime(2026, 10, 11));
      expect(p.fin, DateTime(2026, 10, 11, 23, 59, 59, 999));
      expect(p.titulo, 'Semana del 5 al 11 oct.');
    });

    test('una semana que cruza de mes nombra los dos meses', () {
      final p = Periodo.de(TipoPeriodo.semana, DateTime(2026, 10, 1));
      expect(p.inicio, DateTime(2026, 9, 28));
      expect(p.titulo, 'Semana del 28 sep. al 4 oct.');
    });

    test('una semana que cruza de año lleva el año', () {
      final p = Periodo.de(TipoPeriodo.semana, DateTime(2026, 12, 30));
      expect(p.inicio, DateTime(2026, 12, 28));
      expect(p.ultimoDia, DateTime(2027, 1, 3));
      expect(p.titulo, 'Semana del 28 dic. al 3 ene. 2027');
    });

    test('anterior y siguiente cruzan el año', () {
      final enero = Periodo.de(TipoPeriodo.semana, DateTime(2027, 1, 5));
      expect(enero.anterior.inicio, DateTime(2026, 12, 28));
      expect(enero.anterior.siguiente, enero);
    });

    test('contiene hasta el último instante del domingo', () {
      final p = Periodo.de(TipoPeriodo.semana, DateTime(2026, 10, 7));
      expect(p.contiene(DateTime(2026, 10, 11, 23, 59)), isTrue);
      expect(p.contiene(DateTime(2026, 10, 12)), isFalse);
      expect(p.contiene(DateTime(2026, 10, 4, 23, 59)), isFalse);
    });

    test('dos días de la misma semana dan el mismo periodo', () {
      expect(Periodo.de(TipoPeriodo.semana, DateTime(2026, 10, 6)),
          Periodo.de(TipoPeriodo.semana, DateTime(2026, 10, 10)));
      expect(
          Periodo.de(TipoPeriodo.semana, DateTime(2026, 10, 6)).hashCode,
          Periodo.de(TipoPeriodo.semana, DateTime(2026, 10, 10)).hashCode);
    });
  });

  group('mes', () {
    test('el mes va del 1 al último día y se titula con su nombre', () {
      final p = Periodo.de(TipoPeriodo.mes, DateTime(2026, 10, 15));
      expect(p.inicio, DateTime(2026, 10, 1));
      expect(p.ultimoDia, DateTime(2026, 10, 31));
      expect(p.titulo, 'Octubre 2026');
    });

    test('febrero tiene 28 o 29 días', () {
      expect(Periodo.de(TipoPeriodo.mes, DateTime(2026, 2, 10)).ultimoDia,
          DateTime(2026, 2, 28));
      expect(Periodo.de(TipoPeriodo.mes, DateTime(2028, 2, 10)).ultimoDia,
          DateTime(2028, 2, 29));
    });

    test('el anterior de enero es diciembre del año pasado', () {
      final anterior = Periodo.de(TipoPeriodo.mes, DateTime(2026, 1, 20)).anterior;
      expect(anterior.inicio, DateTime(2025, 12, 1));
      expect(anterior.titulo, 'Diciembre 2025');
    });
  });

  test('Periodo.actual es el que contiene hoy', () {
    final hoy = DateTime(2026, 10, 7);
    expect(Periodo.actual(TipoPeriodo.semana, hoy).contiene(hoy), isTrue);
    expect(Periodo.actual(TipoPeriodo.mes, hoy).inicio, DateTime(2026, 10, 1));
  });
}
```

- [ ] **Step 3: Correr y ver que falla**

Run: `flutter test test/util/periodo_test.dart`
Expected: FAIL (`periodo.dart` no existe).

- [ ] **Step 4: Implementar**

`lib/util/periodo.dart`:

```dart
import 'fecha_util.dart';

enum TipoPeriodo { semana, mes }

const _mesesCortos = [
  'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
  'jul.', 'ago.', 'sep.', 'oct.', 'nov.', 'dic.',
];

const _mesesLargos = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

/// Una semana (lunes a domingo) o un mes calendario, en hora local. Se
/// compara por valor, así sirve de clave de provider.
class Periodo {
  const Periodo._(this.tipo, this.inicio);

  /// El periodo de [tipo] que contiene [dia].
  factory Periodo.de(TipoPeriodo tipo, DateTime dia) {
    final d = inicioDelDia(dia);
    return switch (tipo) {
      TipoPeriodo.semana =>
        Periodo._(tipo, DateTime(d.year, d.month, d.day - (d.weekday - 1))),
      TipoPeriodo.mes => Periodo._(tipo, DateTime(d.year, d.month)),
    };
  }

  /// El periodo de [tipo] en curso.
  factory Periodo.actual(TipoPeriodo tipo, DateTime hoy) =>
      Periodo.de(tipo, hoy);

  final TipoPeriodo tipo;

  /// Primer día, a las 00:00.
  final DateTime inicio;

  /// Último día, a las 00:00.
  DateTime get ultimoDia => switch (tipo) {
        TipoPeriodo.semana =>
          DateTime(inicio.year, inicio.month, inicio.day + 6),
        TipoPeriodo.mes => DateTime(inicio.year, inicio.month + 1, 0),
      };

  /// Último instante del periodo.
  DateTime get fin => finDelDia(ultimoDia);

  Periodo get anterior =>
      Periodo.de(tipo, DateTime(inicio.year, inicio.month, inicio.day - 1));

  Periodo get siguiente => Periodo.de(
      tipo, DateTime(ultimoDia.year, ultimoDia.month, ultimoDia.day + 1));

  bool contiene(DateTime momento) =>
      !momento.isBefore(inicio) && !momento.isAfter(fin);

  /// "Semana del 5 al 11 oct.", "Semana del 28 sep. al 4 oct.",
  /// "Semana del 28 dic. al 3 ene. 2027" u "Octubre 2026".
  String get titulo {
    if (tipo == TipoPeriodo.mes) {
      return '${_mesesLargos[inicio.month - 1]} ${inicio.year}';
    }
    final a = inicio;
    final b = ultimoDia;
    final mesA = _mesesCortos[a.month - 1];
    final mesB = _mesesCortos[b.month - 1];
    if (a.year != b.year) {
      return 'Semana del ${a.day} $mesA al ${b.day} $mesB ${b.year}';
    }
    if (a.month != b.month) {
      return 'Semana del ${a.day} $mesA al ${b.day} $mesB';
    }
    return 'Semana del ${a.day} al ${b.day} $mesB';
  }

  @override
  bool operator ==(Object other) =>
      other is Periodo && other.tipo == tipo && other.inicio == inicio;

  @override
  int get hashCode => Object.hash(tipo, inicio);
}
```

Si `dart format` reacomoda las listas de meses en una por línea, está bien.

- [ ] **Step 5: Correr y ver que pasa**

Run: `flutter test test/util/periodo_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/util/periodo.dart test/util/periodo_test.dart
git commit -m "Add the week and month period model for reports"
```

---

### Task 2: `ReporteRepository` y su provider

**Files:**
- Create: `lib/repositories/reporte_repository.dart`
- Create: `lib/providers/reporte_providers.dart`
- Modify: `lib/providers/repository_providers.dart`
- Test: `test/repositories/reporte_repository_test.dart`

**Interfaces:**
- Consumes: `Periodo` (Task 1); `FiadoRepository.deudaTotalAl(DateTime)`; columnas `anulado`.
- Produces:
  - `class Reporte` con `int ventas, cantidadVentas, gastos, recibidoEfectivo, recibidoTransferencia, fiado, cobrado, deudaInicio, deudaFin`, `Map<DateTime, int> ventasPorDia` (cada día de `desde` a `hasta`, en orden, con 0 si no hubo), `DateTime? mejorDia`, getters `int ganancia`, `int ventaPromedio`, `bool vacio`.
  - `class ComparacionReporte` con `Reporte actual`, `Reporte anterior`, `int? cambioVentas`, `int? cambioGanancia`.
  - `int? cambioPorcentual(int actual, int anterior)`
  - `ReporteRepository(AppDatabase db, FiadoRepository fiado)` con `Future<Reporte> reporte(DateTime desde, DateTime hasta)` y `Future<ComparacionReporte> comparar(Periodo periodo, {required DateTime hoy})`.
  - `reporteRepositoryProvider`; `typedef ConsultaReporte = ({Periodo periodo, DateTime hoy})`; `comparacionReporteProvider` (`FutureProvider.autoDispose.family<ComparacionReporte, ConsultaReporte>`).

- [ ] **Step 1: Escribir la prueba que falla**

`test/repositories/reporte_repository_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/repositories/fiado_repository.dart';
import 'package:app_ventas/repositories/reporte_repository.dart';
import 'package:app_ventas/util/periodo.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ReporteRepository repo;
  late int ana;
  late int pedro;
  final lunes = DateTime(2026, 10, 5);
  final domingo = DateTime(2026, 10, 11);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReporteRepository(db, FiadoRepository(db));
    ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
  });

  tearDown(() => db.close());

  Future<int> vender(int monto, DateTime fecha,
          {bool fiado = false, MedioPago medio = MedioPago.efectivo}) =>
      db.into(db.ventas).insert(VentasCompanion.insert(
            monto: monto,
            fecha: fecha,
            usuarioId: ana,
            esFiado: Value(fiado),
            clienteId: Value(fiado ? pedro : null),
            medioPago: Value(medio),
          ));

  Future<int> abonar(int monto, DateTime fecha,
          {MedioPago medio = MedioPago.efectivo}) =>
      db.into(db.pagosFiado).insert(PagosFiadoCompanion.insert(
            clienteId: pedro,
            monto: monto,
            fecha: fecha,
            usuarioId: ana,
            medioPago: Value(medio),
          ));

  Future<int> gastar(int monto, DateTime fecha) => db.into(db.gastos).insert(
      GastosCompanion.insert(monto: monto, fecha: fecha, usuarioId: ana));

  Future<void> anular(String tabla, int id) => db.customStatement(
      'UPDATE $tabla SET anulado = 1 WHERE id = ?', [id]);

  group('reporte', () {
    test('suma el periodo y separa caja, banco y fiado', () async {
      await vender(5000, DateTime(2026, 10, 5, 9));
      await vender(3000, DateTime(2026, 10, 5, 10),
          medio: MedioPago.transferencia);
      await vender(4000, DateTime(2026, 10, 6), fiado: true);
      await anular('ventas', await vender(9999, DateTime(2026, 10, 6)));
      await abonar(1000, DateTime(2026, 10, 7));
      await abonar(500, DateTime(2026, 10, 7), medio: MedioPago.transferencia);
      await gastar(2000, DateTime(2026, 10, 7));
      await vender(7000, DateTime(2026, 10, 4));
      await vender(7000, DateTime(2026, 10, 12));

      final r = await repo.reporte(lunes, domingo);

      expect(r.ventas, 12000);
      expect(r.cantidadVentas, 3);
      expect(r.ventaPromedio, 4000);
      expect(r.gastos, 2000);
      expect(r.ganancia, 10000);
      expect(r.recibidoEfectivo, 6000);
      expect(r.recibidoTransferencia, 3500);
      expect(r.fiado, 4000);
      expect(r.cobrado, 1500);
      expect(r.deudaInicio, 0);
      expect(r.deudaFin, 2500);
      expect(r.ventasPorDia.length, 7);
      expect(r.ventasPorDia[DateTime(2026, 10, 5)], 8000);
      expect(r.ventasPorDia[DateTime(2026, 10, 6)], 4000);
      expect(r.ventasPorDia[DateTime(2026, 10, 7)], 0);
      expect(r.mejorDia, DateTime(2026, 10, 5));
      expect(r.vacio, isFalse);
    });

    test('cada venta cae en su semana aunque sea a medianoche', () async {
      await vender(1000, DateTime(2026, 10, 11, 23, 59, 59));
      await vender(2000, DateTime(2026, 10, 12));
      await vender(4000, DateTime(2026, 10, 4, 23, 59));

      expect((await repo.reporte(lunes, domingo)).ventas, 1000);
    });

    test('un anulado no cuenta en nada', () async {
      await anular('pagos_fiado', await abonar(800, DateTime(2026, 10, 6)));
      await anular('gastos', await gastar(900, DateTime(2026, 10, 6)));

      final r = await repo.reporte(lunes, domingo);

      expect(r.cobrado, 0);
      expect(r.gastos, 0);
      expect(r.recibidoEfectivo, 0);
      expect(r.vacio, isTrue);
    });

    test('en un empate el mejor día es el primero', () async {
      await vender(3000, DateTime(2026, 10, 5));
      await vender(3000, DateTime(2026, 10, 6));

      expect((await repo.reporte(lunes, domingo)).mejorDia,
          DateTime(2026, 10, 5));
    });

    test('sin datos: vacío, sin mejor día y todos los días en 0', () async {
      final r = await repo.reporte(lunes, domingo);

      expect(r.vacio, isTrue);
      expect(r.mejorDia, isNull);
      expect(r.ventaPromedio, 0);
      expect(r.ventasPorDia.values, everyElement(0));
      expect(r.ventasPorDia.keys.first, lunes);
      expect(r.ventasPorDia.keys.last, domingo);
    });

    test('la deuda al inicio cuenta lo fiado antes del periodo', () async {
      await vender(6000, DateTime(2026, 9, 30), fiado: true);

      final r = await repo.reporte(lunes, domingo);

      expect(r.deudaInicio, 6000);
      expect(r.deudaFin, 6000);
      expect(r.fiado, 0);
    });
  });

  group('comparar', () {
    test('un periodo cerrado se compara con el anterior completo', () async {
      await vender(4000, DateTime(2026, 9, 22));
      await vender(1000, DateTime(2026, 9, 27, 20));
      await vender(6000, DateTime(2026, 9, 29));

      final c = await repo.comparar(
          Periodo.de(TipoPeriodo.semana, DateTime(2026, 9, 30)),
          hoy: DateTime(2026, 10, 7));

      expect(c.actual.ventas, 6000);
      expect(c.anterior.ventas, 5000);
      expect(c.cambioVentas, 20);
      expect(c.actual.ventasPorDia.length, 7);
    });

    test('el periodo actual se compara con los mismos días del anterior',
        () async {
      await vender(4000, DateTime(2026, 9, 29));
      await vender(9000, DateTime(2026, 10, 2));
      await vender(5000, DateTime(2026, 10, 6));

      final hoy = DateTime(2026, 10, 7);
      final c = await repo.comparar(Periodo.actual(TipoPeriodo.semana, hoy),
          hoy: hoy);

      expect(c.actual.ventasPorDia.length, 3);
      expect(c.anterior.ventas, 4000);
      expect(c.cambioVentas, 25);
    });

    test('el 31 de marzo se compara con febrero hasta el 28', () async {
      await vender(2000, DateTime(2026, 2, 28, 18));
      await vender(4000, DateTime(2026, 3, 10));

      final hoy = DateTime(2026, 3, 31);
      final c =
          await repo.comparar(Periodo.actual(TipoPeriodo.mes, hoy), hoy: hoy);

      expect(c.anterior.ventas, 2000);
      expect(c.anterior.ventasPorDia.length, 28);
      expect(c.cambioVentas, 100);
    });

    test('sin ventas en el anterior no hay porcentaje', () async {
      await vender(5000, DateTime(2026, 10, 6));

      final hoy = DateTime(2026, 10, 7);
      final c = await repo.comparar(Periodo.actual(TipoPeriodo.semana, hoy),
          hoy: hoy);

      expect(c.cambioVentas, isNull);
    });

    test('una ganancia anterior negativa usa su valor absoluto', () async {
      await gastar(1000, DateTime(2026, 9, 29));
      await vender(500, DateTime(2026, 10, 6));

      final hoy = DateTime(2026, 10, 7);
      final c = await repo.comparar(Periodo.actual(TipoPeriodo.semana, hoy),
          hoy: hoy);

      expect(c.anterior.ganancia, -1000);
      expect(c.cambioGanancia, 150);
    });
  });

  test('cambioPorcentual redondea y es null con anterior en 0', () {
    expect(cambioPorcentual(1150, 1000), 15);
    expect(cambioPorcentual(900, 1000), -10);
    expect(cambioPorcentual(1000, 1000), 0);
    expect(cambioPorcentual(1000, 3000), -67);
    expect(cambioPorcentual(500, 0), isNull);
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/repositories/reporte_repository_test.dart`
Expected: FAIL (`reporte_repository.dart` no existe).

- [ ] **Step 3: Implementar el repositorio**

`lib/repositories/reporte_repository.dart`:

```dart
import '../data/database.dart';
import '../util/fecha_util.dart';
import '../util/periodo.dart';
import 'fiado_repository.dart';

/// Cifras de un rango de días, sin nada anulado.
class Reporte {
  const Reporte({
    required this.ventas,
    required this.cantidadVentas,
    required this.gastos,
    required this.recibidoEfectivo,
    required this.recibidoTransferencia,
    required this.fiado,
    required this.cobrado,
    required this.deudaInicio,
    required this.deudaFin,
    required this.ventasPorDia,
    required this.mejorDia,
  });

  /// Contado + fiado.
  final int ventas;
  final int cantidadVentas;
  final int gastos;

  /// Ventas de contado y abonos en efectivo.
  final int recibidoEfectivo;

  /// Ventas de contado y abonos por transferencia.
  final int recibidoTransferencia;

  /// Ventas fiadas del rango.
  final int fiado;

  /// Abonos del rango.
  final int cobrado;

  /// Deuda de todos los clientes al cierre del día anterior al rango.
  final int deudaInicio;

  /// Deuda de todos los clientes al cierre del último día del rango.
  final int deudaFin;

  /// Cada día del rango, en orden, con lo vendido (0 si nada).
  final Map<DateTime, int> ventasPorDia;

  /// Día de mayores ventas (empate: el primero); null sin ventas.
  final DateTime? mejorDia;

  int get ganancia => ventas - gastos;

  int get ventaPromedio =>
      cantidadVentas == 0 ? 0 : (ventas / cantidadVentas).round();

  /// Sin ventas, gastos ni abonos.
  bool get vacio => cantidadVentas == 0 && gastos == 0 && cobrado == 0;
}

/// Un periodo y el anterior con el que se compara.
class ComparacionReporte {
  const ComparacionReporte({
    required this.actual,
    required this.anterior,
    required this.cambioVentas,
    required this.cambioGanancia,
  });

  final Reporte actual;
  final Reporte anterior;

  /// Porcentaje entero; null si el anterior fue 0.
  final int? cambioVentas;
  final int? cambioGanancia;
}

/// `redondear((actual − anterior) × 100 ÷ |anterior|)`; null si [anterior]
/// es 0.
int? cambioPorcentual(int actual, int anterior) {
  if (anterior == 0) return null;
  return ((actual - anterior) * 100 / anterior.abs()).round();
}

int _suma(Iterable<int> montos) => montos.fold(0, (suma, m) => suma + m);

/// Días calendario de [desde] a [hasta] (ambos a las 00:00).
int _diasEntre(DateTime desde, DateTime hasta) =>
    DateTime.utc(hasta.year, hasta.month, hasta.day)
        .difference(DateTime.utc(desde.year, desde.month, desde.day))
        .inDays;

class ReporteRepository {
  ReporteRepository(this._db, this._fiado);

  final AppDatabase _db;
  final FiadoRepository _fiado;

  /// Reporte de los días [desde] a [hasta], ambos incluidos.
  Future<Reporte> reporte(DateTime desde, DateTime hasta) async {
    final inicio = inicioDelDia(desde);
    final ultimo = inicioDelDia(hasta);
    final fin = finDelDia(ultimo);

    final ventas = await (_db.select(_db.ventas)
          ..where((v) =>
              v.anulado.equals(false) & v.fecha.isBetweenValues(inicio, fin)))
        .get();
    final pagos = await (_db.select(_db.pagosFiado)
          ..where((p) =>
              p.anulado.equals(false) & p.fecha.isBetweenValues(inicio, fin)))
        .get();
    final gastos = await (_db.select(_db.gastos)
          ..where((g) =>
              g.anulado.equals(false) & g.fecha.isBetweenValues(inicio, fin)))
        .get();

    int recibido(MedioPago medio) =>
        _suma(ventas
            .where((v) => !v.esFiado && v.medioPago == medio)
            .map((v) => v.monto)) +
        _suma(pagos.where((p) => p.medioPago == medio).map((p) => p.monto));

    final porDia = <DateTime, int>{};
    for (var dia = inicio;
        !dia.isAfter(ultimo);
        dia = DateTime(dia.year, dia.month, dia.day + 1)) {
      porDia[dia] = 0;
    }
    for (final v in ventas) {
      porDia.update(inicioDelDia(v.fecha), (suma) => suma + v.monto);
    }
    DateTime? mejorDia;
    for (final entrada in porDia.entries) {
      if (entrada.value > 0 &&
          (mejorDia == null || entrada.value > porDia[mejorDia]!)) {
        mejorDia = entrada.key;
      }
    }

    return Reporte(
      ventas: _suma(ventas.map((v) => v.monto)),
      cantidadVentas: ventas.length,
      gastos: _suma(gastos.map((g) => g.monto)),
      recibidoEfectivo: recibido(MedioPago.efectivo),
      recibidoTransferencia: recibido(MedioPago.transferencia),
      fiado: _suma(ventas.where((v) => v.esFiado).map((v) => v.monto)),
      cobrado: _suma(pagos.map((p) => p.monto)),
      deudaInicio: await _fiado.deudaTotalAl(
          DateTime(inicio.year, inicio.month, inicio.day - 1)),
      deudaFin: await _fiado.deudaTotalAl(ultimo),
      ventasPorDia: porDia,
      mejorDia: mejorDia,
    );
  }

  /// [periodo] contra el anterior. Si [periodo] contiene [hoy], cuenta
  /// hasta hoy y el anterior solo los mismos días (sin pasar de su último
  /// día); si ya cerró, ambos completos.
  Future<ComparacionReporte> comparar(
    Periodo periodo, {
    required DateTime hoy,
  }) async {
    final anterior = periodo.anterior;
    final DateTime hasta;
    final DateTime hastaAnterior;
    if (periodo.contiene(hoy)) {
      hasta = inicioDelDia(hoy);
      final mismoDia = DateTime(anterior.inicio.year, anterior.inicio.month,
          anterior.inicio.day + _diasEntre(periodo.inicio, hasta));
      hastaAnterior = mismoDia.isAfter(anterior.ultimoDia)
          ? anterior.ultimoDia
          : mismoDia;
    } else {
      hasta = periodo.ultimoDia;
      hastaAnterior = anterior.ultimoDia;
    }
    final actual = await reporte(periodo.inicio, hasta);
    final previo = await reporte(anterior.inicio, hastaAnterior);
    return ComparacionReporte(
      actual: actual,
      anterior: previo,
      cambioVentas: cambioPorcentual(actual.ventas, previo.ventas),
      cambioGanancia: cambioPorcentual(actual.ganancia, previo.ganancia),
    );
  }
}
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/repositories/reporte_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Providers**

En `lib/providers/repository_providers.dart` agregar `import '../repositories/reporte_repository.dart';` y:

```dart
final reporteRepositoryProvider = Provider(
  (ref) => ReporteRepository(
    ref.watch(databaseProvider),
    ref.watch(fiadoRepositoryProvider),
  ),
);
```

`lib/providers/reporte_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/reporte_repository.dart';
import '../util/periodo.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

/// Periodo a mostrar y el día que cuenta como hoy (normalizado con
/// `inicioDelDia`). Los records se comparan por valor.
typedef ConsultaReporte = ({Periodo periodo, DateTime hoy});

/// Emite con cada cambio en la base, para recalcular el reporte abierto
/// (mismo patrón que resumen_providers.dart).
final _cambiosReporteProvider = StreamProvider<void>((ref) {
  return ref.watch(databaseProvider).tableUpdates().map((_) {});
});

final comparacionReporteProvider = FutureProvider.autoDispose
    .family<ComparacionReporte, ConsultaReporte>((ref, consulta) {
  ref.watch(_cambiosReporteProvider);
  return ref
      .watch(reporteRepositoryProvider)
      .comparar(consulta.periodo, hoy: consulta.hoy);
});
```

Run: `flutter analyze lib/providers lib/repositories`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/repositories/reporte_repository.dart lib/providers/reporte_providers.dart lib/providers/repository_providers.dart test/repositories/reporte_repository_test.dart
git commit -m "Add ReporteRepository with period totals and comparison"
```

---

### Task 3: Barras de ventas por día

**Files:**
- Create: `lib/screens/reportes/barras_por_dia.dart`
- Test: `test/screens/reportes/barras_por_dia_test.dart`

**Interfaces:**
- Consumes: `formatoMoneda`, `ColoresApp.entra`, `ColoresApp.entraSuave`.
- Produces: `String etiquetaDia(DateTime dia)` ("Lun 5"); `BarrasPorDia({Key? key, required Map<DateTime, int> ventasPorDia, DateTime? mejorDia})`; `BarraDia({Key? key, required String etiqueta, required int valor, required double fraccion, required bool resaltada})` con llave `barra_<día del mes>`; texto con llave `texto_mejor_dia`.

- [ ] **Step 1: Escribir la prueba que falla**

`test/screens/reportes/barras_por_dia_test.dart`:

```dart
import 'package:app_ventas/screens/reportes/barras_por_dia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> montar(WidgetTester tester, Map<DateTime, int> ventas,
      {DateTime? mejorDia}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BarrasPorDia(ventasPorDia: ventas, mejorDia: mejorDia),
      ),
    ));
  }

  test('etiquetaDia usa el día de la semana abreviado', () {
    expect(etiquetaDia(DateTime(2026, 10, 5)), 'Lun 5');
    expect(etiquetaDia(DateTime(2026, 10, 7)), 'Mié 7');
    expect(etiquetaDia(DateTime(2026, 10, 10)), 'Sáb 10');
    expect(etiquetaDia(DateTime(2026, 10, 11)), 'Dom 11');
  });

  testWidgets('una fila por día y el mejor día resaltado', (tester) async {
    await montar(tester, {
      DateTime(2026, 10, 5): 2000,
      DateTime(2026, 10, 6): 5000,
      DateTime(2026, 10, 7): 0,
    }, mejorDia: DateTime(2026, 10, 6));

    expect(find.byType(BarraDia), findsNWidgets(3));
    expect(find.text('Lun 5'), findsOneWidget);
    expect(find.text(r'$5.000'), findsOneWidget);
    expect(find.text(r'Mejor día: martes 6 · $5.000'), findsOneWidget);
    final mejor = tester.widget<BarraDia>(find.byKey(const Key('barra_6')));
    expect(mejor.resaltada, isTrue);
    expect(mejor.fraccion, 1.0);
    final otra = tester.widget<BarraDia>(find.byKey(const Key('barra_5')));
    expect(otra.resaltada, isFalse);
    expect(otra.fraccion, 0.4);
  });

  testWidgets('todo en 0 no divide por cero ni muestra mejor día',
      (tester) async {
    await montar(tester, {
      DateTime(2026, 10, 5): 0,
      DateTime(2026, 10, 6): 0,
    });

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('texto_mejor_dia')), findsNothing);
    expect(tester.widget<BarraDia>(find.byKey(const Key('barra_5'))).fraccion,
        0.0);
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/reportes/barras_por_dia_test.dart`
Expected: FAIL (`barras_por_dia.dart` no existe).

- [ ] **Step 3: Implementar**

`lib/screens/reportes/barras_por_dia.dart`:

```dart
import 'package:flutter/material.dart';

import '../../ui/colores_app.dart';
import '../../util/formato_moneda.dart';

const _diasCortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _diasLargos = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];

/// "Lun 5".
String etiquetaDia(DateTime dia) => '${_diasCortos[dia.weekday - 1]} ${dia.day}';

/// Ventas de cada día como barras horizontales, con el mejor día resaltado.
class BarrasPorDia extends StatelessWidget {
  const BarrasPorDia({super.key, required this.ventasPorDia, this.mejorDia});

  final Map<DateTime, int> ventasPorDia;
  final DateTime? mejorDia;

  @override
  Widget build(BuildContext context) {
    final maximo =
        ventasPorDia.values.fold<int>(0, (m, v) => v > m ? v : m);
    final mejor = mejorDia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mejor != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Mejor día: ${_diasLargos[mejor.weekday - 1]} ${mejor.day} · '
              '${formatoMoneda(ventasPorDia[mejor] ?? 0)}',
              key: const Key('texto_mejor_dia'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        for (final entrada in ventasPorDia.entries)
          BarraDia(
            key: Key('barra_${entrada.key.day}'),
            etiqueta: etiquetaDia(entrada.key),
            valor: entrada.value,
            fraccion: maximo == 0 ? 0.0 : entrada.value / maximo,
            resaltada: entrada.key == mejor,
          ),
      ],
    );
  }
}

/// Una fila: etiqueta del día, barra proporcional y monto.
class BarraDia extends StatelessWidget {
  const BarraDia({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.fraccion,
    required this.resaltada,
  });

  final String etiqueta;
  final int valor;

  /// De 0 a 1, respecto al día de más venta.
  final double fraccion;
  final bool resaltada;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(etiqueta)),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                // Un día sin ventas deja una marca mínima, no un hueco.
                widthFactor: fraccion == 0 ? 0.01 : fraccion,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: resaltada ? ColoresApp.entra : ColoresApp.entraSuave,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: Text(
              formatoMoneda(valor),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/screens/reportes/barras_por_dia_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/reportes/barras_por_dia.dart test/screens/reportes/barras_por_dia_test.dart
git commit -m "Add daily sales bars for reports"
```

---

### Task 4: Pantalla Reportes

**Files:**
- Create: `lib/screens/reportes/reportes_screen.dart`
- Test: `test/screens/reportes/reportes_screen_test.dart`

**Interfaces:**
- Consumes: `Periodo`, `TipoPeriodo` (Task 1); `comparacionReporteProvider`, `ConsultaReporte`, `ComparacionReporte`, `Reporte` (Task 2); `BarrasPorDia` (Task 3); `SelectorSegmentado`, `TarjetaMonto`, `TonoMonto`, `EstadoVacio`, `plural`, `formatoMoneda`, `inicioDelDia`.
- Produces: `ReportesScreen({Key? key, DateTime? hoy})` (`hoy` solo para pruebas). Llaves: `selector_periodo`, `periodo_anterior`, `periodo_siguiente`, `titulo_periodo`, `reporte_ventas`, `reporte_gastos`, `reporte_ganancia`, `cambio_ventas`, `cambio_ganancia`, `texto_promedio`, `reporte_efectivo`, `reporte_transferencia`, `texto_gastos_caja`, `texto_fiado`, `texto_deuda`.

- [ ] **Step 1: Escribir la prueba que falla**

`test/screens/reportes/reportes_screen_test.dart`:

```dart
import 'package:app_ventas/data/database.dart';
import 'package:app_ventas/providers/database_provider.dart';
import 'package:app_ventas/screens/reportes/barras_por_dia.dart';
import 'package:app_ventas/screens/reportes/reportes_screen.dart';
import 'package:app_ventas/ui/monto.dart';
import 'package:app_ventas/ui/tema_app.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int ana;
  late int pedro;
  final hoy = DateTime(2026, 10, 7); // miércoles

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ana = await db.into(db.usuarios).insert(
        UsuariosCompanion.insert(nombre: 'Ana', rol: 'admin', pinHash: 'x'));
    pedro = await db
        .into(db.clientes)
        .insert(ClientesCompanion.insert(nombre: 'Don Pedro'));
  });

  tearDown(() => db.close());

  Future<void> vender(int monto, DateTime fecha, {bool fiado = false}) =>
      db.into(db.ventas).insert(VentasCompanion.insert(
            monto: monto,
            fecha: fecha,
            usuarioId: ana,
            esFiado: Value(fiado),
            clienteId: Value(fiado ? pedro : null),
          ));

  Future<void> montar(WidgetTester tester) async {
    // Pantalla alta: el ListView construye todas las secciones.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: temaApp(), home: ReportesScreen(hoy: hoy)),
    ));
    await tester.pumpAndSettle();
  }

  Finder en(String clave, String texto) => find.descendant(
      of: find.byKey(Key(clave)), matching: find.text(texto));

  bool siguienteHabilitada(WidgetTester tester) =>
      tester
          .widget<IconButton>(find.byKey(const Key('periodo_siguiente')))
          .onPressed !=
      null;

  testWidgets('muestra la semana actual con sus cifras y la comparación',
      (tester) async {
    await vender(5000, DateTime(2026, 10, 6));
    await vender(4000, DateTime(2026, 9, 29));
    await montar(tester);

    expect(find.text('Reportes'), findsOneWidget);
    expect(find.text('Semana del 5 al 11 oct.'), findsOneWidget);
    expect(en('reporte_ventas', r'$5.000'), findsOneWidget);
    expect(find.text('↑ 25 % vs. semana pasada'), findsWidgets);
    expect(find.text(r'1 venta · promedio $5.000'), findsOneWidget);
    expect(en('reporte_efectivo', r'$5.000'), findsOneWidget);
    expect(siguienteHabilitada(tester), isFalse);
  });

  testWidgets('la flecha anterior va a la semana pasada', (tester) async {
    await vender(5000, DateTime(2026, 10, 6));
    await vender(4000, DateTime(2026, 9, 29));
    await montar(tester);

    await tester.tap(find.byKey(const Key('periodo_anterior')));
    await tester.pumpAndSettle();

    expect(find.text('Semana del 28 sep. al 4 oct.'), findsOneWidget);
    expect(en('reporte_ventas', r'$4.000'), findsOneWidget);
    expect(siguienteHabilitada(tester), isTrue);
  });

  testWidgets('Mes muestra el mes actual sin comparación si el anterior '
      'no vendió esos días', (tester) async {
    await vender(5000, DateTime(2026, 10, 6));
    await vender(4000, DateTime(2026, 9, 29));
    await montar(tester);

    await tester.tap(find.text('Mes'));
    await tester.pumpAndSettle();

    expect(find.text('Octubre 2026'), findsOneWidget);
    expect(en('reporte_ventas', r'$5.000'), findsOneWidget);
    expect(find.textContaining('vs. mes pasado'), findsNothing);
  });

  testWidgets('sin movimientos muestra el estado vacío con el selector',
      (tester) async {
    await montar(tester);

    expect(find.text('Sin ventas en este periodo'), findsOneWidget);
    expect(find.byKey(const Key('selector_periodo')), findsOneWidget);
    expect(find.byKey(const Key('periodo_anterior')), findsOneWidget);
  });

  testWidgets('con solo gastos no es vacío y la ganancia sale en rojo',
      (tester) async {
    await db.into(db.gastos).insert(GastosCompanion.insert(
        monto: 3000, fecha: DateTime(2026, 10, 6), usuarioId: ana));
    await montar(tester);

    expect(find.text('Sin ventas en este periodo'), findsNothing);
    expect(en('reporte_ganancia', r'-$3.000'), findsOneWidget);
    final ganancia = tester.widget<Monto>(find.descendant(
        of: find.byKey(const Key('reporte_ganancia')),
        matching: find.byType(Monto)));
    expect(ganancia.tono, TonoMonto.sale);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra fiado, deuda y el mejor día', (tester) async {
    await vender(2000, DateTime(2026, 9, 30), fiado: true);
    await vender(3000, DateTime(2026, 10, 6), fiado: true);
    await vender(1000, DateTime(2026, 10, 5));
    await db.into(db.pagosFiado).insert(PagosFiadoCompanion.insert(
        clienteId: pedro,
        monto: 1000,
        fecha: DateTime(2026, 10, 7),
        usuarioId: ana));
    await montar(tester);

    expect(find.text(r'Fiaste $3.000 · Cobraste $1.000'), findsOneWidget);
    expect(find.text(r'Deuda: $2.000 → $4.000'), findsOneWidget);
    expect(find.text(r'Mejor día: martes 6 · $3.000'), findsOneWidget);
    expect(tester.widget<BarraDia>(find.byKey(const Key('barra_6'))).resaltada,
        isTrue);
  });

  testWidgets('una venta registrada con la pantalla abierta aparece sola',
      (tester) async {
    await montar(tester);
    expect(find.text('Sin ventas en este periodo'), findsOneWidget);

    await vender(7000, DateTime(2026, 10, 7, 9));
    await tester.pumpAndSettle();

    expect(en('reporte_ventas', r'$7.000'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/reportes/reportes_screen_test.dart`
Expected: FAIL (`reportes_screen.dart` no existe).

- [ ] **Step 3: Implementar**

`lib/screens/reportes/reportes_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/reporte_providers.dart';
import '../../repositories/reporte_repository.dart';
import '../../ui/colores_app.dart';
import '../../ui/estado_vacio.dart';
import '../../ui/monto.dart';
import '../../ui/selector_segmentado.dart';
import '../../ui/tarjeta_monto.dart';
import '../../util/fecha_util.dart';
import '../../util/formato_moneda.dart';
import '../../util/periodo.dart';
import '../../util/texto_util.dart';
import 'barras_por_dia.dart';

/// Reporte por semana o por mes: cómo le fue, caja y banco, fiado y ventas
/// por día, comparado con el periodo anterior.
class ReportesScreen extends ConsumerStatefulWidget {
  const ReportesScreen({super.key, this.hoy});

  /// Día que cuenta como hoy; solo para pruebas (por defecto, hoy).
  final DateTime? hoy;

  @override
  ConsumerState<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends ConsumerState<ReportesScreen> {
  late final DateTime _hoy = inicioDelDia(widget.hoy ?? DateTime.now());
  late Periodo _periodo = Periodo.actual(TipoPeriodo.semana, _hoy);

  @override
  Widget build(BuildContext context) {
    final esActual = _periodo.contiene(_hoy);
    final comparacionAsync = ref.watch(
        comparacionReporteProvider((periodo: _periodo, hoy: _hoy)));

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SelectorSegmentado<TipoPeriodo>(
            key: const Key('selector_periodo'),
            opciones: const {
              TipoPeriodo.semana: 'Semana',
              TipoPeriodo.mes: 'Mes',
            },
            valor: _periodo.tipo,
            onCambio: (tipo) =>
                setState(() => _periodo = Periodo.actual(tipo, _hoy)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                key: const Key('periodo_anterior'),
                tooltip: 'Anterior',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () =>
                    setState(() => _periodo = _periodo.anterior),
              ),
              Expanded(
                child: Text(
                  _periodo.titulo,
                  key: const Key('titulo_periodo'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                key: const Key('periodo_siguiente'),
                tooltip: 'Siguiente',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: esActual
                    ? null
                    : () => setState(() => _periodo = _periodo.siguiente),
              ),
            ],
          ),
          const SizedBox(height: 8),
          comparacionAsync.when(
            data: (comparacion) => comparacion.actual.vacio
                ? const EstadoVacio(
                    icono: Icons.bar_chart_rounded,
                    titulo: 'Sin ventas en este periodo',
                  )
                : _Contenido(
                    comparacion: comparacion,
                    tipo: _periodo.tipo,
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.comparacion, required this.tipo});

  final ComparacionReporte comparacion;
  final TipoPeriodo tipo;

  @override
  Widget build(BuildContext context) {
    final r = comparacion.actual;
    final contra =
        tipo == TipoPeriodo.semana ? 'vs. semana pasada' : 'vs. mes pasado';
    const gris = TextStyle(color: ColoresApp.textoSecundario);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Titulo('¿Cómo te fue?'),
        TarjetaMonto(
          key: const Key('reporte_ventas'),
          etiqueta: 'Ventas',
          valor: r.ventas,
          tono: TonoMonto.entra,
          tamano: 28,
        ),
        _TextoCambio(
            key: const Key('cambio_ventas'),
            cambio: comparacion.cambioVentas,
            contra: contra),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TarjetaMonto(
                key: const Key('reporte_gastos'),
                etiqueta: 'Gastos',
                valor: r.gastos,
                tono: TonoMonto.sale,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TarjetaMonto(
                    key: const Key('reporte_ganancia'),
                    etiqueta: 'Ganancia',
                    valor: r.ganancia,
                    tono: r.ganancia < 0 ? TonoMonto.sale : TonoMonto.neutro,
                  ),
                  _TextoCambio(
                      key: const Key('cambio_ganancia'),
                      cambio: comparacion.cambioGanancia,
                      contra: contra),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${plural(r.cantidadVentas, 'venta', 'ventas')} · '
          'promedio ${formatoMoneda(r.ventaPromedio)}',
          key: const Key('texto_promedio'),
          style: gris,
        ),
        const _Titulo('Caja y banco'),
        Row(
          children: [
            Expanded(
              child: TarjetaMonto(
                key: const Key('reporte_efectivo'),
                etiqueta: 'Efectivo',
                valor: r.recibidoEfectivo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TarjetaMonto(
                key: const Key('reporte_transferencia'),
                etiqueta: 'Transferencia',
                valor: r.recibidoTransferencia,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Gastos ${formatoMoneda(r.gastos)}',
            key: const Key('texto_gastos_caja'), style: gris),
        const _Titulo('Fiado'),
        Text(
          'Fiaste ${formatoMoneda(r.fiado)} · '
          'Cobraste ${formatoMoneda(r.cobrado)}',
          key: const Key('texto_fiado'),
        ),
        const SizedBox(height: 4),
        Text(
          'Deuda: ${formatoMoneda(r.deudaInicio)} → '
          '${formatoMoneda(r.deudaFin)}',
          key: const Key('texto_deuda'),
        ),
        const _Titulo('Ventas por día'),
        BarrasPorDia(ventasPorDia: r.ventasPorDia, mejorDia: r.mejorDia),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(texto,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
}

/// "↑ 12 % vs. semana pasada" en verde, "↓ 8 % …" en rojo o "= …" en gris;
/// nada si no hay porcentaje.
class _TextoCambio extends StatelessWidget {
  const _TextoCambio({super.key, required this.cambio, required this.contra});

  final int? cambio;
  final String contra;

  @override
  Widget build(BuildContext context) {
    final valor = cambio;
    if (valor == null) return const SizedBox.shrink();
    final (texto, color) = valor > 0
        ? ('↑ $valor % $contra', ColoresApp.entra)
        : valor < 0
            ? ('↓ ${-valor} % $contra', ColoresApp.sale)
            : ('= $contra', ColoresApp.textoSecundario);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(texto,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/screens/reportes`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/reportes/reportes_screen.dart test/screens/reportes/reportes_screen_test.dart
git commit -m "Add the Reportes screen with week and month navigation"
```

---

### Task 5: Botón "Ver reportes" en Inicio

**Files:**
- Modify: `lib/screens/home/resumen_screen.dart`
- Modify: `test/screens/home/resumen_screen_test.dart`

**Interfaces:**
- Consumes: `ReportesScreen` (Task 4), `sesionProvider.esAdmin`, `BotonPrincipal(variante: VarianteBoton.contorno, icono:)`.
- Produces: botón con llave `boton_ver_reportes`.

- [ ] **Step 1: Escribir las pruebas que fallan**

En `test/screens/home/resumen_screen_test.dart` agregar imports:

```dart
import 'package:app_ventas/screens/reportes/reportes_screen.dart';

import '../../support/montaje.dart';
```

y dentro de `main()`:

```dart
  Future<void> montarConSesion(WidgetTester tester, String rol) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await containerConSesion(db, nombre: 'Caro', rol: rol);
    addTearDown(container.dispose);
    await tester.pumpWidget(appDePrueba(container,
        inicio: const Scaffold(body: ResumenScreen())));
    await tester.pumpAndSettle();
  }

  testWidgets('el administrador ve Ver reportes y lo abre', (tester) async {
    await montarConSesion(tester, 'admin');

    await tester.tap(find.byKey(const Key('boton_ver_reportes')));
    await tester.pumpAndSettle();

    expect(find.byType(ReportesScreen), findsOneWidget);
  });

  testWidgets('el vendedor no ve Ver reportes', (tester) async {
    await montarConSesion(tester, 'vendedor');

    expect(find.byKey(const Key('boton_ver_reportes')), findsNothing);
  });
```

- [ ] **Step 2: Correr y ver que falla**

Run: `flutter test test/screens/home/resumen_screen_test.dart`
Expected: FAIL (no existe `boton_ver_reportes`).

- [ ] **Step 3: Implementar**

En `lib/screens/home/resumen_screen.dart`:
- imports:

```dart
import '../../providers/sesion_provider.dart';
import '../reportes/reportes_screen.dart';
```

- en `build`, junto a los otros `ref.watch`:

```dart
    final esAdmin = ref.watch(sesionProvider).esAdmin;
```

- justo después del `Row` de los botones "+ Venta" / "− Gasto" (antes de `const SizedBox(height: 24),` y "Por vendedor"):

```dart
        if (esAdmin) ...[
          const SizedBox(height: 12),
          BotonPrincipal(
            key: const Key('boton_ver_reportes'),
            texto: 'Ver reportes',
            icono: Icons.bar_chart_rounded,
            variante: VarianteBoton.contorno,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReportesScreen()),
            ),
          ),
        ],
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `flutter test test/screens/home`
Expected: PASS (las pruebas viejas de Inicio no tienen sesión: el botón no aparece y nada cambia para ellas).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home/resumen_screen.dart test/screens/home/resumen_screen_test.dart
git commit -m "Open reports from Inicio for the administrator"
```

---

### Task 6: Verificación final

**Files:**
- Modify: `docs/superpowers/specs/2026-10-06-vecitienda-reportes-design.md` (línea `**Estado:**`)

- [ ] **Step 1: Análisis y suite completa**

Run: `flutter analyze` y `flutter test`
Expected: "No issues found!" y todas las pruebas pasan.

- [ ] **Step 2: Compilar**

Run: `flutter build apk --debug`
Expected: "Built build\app\outputs\flutter-apk\app-debug.apk". (El recorrido manual queda para un celular real: el emulador `app_ventas_ligero` no entrega toques.)

- [ ] **Step 3: Marcar la especificación**

Cambiar `**Estado:** Diseño aprobado, pendiente de plan` por `**Estado:** Implementado (falta el recorrido manual en un celular real)`.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-10-06-vecitienda-reportes-design.md
git commit -m "Mark Fase 3B as implemented"
```
