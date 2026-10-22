#!/usr/bin/env python3
"""Añade proveedores gratuitos a OmniRoute y construye un combo con los que responden.

Dos clases de proveedor:

- **Con clave**: se leen de ~/.secrets/omniroute-free.env (modo 600), nunca de
  argumentos, para que no queden en el historial ni en la lista de procesos.
- **Sin clave**: se registran con una credencial ficticia, porque el runtime de
  OmniRoute exige una aunque el proveedor no la use. Hoy es el caso de Cloudflare
  AI Playground, que necesita Chromium (just omniroute-browser).

  omniroute-free.py --list     # proveedores soportados y dónde sacar cada clave
  omniroute-free.py            # añade, prueba de verdad y crea/actualiza el combo
  omniroute-free.py --combo free --no-opencode

Un proveedor solo entra en el combo si supera una petición de chat real, no solo
el test de configuración de OmniRoute: varios proveedores pasan ese test y luego
devuelven 401.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

HOME = Path.home()
ENV_FILE = HOME / ".secrets/omniroute-free.env"
GATEWAY_KEY_FILE = HOME / ".secrets/omniroute-key"
GATEWAY = "http://127.0.0.1:20128"
PLAYWRIGHT = HOME / ".local/share/omniroute/lib/node_modules/omniroute/node_modules/playwright/cli.js"

# El orden de esta lista es el orden de prioridad del combo. `max` limita
# cuántos modelos de ese proveedor entran: uno basta salvo que aporte variedad.
PROVIDERS = [
    {
        "id": "gemini", "env": "GEMINI_API_KEY", "label": "Google AI Studio",
        "url": "https://aistudio.google.com/apikey",
        "prefer": ["gemini-3-flash-preview", "gemini-3.1-flash-lite", "gemini-2.5-flash", "gemini"],
        "note": "15 RPM · sin tarjeta · la más generosa",
    },
    {
        "id": "cloudflare-playground", "env": "", "keyless": True,
        "label": "Cloudflare Playground", "url": "https://playground.ai.cloudflare.com",
        "prefer": ["glm-5.2", "deepseek-v4-flash", "kimi-k2.7-code", "glm", "qwen"],
        "max": 3, "note": "sin clave · necesita Chromium · 10-30 s por petición",
    },
    {
        "id": "groq", "env": "GROQ_API_KEY", "label": "Groq",
        "url": "https://console.groq.com/keys",
        "prefer": ["gpt-oss-120b", "qwen", "llama-3.3", "llama"],
        "note": "30 RPM · 1.000-14.400 peticiones/día · muy rápido",
    },
    {
        "id": "cerebras", "env": "CEREBRAS_API_KEY", "label": "Cerebras",
        "url": "https://cloud.cerebras.ai",
        "prefer": ["gpt-oss-120b", "qwen", "llama"],
        "note": "30 RPM · 14.400 peticiones/día · el más rápido",
    },
    {
        "id": "zai", "env": "ZAI_API_KEY", "label": "Z.AI (GLM)",
        "url": "https://z.ai/manage-apikey/apikey-list",
        "prefer": ["glm-4.5-flash", "glm-4.7-flash", "flash", "glm"],
        "note": "modelos flash gratis · GLM-5 en el plan gratuito",
    },
    {
        "id": "mistral", "env": "MISTRAL_API_KEY", "label": "Mistral",
        "url": "https://console.mistral.ai/api-keys",
        "prefer": ["mistral-small-latest", "mistral-small", "codestral", "open-mistral"],
        "note": "tier Experiment · ~1.000 M tokens/mes · pide teléfono",
    },
    {
        "id": "openrouter", "env": "OPENROUTER_API_KEY", "label": "OpenRouter",
        "url": "https://openrouter.ai/settings/keys",
        "prefer": ["openrouter/free", ":free"],
        "note": "50 peticiones/día (1.000 con 10 $ comprados) · muchos modelos",
    },
    {
        "id": "sambanova", "env": "SAMBANOVA_API_KEY", "label": "SambaNova",
        "url": "https://cloud.sambanova.ai/apis",
        "prefer": ["DeepSeek", "Llama-3.3-70B", "llama"],
        "note": "tier gratuito · sin tarjeta",
    },
    {
        "id": "nous-research", "env": "NOUS_API_KEY", "label": "Nous Research",
        "url": "https://portal.nousresearch.com",
        "prefer": ["hermes"], "note": "50 RPM · 500k TPM · plan gratuito",
    },
    {
        "id": "cohere", "env": "COHERE_API_KEY", "label": "Cohere",
        "url": "https://dashboard.cohere.com/api-keys",
        "prefer": ["command-a", "command-r-plus", "command-r"],
        "note": "1.000 llamadas/mes · solo uso no comercial",
    },
    {
        "id": "huggingface", "env": "HF_TOKEN", "label": "Hugging Face",
        "url": "https://huggingface.co/settings/tokens",
        "prefer": ["Qwen2.5-7B", "Llama-3.2-8B", "Mistral-7B", "Qwen", "Llama"],
        "note": "créditos gratis · arranques en frío de 10-30 s",
    },
]

TEMPLATE = """\
# Claves de proveedores gratuitos para OmniRoute.
# Rellena solo las que quieras; las vacías se ignoran y el proveedor se salta.
# Permisos: 600. Este archivo no se versiona.
#
# Después: just omniroute-free
#
# Ninguna de estas claves requiere tarjeta. Cloudflare Playground no aparece
# aquí: no usa clave, solo necesita Chromium (just omniroute-browser).

# Google AI Studio — https://aistudio.google.com/apikey
GEMINI_API_KEY=

# Groq — https://console.groq.com/keys  (el más rápido del tier gratis)
GROQ_API_KEY=

# Cerebras — https://cloud.cerebras.ai
CEREBRAS_API_KEY=

# Z.AI / GLM — https://z.ai/manage-apikey/apikey-list
ZAI_API_KEY=

# Mistral — https://console.mistral.ai/api-keys  (pide verificación por teléfono)
MISTRAL_API_KEY=

# OpenRouter — https://openrouter.ai/settings/keys  (modelos :free)
OPENROUTER_API_KEY=

# SambaNova — https://cloud.sambanova.ai/apis
SAMBANOVA_API_KEY=

# Nous Research — https://portal.nousresearch.com
NOUS_API_KEY=

# Cohere — https://dashboard.cohere.com/api-keys  (solo uso no comercial)
COHERE_API_KEY=

# Hugging Face — https://huggingface.co/settings/tokens
HF_TOKEN=
"""


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
def load_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return values
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        name, _, value = line.partition("=")
        value = value.strip().strip('"').strip("'")
        if value:
            values[name.strip()] = value
    return values


def gateway_key() -> str:
    try:
        return GATEWAY_KEY_FILE.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def api(path: str, payload: dict | None = None, timeout: float = 90.0):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(f"{GATEWAY}{path}", data=data)
    req.add_header("Authorization", f"Bearer {gateway_key()}")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.load(resp)


def cli(args: list[str], stdin: str | None = None, timeout: int = 240) -> subprocess.CompletedProcess:
    return subprocess.run(["omniroute", *args], input=stdin, capture_output=True,
                          text=True, timeout=timeout)


def cli_json(args: list[str], stdin: str | None = None, timeout: int = 240) -> dict:
    out = cli(args, stdin=stdin, timeout=timeout).stdout
    start = out.find("{")
    if start < 0:
        return {}
    try:
        return json.loads(out[start:])
    except json.JSONDecodeError:
        return {}


def connected_providers() -> set[str]:
    data = cli_json(["providers", "list", "--json"])
    return {c.get("provider", "") for c in data.get("providers", [])}


def models_of(provider: str, cache: dict) -> list[str]:
    if "data" not in cache:
        try:
            cache["data"] = api("/v1/models")["data"]
        except (urllib.error.URLError, OSError, KeyError):
            cache["data"] = []
    return [m["id"] for m in cache["data"] if m.get("owned_by") == provider]


def pick_models(ids: list[str], preferences: list[str], limit: int) -> list[str]:
    chosen: list[str] = []
    for want in preferences:
        for mid in ids:
            if mid in chosen:
                continue
            if want.lower() in mid.lower():
                chosen.append(mid)
                if len(chosen) >= limit:
                    return chosen
    for mid in ids:
        if mid not in chosen:
            chosen.append(mid)
            if len(chosen) >= limit:
                break
    return chosen


def chat_works(model: str) -> tuple[bool, str]:
    try:
        resp = api("/v1/chat/completions", {
            "model": model,
            "messages": [{"role": "user", "content": "Di exactamente: hola"}],
            "max_tokens": 64,
        }, timeout=150)
    except urllib.error.HTTPError as exc:
        try:
            detail = json.load(exc).get("error", {}).get("message", "")
        except Exception:
            detail = ""
        return False, (detail or f"HTTP {exc.code}")[:90]
    except (urllib.error.URLError, OSError) as exc:
        return False, str(exc)[:90]
    if resp.get("choices"):
        text = (resp["choices"][0].get("message") or {}).get("content") or ""
        return True, text.replace("\n", " ")[:60]
    return False, str(resp.get("error", ""))[:90]


# ---------------------------------------------------------------------------
# Comandos
# ---------------------------------------------------------------------------
def cmd_list(values: dict[str, str]) -> int:
    connected = connected_providers()
    print(f"\n  {'proveedor':<24} {'clave':<8} {'conectado':<11} límite")
    print(f"  {'-'*24} {'-'*8} {'-'*11} {'-'*44}")
    for p in PROVIDERS:
        env = p.get("env", "")
        has_key = "—" if p.get("keyless") else ("sí" if env in values else "—")
        conn = "sí" if p["id"] in connected else "no"
        print(f"  {p['label']:<24} {has_key:<8} {conn:<11} {p['note']}")
        if p.get("url"):
            print(f"  {'':<24} {p['url']}")
    print(f"\n  Archivo de claves: {ENV_FILE}")
    if not ENV_FILE.exists():
        print("  (no existe; se crea la plantilla al ejecutar sin --list)")
    return 0


def cmd_add(values: dict[str, str], combo: str, refresh_opencode: bool) -> int:
    connected = connected_providers()
    cache: dict = {}
    winners: list[str] = []
    rows: list[tuple[str, str]] = []
    missing_browser = False

    for p in PROVIDERS:
        pid, label = p["id"], p["label"]
        key = values.get(p.get("env", ""), "")
        keyless = bool(p.get("keyless"))
        limit = int(p.get("max", 1))

        if pid not in connected:
            if not key and not keyless:
                rows.append((label, "sin clave"))
                continue

            print(f"  → añadiendo {label}…", flush=True)
            args = ["providers", "add", pid, "--yes", "--json"]
            stdin = None
            if key:
                args += ["--credential-stdin"]
                stdin = key
            else:
                # El runtime exige credencial aunque el proveedor no la use.
                args += ["--credential", "noauth", "--allow-no-credential"]
            if not cli_json(args, stdin=stdin).get("connection"):
                rows.append((label, "error al añadir"))
                continue

        test = cli(["providers", "test", pid])
        out = (test.stdout or "") + (test.stderr or "")
        if "FAIL" in out or "OK" not in out:
            rows.append((label, "test fallido"))
            continue

        candidates = pick_models(models_of(pid, cache), p["prefer"], limit)
        if not candidates:
            rows.append((label, "sin modelos"))
            continue

        for model in candidates:
            ok, detail = chat_works(model)
            short = model.split("/", 1)[-1]
            if ok:
                winners.append(model)
                rows.append((label, f"OK · {short}"))
            else:
                rows.append((label, f"falla · {short}: {detail}"))
                if "Playwright" in detail or "Chromium" in detail:
                    missing_browser = True

    print(f"\n  {'proveedor':<24} resultado")
    print(f"  {'-'*24} {'-'*58}")
    for label, status in rows:
        mark = "✓" if status.startswith("OK") else "·"
        print(f"  {mark} {label:<22} {status}")

    if missing_browser:
        print("\n  Cloudflare Playground necesita Chromium:")
        print("    just omniroute-browser")

    if not winners:
        print("\n  Ningún proveedor respondió. Rellena alguna clave en:")
        print(f"    {ENV_FILE}")
        return 1

    print(f"\n  Creando combo «{combo}» con {len(winners)} modelos…")
    cli(["combo", "delete", combo, "--yes"])
    created = cli(["combo", "create", combo, "--strategy", "priority",
                   "--models", ",".join(winners)])
    if "creada" not in created.stdout.lower() and created.returncode != 0:
        print(f"  ! no se pudo crear el combo: {created.stderr[:200]}")
        return 1

    for model in winners:
        print(f"    · {model}")

    if refresh_opencode:
        script = Path(__file__).with_name("opencode-providers.py")
        result = subprocess.run([sys.executable, str(script)], capture_output=True, text=True)
        if result.returncode == 0:
            print("\n  OpenCode actualizado. Prueba:")
            print(f"    opencode run --model omniroute/combo/{combo} \"hola\"")
        else:
            print(f"\n  ! OpenCode no se actualizó: {result.stderr[:200]}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Proveedores gratuitos para OmniRoute")
    ap.add_argument("--list", action="store_true", help="muestra proveedores y URLs")
    ap.add_argument("--combo", default="free", help="nombre del combo (por defecto free)")
    ap.add_argument("--no-opencode", action="store_true",
                    help="no actualiza la configuración de OpenCode al terminar")
    args = ap.parse_args()

    if not ENV_FILE.exists() and not args.list:
        ENV_FILE.parent.mkdir(parents=True, exist_ok=True)
        os.chmod(ENV_FILE.parent, 0o700)
        ENV_FILE.write_text(TEMPLATE, encoding="utf-8")
        os.chmod(ENV_FILE, 0o600)
        print(f"  Plantilla creada: {ENV_FILE}")
        print("  Rellena las claves que quieras y vuelve a ejecutar.")
        return 0

    values = load_env(ENV_FILE)
    if args.list:
        return cmd_list(values)
    return cmd_add(values, args.combo, not args.no_opencode)


if __name__ == "__main__":
    sys.exit(main())
