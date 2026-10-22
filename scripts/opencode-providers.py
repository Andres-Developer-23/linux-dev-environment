#!/usr/bin/env python3
"""Integra OmniRoute en la configuración de OpenCode V2.

OmniRoute documenta `omniroute setup-opencode`, pero escribe el formato de la
V1 (`provider`, `npm`, `options.baseURL`). OpenCode V2 usa `providers`,
`package` y `settings`. Este script escribe el formato correcto sin tocar el
resto de la configuración.

Uso:
  opencode-providers.py                 # añade/actualiza el proveedor omniroute
  opencode-providers.py --sync          # además importa el catálogo de /v1/models
  opencode-providers.py --set-default   # deja omniroute/auto como modelo por defecto
  opencode-providers.py --print         # muestra el resultado sin escribir

El archivo de OpenCode admite JSONC, así que se respetan comentarios y comas
finales al leer. Al escribir se normaliza a JSON con sangría de 2 espacios y se
guarda un backup del archivo anterior.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_URL = "http://127.0.0.1:20128"
DEFAULT_KEY_FILE = Path("~/.secrets/omniroute-key").expanduser()
DEFAULT_CONFIG = Path("~/.config/opencode/opencode.jsonc").expanduser()

# Modelos de enrutamiento que OmniRoute expone siempre. Los nombres son
# estables: apuntan a una política, no a un proveedor concreto. La lista
# completa del catálogo son cientos de entradas, muchas inutilizables, así que
# por defecto solo se exponen estas y los combos que se pidan con --combos.
ROUTING_MODELS = {
    "auto": "Auto — fallback entre proveedores",
    "auto/cheap": "Auto — el más barato",
    "auto/coding": "Auto — código",
    "auto/fast": "Auto — el más rápido",
    "auto/vision": "Auto — con visión",
    "auto/best-coding": "Auto — el mejor para código",
}


# ---------------------------------------------------------------------------
# Lectura de JSONC
# ---------------------------------------------------------------------------
def strip_jsonc(text: str) -> str:
    """Quita comentarios y comas finales respetando las cadenas."""
    out: list[str] = []
    i, n = 0, len(text)
    in_string = False
    while i < n:
        ch = text[i]
        if in_string:
            out.append(ch)
            if ch == "\\" and i + 1 < n:  # escape dentro de la cadena
                out.append(text[i + 1])
                i += 2
                continue
            if ch == '"':
                in_string = False
            i += 1
            continue

        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue

        if text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j == -1 else j
            continue

        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j == -1 else j + 2
            continue

        out.append(ch)
        i += 1

    return remove_trailing_commas("".join(out))


def remove_trailing_commas(text: str) -> str:
    """Quita la coma que precede a } o ], también fuera de cadenas."""
    out: list[str] = []
    i, n = 0, len(text)
    in_string = False
    while i < n:
        ch = text[i]
        if in_string:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
        if ch == ",":
            j = i + 1
            while j < n and text[j] in " \t\r\n":
                j += 1
            if j < n and text[j] in "}]":
                i += 1  # se descarta la coma
                continue
        out.append(ch)
        i += 1
    return "".join(out)


def load_config(path: Path) -> dict:
    if not path.exists():
        return {"$schema": "https://opencode.ai/config.json"}
    raw = path.read_text(encoding="utf-8")
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return json.loads(strip_jsonc(raw))


# ---------------------------------------------------------------------------
# Catálogo
# ---------------------------------------------------------------------------
def fetch_models(url: str, key: str, timeout: float = 5.0) -> list[dict]:
    req = urllib.request.Request(f"{url}/v1/models")
    if key:
        req.add_header("Authorization", f"Bearer {key}")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        data = json.load(resp)
    items = data.get("data", data if isinstance(data, list) else [])
    return [m for m in items if isinstance(m, dict) and m.get("id")]


def read_key(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def discover_combos() -> list[str]:
    """Lee los combos de la CLI; no aparecen en /v1/models."""
    import shutil
    import subprocess

    exe = shutil.which("omniroute")
    if not exe:
        return []
    try:
        out = subprocess.run(
            [exe, "--output", "json", "combo", "list"],
            capture_output=True, text=True, timeout=20,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return []
    start = out.find("{")
    if start < 0:
        return []
    try:
        data = json.loads(out[start:])
    except json.JSONDecodeError:
        return []
    return [c["name"] for c in data.get("combos", []) if c.get("name")]


# ---------------------------------------------------------------------------
# Construcción del bloque
# ---------------------------------------------------------------------------
def provider_block(url: str, key_file: Path) -> dict:
    models = {mid: {"name": name} for mid, name in ROUTING_MODELS.items()}
    return {
        "name": "OmniRoute",
        "package": "@opencode/ai/providers/openai-compatible",
        "env": ["OMNIROUTE_API_KEY"],
        "settings": {
            "baseURL": f"{url}/v1",
            # {file:...} evita depender del entorno del servicio en segundo plano.
            "apiKey": "{file:" + str(key_file) + "}",
        },
        "models": models,
    }


def merge(config: dict, url: str, key_file: Path, catalog: list[dict] | None,
          combos: list[str] | None = None) -> dict:
    providers = config.setdefault("providers", {})
    block = provider_block(url, key_file)
    existing = providers.get("omniroute") or {}

    # Conserva modelos que el usuario haya añadido a mano.
    merged_models = dict(block["models"])
    for mid, spec in (existing.get("models") or {}).items():
        merged_models.setdefault(mid, spec)

    for name in combos or []:
        merged_models.setdefault(f"combo/{name}", {"name": f"Combo «{name}»"})

    if catalog:
        for item in catalog:
            mid = item["id"]
            if mid in merged_models:
                continue
            spec: dict = {"name": item.get("name") or mid}
            own = item.get("owned_by")
            if own:
                spec["name"] = f"{mid} · {own}"
            merged_models[mid] = spec

    block["models"] = merged_models

    # Respeta un baseURL o una apiKey puestos a mano.
    for field, value in (existing.get("settings") or {}).items():
        block["settings"].setdefault(field, value)

    providers["omniroute"] = block
    return config


def write_config(path: Path, config: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = 0o644
    if path.exists():
        mode = path.stat().st_mode & 0o777
        stamp = time.strftime("%Y%m%d-%H%M%S")
        backup = path.with_suffix(path.suffix + f".bak-{stamp}")
        shutil.copy2(path, backup)
        print(f"  backup: {backup}")
    path.write_text(json.dumps(config, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.chmod(path, mode)


# ---------------------------------------------------------------------------
def main() -> int:
    ap = argparse.ArgumentParser(description="Integra OmniRoute en OpenCode V2")
    ap.add_argument("--url", default=os.environ.get("OMNIROUTE_URL", DEFAULT_URL),
                    help=f"base del gateway (por defecto {DEFAULT_URL})")
    ap.add_argument("--key-file", type=Path, default=DEFAULT_KEY_FILE,
                    help="archivo con la API key de OmniRoute")
    ap.add_argument("--config", type=Path, default=DEFAULT_CONFIG,
                    help="opencode.jsonc a modificar")
    ap.add_argument("--sync", action="store_true",
                    help="importa TODO el catálogo de /v1/models (cientos de modelos)")
    ap.add_argument("--combos", default="",
                    help="nombres de combo separados por comas (por defecto: los detecta del gateway)")
    ap.add_argument("--set-default", nargs="?", const="auto", default=None,
                    metavar="MODELO",
                    help="fija el modelo por defecto (por defecto auto)")
    ap.add_argument("--print", dest="dry", action="store_true",
                    help="muestra el JSON resultante sin escribir")
    ap.add_argument("--check", action="store_true",
                    help="sale con 0 si el proveedor está configurado (para verify.sh)")
    args = ap.parse_args()

    if args.check:
        config = load_config(args.config)
        block = (config.get("providers") or {}).get("omniroute")
        if not block:
            print("sin proveedor omniroute en la configuración de OpenCode", file=sys.stderr)
            return 1
        models = len(block.get("models") or {})
        print(f"omniroute: {models} modelos, baseURL {(block.get('settings') or {}).get('baseURL', '?')}")
        return 0

    url = args.url.rstrip("/")
    key = read_key(args.key_file)
    if not key:
        print(f"  ! no hay API key en {args.key_file}", file=sys.stderr)

    catalog = None
    if args.sync:
        try:
            catalog = fetch_models(url, key)
            print(f"  catálogo: {len(catalog)} modelos en {url}/v1/models")
        except (urllib.error.URLError, OSError, json.JSONDecodeError) as exc:
            print(f"  ! no se pudo leer el catálogo: {exc}", file=sys.stderr)

    config = load_config(args.config)
    combos = [c.strip() for c in args.combos.split(",") if c.strip()]
    if not combos:
        combos = discover_combos()
    config = merge(config, url, args.key_file, catalog, combos)

    if args.set_default:
        config["model"] = f"omniroute/{args.set_default}"

    if args.dry:
        print(json.dumps(config, indent=2, ensure_ascii=False))
        return 0

    write_config(args.config, config)
    total = len(config["providers"]["omniroute"]["models"])
    print(f"  ✓ proveedor omniroute con {total} modelos en {args.config}")
    if args.set_default:
        print(f"  ✓ modelo por defecto: omniroute/{args.set_default}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
