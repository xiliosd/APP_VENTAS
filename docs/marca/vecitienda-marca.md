# VeciTienda — Marca e identidad gráfica

**Fecha de recepción:** 2026-10-05
**Estado:** Pendiente de aplicar. Se ejecuta **después** de terminar las 9 tareas de la Fase 2B+2C (respaldo en la nube), como un subproyecto propio con su propio diseño y plan.
**Fuente:** brief entregado por el usuario (transcrito sin cambios de contenido).

## 1. Definición de marca

- **Nombre de la aplicación:** VeciTienda
- **Slogan:** "La tranquilidad de tu tienda, en tu bolsillo."
- **Identidad e isotipo (Logo 1):** un toldo clásico de tienda de barrio integrado con una casita y una flecha ascendente que forma un check de verificación. Simboliza ventas al alza, control, seguridad y crecimiento del negocio local.

## 2. Paleta de colores (basada en el Logo 1)

### Colores principales (marca y navegación)

| Color | Hex | Uso |
|---|---|---|
| Azul Cobalto / Índigo (estructura y confianza) | `#1A539B` | Estructura de la tienda en el logo, headers, barras de navegación, títulos y bordes |
| Verde Esmeralda / Menta (crecimiento y ventas) | `#16A34A` (o `#00B06B`) | Toldo de la tienda, flecha de crecimiento/check en el logo, botones primarios ("Registrar Venta") e indicadores de ingresos |

### Colores secundarios y neutros

| Color | Hex | Uso |
|---|---|---|
| Blanco puro (fondos de tarjetas) | `#FFFFFF` | Contenedores de información, campos de texto y formularios |
| Gris fondo / superficie | `#F8FAFC` | Fondo general de la app, para dar contraste limpio a tarjetas y métricas |
| Gris texto oscuro | `#1E293B` | Textos principales, precios y cifras contables |
| Rojo coral (gastos y alertas) | `#DC2626` | Salidas de dinero, deudas pendientes o alertas de stock |

## 3. Tipografía recomendada

- **Logotipo y títulos:** sans-serif moderna de trazos firmes pero redondeados en las esquinas (ej. Poppins Bold, Nunito ExtraBold u Outfit).
- **Cuerpo de texto y números:** fuente limpia y estructurada para lectura rápida de números contables (ej. Inter, Roboto o System UI).

## 4. Especificaciones CSS / Tailwind (referencia del brief)

```js
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        brand: {
          blue: '#1A539B',
          green: '#16A34A',
          bg: '#F8FAFC',
          dark: '#1E293B',
          danger: '#DC2626'
        }
      },
      fontFamily: {
        sans: ['Inter', 'Poppins', 'sans-serif'],
      }
    },
  },
}
```

```css
:root {
  --color-primary-blue: #1A539B;
  --color-primary-green: #16A34A;
  --color-bg-app: #F8FAFC;
  --color-surface: #FFFFFF;
  --color-text-main: #1E293B;
  --color-danger: #DC2626;

  --font-family-main: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  --border-radius-card: 12px;
  --border-radius-button: 16px;
}
```

La app es Flutter: al aplicarlo, estos valores se traducen a `lib/ui/colores_app.dart` y `lib/ui/tema_app.dart` (no hay Tailwind ni CSS en el proyecto).

## 5. Lineamientos de interfaz

- **Header principal:** azul (`#1A539B`) con el ícono del toldo y la flecha en blanco/verde, para identificar la app al instante.
- **Botón destacado (CTA):** verde (`#16A34A`) con texto blanco para "Registrar Venta"; puede incluir un pequeño ícono de flecha hacia arriba o "+" que refuerce la gráfica del logo.
- **Métricas rápidas (dashboard):**
  - Tarjeta de ingresos: fondo blanco con borde verde claro y la cifra en verde esmeralda (`#16A34A`).
  - Tarjeta de gastos: fondo blanco con borde rojo claro y la cifra en rojo (`#DC2626`).

## Notas para cuando se aplique (no cambian el brief)

- **Contraste:** el verde `#16A34A` da 3.1:1 con texto blanco y sobre blanco; la Fase 2E fijó como regla ≥ 4.5:1 y por eso usa `#15803D`. Al aplicar la marca hay que decidir con el usuario: mantener `#16A34A` solo para el logo/acentos y un verde más oscuro para texto y botones, o aceptar el contraste menor.
- **Radio de botones:** el brief pide 16 px (hoy 12 px en la app); tarjetas 12 px coincide.
- **Logo:** entregado como `docs/marca/logo-vecitienda.jpeg` (JPEG 2816×1536, fondo blanco, isotipo + "VeciTienda" + slogan). Colores observados: azul ≈ `#1F4F96` (contorno y nombre), verde ≈ `#1E9E4A` (toldo y flecha). Para el ícono del lanzador y la app hará falta el isotipo solo (toldo + casita + flecha), cuadrado y con fondo transparente; idealmente en SVG o PNG de al menos 1024×1024. Si no hay vector, se recorta/vectoriza del JPEG.
- **Alcance probable:** nombre en `MaterialApp.title`, `MarcaApp`, nombre e ícono del launcher Android (`android:label`, mipmaps), fuente de títulos (Poppins/Nunito/Outfit) empaquetada, paleta y radios en el tema, header azul en Inicio.
