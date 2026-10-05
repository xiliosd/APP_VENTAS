"""Genera el isotipo y los íconos Android de VeciTienda a partir del logo.

Uso, desde la raíz del repositorio:
    python tool/generar_iconos.py

Requiere Pillow (pip install pillow). No es dependencia de la app: si llega
una versión mejor del logo, se reemplaza docs/marca/logo-vecitienda.jpeg y se
vuelve a correr.
"""
from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
LOGO = RAIZ / "docs" / "marca" / "logo-vecitienda.jpeg"
RES = RAIZ / "android" / "app" / "src" / "main" / "res"
DENSIDADES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

# El isotipo ocupa la franja superior del logo; el nombre "VeciTienda"
# empieza más abajo (~62 % de la altura). Se corta antes, al 59 %.
FIN_ISOTIPO = 0.59

XML_ADAPTATIVO = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""

XML_COLOR = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
"""


def recortar_isotipo(logo):
    """Recorta el isotipo, vuelve transparente el blanco y lo deja cuadrado."""
    rgb = logo.convert("RGB")
    franja = rgb.crop((0, 0, rgb.width, int(rgb.height * FIN_ISOTIPO)))
    tinta = franja.convert("L").point(lambda v: 255 if v < 235 else 0)
    isotipo = franja.crop(tinta.getbbox()).convert("RGBA")
    # get_flattened_data reemplaza a getdata (obsoleto desde Pillow 12).
    pixeles = getattr(isotipo, "get_flattened_data", isotipo.getdata)()
    isotipo.putdata([(r, g, b, _alfa(r, g, b)) for (r, g, b, _) in pixeles])
    return _cuadrar(isotipo)


def _alfa(r, g, b):
    """Opaco para la tinta, transparente para el blanco, suave en los bordes."""
    luz = (r + g + b) / 3
    if luz >= 245:
        return 0
    if luz <= 200:
        return 255
    return int((245 - luz) / 45 * 255)


def _cuadrar(imagen, margen=0.08):
    lado = int(max(imagen.size) * (1 + 2 * margen))
    lienzo = Image.new("RGBA", (lado, lado), (255, 255, 255, 0))
    lienzo.alpha_composite(
        imagen, ((lado - imagen.width) // 2, (lado - imagen.height) // 2)
    )
    return lienzo


def _centrado(isotipo, lado, proporcion):
    lienzo = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    interior = int(lado * proporcion)
    logo = isotipo.resize((interior, interior), Image.LANCZOS)
    lienzo.alpha_composite(logo, ((lado - interior) // 2, (lado - interior) // 2))
    return lienzo


def icono_clasico(isotipo, lado):
    """Isotipo sobre un cuadrado blanco redondeado (Android anterior a 8)."""
    fondo = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    ImageDraw.Draw(fondo).rounded_rectangle(
        (0, 0, lado - 1, lado - 1), radius=lado // 5, fill=(255, 255, 255, 255)
    )
    fondo.alpha_composite(_centrado(isotipo, lado, 0.84))
    return fondo


def primer_plano(isotipo, lado):
    """Capa frontal del ícono adaptativo: isotipo dentro de la zona segura
    (66 dp de 108 dp)."""
    return _centrado(isotipo, lado, 66 / 108)


def main():
    isotipo = recortar_isotipo(Image.open(LOGO))

    destino = RAIZ / "assets" / "marca"
    destino.mkdir(parents=True, exist_ok=True)
    isotipo.resize((512, 512), Image.LANCZOS).save(destino / "isotipo.png")

    for nombre, escala in DENSIDADES.items():
        carpeta = RES / f"mipmap-{nombre}"
        carpeta.mkdir(exist_ok=True)
        icono_clasico(isotipo, int(48 * escala)).save(carpeta / "ic_launcher.png")
        primer_plano(isotipo, int(108 * escala)).save(
            carpeta / "ic_launcher_foreground.png"
        )

    adaptativo = RES / "mipmap-anydpi-v26"
    adaptativo.mkdir(exist_ok=True)
    (adaptativo / "ic_launcher.xml").write_text(XML_ADAPTATIVO, encoding="utf-8")
    (RES / "values" / "ic_launcher_background.xml").write_text(
        XML_COLOR, encoding="utf-8"
    )
    print("Isotipo e íconos generados")


if __name__ == "__main__":
    main()
