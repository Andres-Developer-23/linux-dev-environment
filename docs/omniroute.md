# OmniRoute: un gateway local para todos los modelos

OmniRoute es un gateway open source (MIT) que expone **una sola API compatible con
OpenAI** y enruta cada petición hacia el proveedor que corresponda: OpenAI, Anthropic,
Gemini, GLM, Kimi, DeepSeek, Groq, Ollama… Si un proveedor falla o agota su cuota, salta
al siguiente sin que la herramienta cliente se entere.

En este proyecto se instala en tu máquina, escucha solo en `127.0.0.1:20128` y corre como
servicio de usuario. OpenCode lo ve como un proveedor más.

```
                    ┌──────────────────────────────┐
  opencode ────────▶│  OmniRoute  :20128/v1        │
  (proveedor        │  · enruta y hace fallback    │──▶ proveedor A (gratis)
   `omniroute`)     │  · mide cuotas y coste       │──▶ proveedor B
                    │  · dashboard en /dashboard   │──▶ proveedor C
                    └──────────────────────────────┘
```

---

## 1. Qué resuelve

- **Una clave y un endpoint** para todos los modelos: dejas de repartir claves por
  herramientas.
- **Fallback real**: si un proveedor devuelve 429, 5xx o agota su cuota, la petición
  continúa en el siguiente de la lista. Tú no ves el error.
- **Cuotas gratis apiladas**: puedes conectar varios proveedores con plan gratuito y
  consumirlos en orden.
- **Medición**: el panel muestra qué modelo atendió cada petición, cuántos tokens gastó y
  cuánto costó.
- **Compresión de contexto** opcional, para reducir tokens en conversaciones largas.

Lo que **no** hace: no regala cuotas. Cada proveedor impone sus límites y sus términos, y
tú pones la cuenta. OmniRoute solo organiza el acceso.

---

## 2. Instalación

```bash
./install.sh --omniroute
```

La capa hace cinco cosas:

1. Instala el paquete npm en `~/.local/share/omniroute`, **no** en el prefijo global.
   Ese prefijo vive dentro de fnm (`node-versions/v24.22.0/…`) y desaparecería al cambiar
   de versión de Node.
2. Enlaza `~/.local/bin/omniroute`.
3. Escribe y activa el servicio `~/.config/systemd/user/omniroute.service`.
4. Espera a que el gateway responda en `:20128`.
5. Escribe el proveedor `omniroute` en `~/.config/opencode/opencode.jsonc`.

Ocupa unos **3 GB** en disco: el paquete arrastra binarios nativos (onnxruntime, keytar,
playwright) que no se pueden evitar.

> **npm y los scripts de instalación.** npm 11 bloquea los scripts de ciclo de vida salvo
> que se autoricen. El script pasa `--allow-scripts` con la lista que OmniRoute publica.
> Si una versión futura pide otra lista, npm lo dice en el aviso y basta añadir el nombre.

Comprobación:

```bash
omniroute --version
systemctl --user status omniroute --no-pager
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:20128/v1/models   # 401 sin clave
```

---

## 3. Las dos claves

OmniRoute maneja dos secretos distintos:

| Secreto | Para qué | Dónde queda |
|---|---|---|
| **contraseña de administrador** | entrar en el panel y crear/revocar claves | `~/.secrets/omniroute-admin-password` |
| **API key del endpoint** | que OpenCode (o cualquier cliente) llame a `/v1` | `~/.secrets/omniroute-key` |

Las dos las genera el instalador, con permisos `600` dentro de `~/.secrets` (700):

```bash
# Ver la contraseña del panel, si la necesitas
cat ~/.secrets/omniroute-admin-password
```

La API key se crea llamando a la API con la sesión de administrador
(`POST /api/auth/login` → `POST /api/keys`). No hay comando `keys create` en la CLI: el
comando `keys` gestiona claves **de proveedor**, no claves del endpoint.

Si prefieres crear otra a mano: panel → **Endpoints** → *Create key*. El secreto se muestra
una sola vez.

```bash
# Rotar: crea una nueva y revoca la anterior
xdg-open http://127.0.0.1:20128/dashboard
printf '%s\n' 'sk-...' > ~/.secrets/omniroute-key
chmod 600 ~/.secrets/omniroute-key
```

`opencode.jsonc` no contiene la clave: la lee con la sustitución `{file:…}`. Así no depende
del entorno del servicio en segundo plano y no se puede filtrar en un `git diff`.

---

## 4. Cerrado a loopback por defecto

Esto no es un detalle: OmniRoute **arranca escuchando en `0.0.0.0` y sin exigir clave**. Lo
dice él mismo en el registro:

```
⚠ SECURITY: listening on 0.0.0.0 with NO API-key requirement — the inference plane
(/v1/*) is reachable by ANY device that can route to this host, and requests are billed
to your configured providers.
```

La unidad de systemd que escribe este proyecto lo cierra:

```ini
Environment=OMNIROUTE_SERVER_HOST=127.0.0.1
Environment=REQUIRE_API_KEY=true
```

Comprobación:

```bash
ss -ltnp | grep 20128        # debe decir 127.0.0.1:20128, no 0.0.0.0
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:20128/v1/models   # 401
```

Si lo ejecutas a mano (sin systemd), exporta esas dos variables antes:

```bash
OMNIROUTE_SERVER_HOST=127.0.0.1 REQUIRE_API_KEY=true omniroute
```

---

## 5. Conectar proveedores

Este paso es interactivo y hay que hacerlo una vez por proveedor, en
`http://127.0.0.1:20128/dashboard → Providers`.

| Tipo | Cómo se conecta | Ejemplos |
|---|---|---|
| Sin clave | Pulsar *Connect* | OpenCode Free, Pollinations, Kiro |
| Con clave | Pegar la API key | Groq, Gemini, DeepSeek, GLM, Mistral |
| OAuth | Iniciar sesión en el navegador | Anthropic, OpenAI, GitHub Copilot |
| Local | Apuntar a `127.0.0.1:11434` | Ollama, LM Studio, vLLM |

Criterio práctico para un entorno de desarrollo:

1. Empieza por **un proveedor gratuito que funcione** y compruébalo con una petición real
   antes de añadir más. Un `auto` sin ningún destino válido devuelve error.
2. Añade un segundo proveedor de **otro** proveedor upstream. Si los dos son la misma
   empresa, el fallback no sirve de nada: caen juntos.
3. Revisa los términos de cada proveedor. Algunos planes gratuitos prohíben el uso
   automatizado o el reenvío a terceros, y OmniRoute no lo decide por ti: los proveedores
   marcados como `tos: avoid` quedan fuera de `auto` por defecto.

Verifica el catálogo resultante:

```bash
just omniroute-models          # lista de modelos que el gateway puede atender
```

### Proveedores gratuitos: qué sigue funcionando en 2026

Comprobado en octubre de 2026. Casi todos los gateways que se anuncian como «sin clave»
(Pollinations, LLM7, DuckDuckGo, Kilo Gateway) devuelven 401: piden registro igualmente o
tienen el catálogo caducado. La excepción es **Cloudflare AI Playground**, que no pide
cuenta pero funciona con un navegador headless.

| Proveedor | Límite gratis | Registro | Modelos |
|---|---|---|---|
| **Cloudflare Playground** | sin cuota publicada · 10-30 s por petición | **No** (solo Chromium) | GLM-5.2, DeepSeek V4, Kimi K2.7 |
| **Google AI Studio** | 5-15 RPM · 20-1.500 peticiones/día | Sí, sin tarjeta | Gemini Flash |
| **Groq** | 30 RPM · 1.000-14.400/día · ~800 tok/s | Sí, sin tarjeta | gpt-oss, Qwen, Llama |
| **Cerebras** | 30 RPM · 14.400/día · 1M tokens/día | Sí, sin tarjeta | gpt-oss-120b |
| **Z.AI (GLM)** | modelos *flash* gratis | Sí, sin tarjeta | GLM-4.5/4.7 Flash |
| **OpenRouter** | 50/día (1.000 con 10 $ comprados) | Sí, sin tarjeta | 19 modelos `:free` |
| **SambaNova** | tier gratuito | Sí, sin tarjeta | DeepSeek, Llama 70B |
| **Nous Research** | 50 RPM · 500k TPM | Sí, sin tarjeta | Hermes |
| **Mistral** | ~1.000 M tokens/mes | Sí, pide teléfono | Mistral, Codestral |
| **Cohere** | 1.000 llamadas/mes | Sí, sin tarjeta | Command R (no comercial) |
| **Hugging Face** | créditos | Sí, sin tarjeta | serverless, arranques lentos |

Cerebras, Mistral y NVIDIA NIM han ido y venido entre «tier gratis» y «créditos de prueba»;
los límites cambian cada pocos meses. Verifícalo antes de confiar en uno.

### Añadirlos: un archivo y un comando

`just omniroute-free` lee las claves de `~/.secrets/omniroute-free.env` (600), registra cada
proveedor, le hace una petición de chat real y crea el combo `free` **solo con los que
responden**. Los que fallan se listan y no entran.

```bash
just omniroute-browser      # solo la primera vez: Chromium para Cloudflare (~400 MB)
just omniroute-free-list    # tabla con la URL de cada clave
nano ~/.secrets/omniroute-free.env
just omniroute-free
opencode run --model omniroute/combo/free "hola"
```

**Por qué una petición real y no solo `providers test`:** ese test valida la configuración,
no la credencial. Pollinations, LLM7 y Kilo Gateway lo pasan y luego devuelven 401. El
script manda un chat con `max_tokens: 64` y solo acepta respuestas con `choices`.

El combo queda ordenado por la tabla de arriba (Cloudflare → Gemini → Groq → …). Para que el
fallback sirva de algo, el orden debe mezclar **empresas distintas**: dos modelos del mismo
proveedor caen juntos cuando se agota su cuota.

Verificado en esta máquina: con el proveedor de Gemini desactivado
(`omniroute providers edit gemini --inactive`), `combo/free` siguió respondiendo por
Cloudflare. Eso es el fallback funcionando.

Para quitar uno: `omniroute providers remove <id> --yes`.

> **Coste oculto de Cloudflare Playground**: cada petición levanta un Chromium headless.
> Tarda 10-30 s y consume RAM. Es un buen *último recurso* del combo, no el primero, salvo
> que no tengas ninguna clave.

---

## 6. Fallback: `auto` y los combos

OmniRoute tiene dos mecanismos:

- **`auto`** — elige entre las conexiones activas aplicando reglas de cuota, coste y salud.
- **Combos** — una secuencia explícita de modelos. Si el primero falla, prueba el segundo, y
  así sucesivamente. Es el modo determinista.

`auto` expone 37 variantes; estas son las que interesa tener a mano:

| Modelo | Criterio |
|---|---|
| `auto` | Equilibrio general |
| `auto/cheap` | Menor coste |
| `auto/coding` | Código |
| `auto/fast` | Menor latencia |
| `auto/vision` | Modelos con visión |
| `auto/best-coding` | El mejor puntuado para código |

> **Aviso con `auto` en una instalación nueva.** El catálogo incluye cientos de entradas de
> proveedores sin clave configurada. Algunas responden, otras dan 503 porque necesitan
> Playwright/Chromium, y otras se quedan colgadas hasta el timeout. En la práctica `auto` y
> `auto/coding` pueden tardar mucho o fallar; `auto/cheap` fue el que respondió de forma
> consistente. **Para el día a día, usa un combo**: sabes qué orden se sigue y no dependes
> de que el enrutador descubra un destino sano.

Los combos **no aparecen en `/v1/models`** (el catálogo solo lista modelos de proveedor), así
que hay que nombrarlos. Se crean por CLI:

```bash
# Un combo llamado "dev" con tres modelos en orden de prioridad
omniroute combo create dev --strategy priority \
  --models "gemini/gemini-3-flash-preview,gemini/gemini-3.8-flash,gemini/gemini-2.5-pro"

# O con la receta del proyecto
just omniroute-combo dev "gemini/gemini-3-flash-preview,gemini/gemini-3.8-flash"

# Ver los que hay
omniroute --output json combo list | jq -r '.combos[].name'
```

Se direccionan como `combo/<nombre>` dentro del gateway, y como `omniroute/combo/<nombre>`
desde OpenCode. El script de integración detecta los combos de la CLI y los añade solo, así
que basta con volver a ejecutarlo (`just omniroute-default`) después de crear uno.

`--strategy` acepta `priority` (el orden de la lista), `weighted`, `round-robin`,
`cost-optimized`, `least-used`, `reset-aware`… Para «gratis primero y luego lo que haga
falta», `priority` es lo que quieres.

> **El fallback ocurre dentro de OmniRoute, no en OpenCode.** OpenCode envía una petición a
> `auto` o a `combo/dev` y espera; los reintentos entre proveedores son invisibles para él.
> Por eso no necesitas configurar reintentos en OpenCode.

---

## 7. OpenCode: el proveedor `omniroute`

`omniroute setup-opencode` escribe el formato de la **V1** de OpenCode (`provider`, `npm`,
`options.baseURL`). La V2 usa `providers`, `package` y `settings`, así que este proyecto
trae su propio script:

```bash
# Añade o actualiza el proveedor sin tocar el resto de la configuración
./scripts/opencode-providers.py

# Fija el modelo por defecto (auto, o el que le pases)
./scripts/opencode-providers.py --set-default combo/dev

# Importa TODO el catálogo del gateway (cientos de modelos; casi nunca lo quieres)
./scripts/opencode-providers.py --sync
```

El bloque que escribe es este:

```jsonc
{
  "providers": {
    "omniroute": {
      "name": "OmniRoute",
      "package": "@opencode/ai/providers/openai-compatible",
      "env": ["OMNIROUTE_API_KEY"],
      "settings": {
        "baseURL": "http://127.0.0.1:20128/v1",
        "apiKey": "{file:/home/andres/.secrets/omniroute-key}"
      },
      "models": {
        "auto": { "name": "Auto — fallback entre proveedores" },
        "auto/cheap": { "name": "Auto — el más barato" },
        "auto/coding": { "name": "Auto — código" },
        "auto/fast": { "name": "Auto — el más rápido" },
        "auto/vision": { "name": "Auto — con visión" },
        "auto/best-coding": { "name": "Auto — el mejor para código" },
        "combo/dev": { "name": "Combo «dev»" }
      }
    }
  }
}
```

**Por qué una lista curada y no el catálogo entero.** `/v1/models` devuelve más de 450
entradas: modelos de proveedores que no has conectado, betas cerradas y modelos de imagen.
Volcarlas todas en el selector de `/models` lo hace inútil. El script expone las rutas de
enrutamiento, tus combos y lo que ya tuvieras; `--sync` existe para cuando de verdad
quieras ver todo.

Tres detalles que importan:

- **`package`** es obligatorio en un proveedor que no está en el catálogo de models.dev.
  `openai-compatible` es el runtime correcto para un gateway OpenAI-compatible.
- **`apiKey` con `{file:…}`** evita depender de que el servicio en segundo plano herede la
  variable de entorno. `{env:OMNIROUTE_API_KEY}` también funcionaría, pero solo si la
  variable existe en el proceso que arranca el servidor de OpenCode.
- **El script no pisa nada**: lee JSONC (con comentarios y comas finales), conserva las
  claves que ya tengas y solo añade o actualiza `providers.omniroute`. Antes de escribir
  guarda un backup `opencode.jsonc.bak-<fecha>`.

---

## 8. Elegir modelo

```bash
# Un modelo para una ejecución suelta
opencode run --model omniroute/combo/dev "resume este diff"

# O dentro de la TUI
/models          # y elige omniroute/combo/dev
```

Para dejarlo por defecto:

```bash
just omniroute-default                # omniroute/auto
just omniroute-default combo/dev      # el combo
```

Eso pone `"model"` en la configuración global. Para volver a no fijar ninguno, edita el
archivo y borra la clave `model`.

Comprueba que OpenCode lo ve:

```bash
opencode models | grep omniroute
```

> **Antes de fijarlo**, comprueba que el gateway tiene al menos un destino válido. Si no,
> la siguiente sesión fallará con `Model unavailable`. `just omniroute-models` te lo dice.

### Por qué no basta con `auto`

Un modelo de enrutamiento **no declara capacidades**. OpenCode, para un modelo que no está
en su catálogo, asume: herramientas sí, texto e imagen de entrada, 200 000 tokens de
contexto. Normalmente es correcto para un gateway que enruta a modelos de código, pero si
enruta a un modelo sin visión, una imagen fallará. Si te pasa, declara el modelo concreto en
`models` con sus `capabilities` y `limit` reales, o usa un combo que solo contenga modelos
compatibles.

---

## 9. Operación

```bash
systemctl --user status omniroute      # estado
systemctl --user restart omniroute     # reiniciar
systemctl --user stop omniroute        # parar
journalctl --user -u omniroute -f      # registro en vivo
omniroute doctor                       # diagnóstico de proveedores y puertos
```

El servicio arranca con tu sesión, no con el sistema: si nadie inicia sesión, no hay
gateway. Para que siga vivo tras cerrar sesión:

```bash
loginctl enable-linger "$USER"
```

El registro también se escribe en `~/.local/state/omniroute/gateway.log`.

---

## 10. Consumo y límites

El panel muestra, por petición: modelo elegido, proveedor, tokens de entrada y salida,
latencia y coste. Sirve para responder a la pregunta que importa: *¿qué me está atendiendo
y cuánto me cuesta?*

Cuando un proveedor agota su cuota, OmniRoute lo aparta hasta que se renueve y sigue con el
siguiente. Si todos están agotados, la petición falla con el error del último intento.

Para reducir consumo:

- `auto/cheap` para tareas mecánicas (formatear, renombrar, resumir).
- Compresión de contexto en conversaciones largas (panel → Settings → Compression). Cuesta
  una llamada extra, así que no compensa en sesiones cortas.
- Desactivar el *warming* de OpenCode si lo tuvieras activo: mantiene sesiones calientes con
  peticiones periódicas.

---

## 11. Problemas frecuentes

**`auto` devuelve error 400 o 404**
→ no hay ningún destino elegible. Conecta un proveedor y compruébalo con
`just omniroute-models`. Un `auto` recién instalado, sin proveedores, no tiene a dónde ir.

**El gateway no arranca**
→ `journalctl --user -u omniroute -n 60`. Las causas habituales: puerto 20128 ocupado
(`ss -ltnp | grep 20128`), o el postinstall de npm no se ejecutó por la política de scripts
(reinstala con `--allow-scripts`, ver §2).

**OpenCode dice `Model unavailable: omniroute/auto`**
→ el proveedor no está en la configuración, o el gateway no responde. Comprueba
`./scripts/opencode-providers.py --check` y `curl -s -o /dev/null -w '%{http_code}\n'
http://127.0.0.1:20128/v1/models`.

**401 en todas las peticiones**
→ la clave de `~/.secrets/omniroute-key` no es válida o tiene un salto de línea de más. El
script escribe con `printf '%s\n'`, que es lo correcto; si la copiaste a mano, revisa que no
haya espacios.

**`auto` tarda una eternidad o devuelve 502**
→ está intentando proveedores sin credenciales que dan 503 (Playwright) o que ya no aceptan
registros. Usa un combo. Si quieres arreglar `auto`, conecta proveedores y quita los que
sabes que no funcionan.

**La contraseña del panel no entra**
→ hay dos bases de datos. `omniroute setup` escribe en `~/.config/omniroute/`, pero el
servidor usa `~/.omniroute/` (lo crea al arrancar). Ejecuta `setup` **con el servidor ya
arrancado**:

```bash
systemctl --user start omniroute
omniroute setup --password "$(cat ~/.secrets/omniroute-admin-password)" --non-interactive
```

**`npm install` se queda parado minutos**
→ está descargando el binario de `onnxruntime-node` en el `postinstall`. Son cientos de MB.
Mira el progreso con `du -sh ~/.local/share/omniroute` y no lo interrumpas: npm hace rollback
y empieza de cero.

**Una conexión de proveedor dice `error` pero otras funcionan**
→ `omniroute providers test <id>` para ver el motivo. Una clave de OpenCode Zen no sirve
para el proveedor `opencode-zen` si no es de ese servicio; quítala con
`omniroute providers remove <id> --yes`.

**Los modelos del catálogo no aparecen en `/models`**
→ es intencionado: el bloque es curado. Añade combos (`omniroute combo create …` y luego
`just omniroute-default`) o importa todo con `./scripts/opencode-providers.py --sync`.

**Se come la RAM**
→ `OMNIROUTE_MEMORY_MB=2048` está fijado en la unidad. Súbelo si usas contextos muy largos;
el proceso muere por heap si se queda corto, no por el sistema.

**Quiero quitarlo**
→ `systemctl --user disable --now omniroute && rm -rf ~/.local/share/omniroute
~/.config/systemd/user/omniroute.service ~/.local/state/omniroute` y borra
`providers.omniroute` de `opencode.jsonc`.
