# Arquitectura de `install.sh`

Cómo está construido el bootstrap, por qué está hecho así, y cómo extenderlo.

---

## 1. Idea general

El script instala un entorno de desarrollo **por capas**. Cada capa es un conjunto
independiente de herramientas o de configuraciones, se activa con un flag y se puede
ejecutar sola, repetidas veces, sin efectos acumulativos.

```
./install.sh --apt --user --config --java
              ───┬── ───┬── ───┬── ───┬──
                 │     │     │     └── Java: OpenJDK 21 + Maven
                 │     │     └──────── Configuración: dotfiles, git, tmux, starship
                 │     └────────────── Usuario: binarios en ~/.local, fuentes, plugins
                 └──────────────────── Sistema: toolchain y CLI vía apt
```

El orden importa solo en un caso: `--chsh` necesita que zsh ya esté instalado, así que
debe ir después de `--apt`. Por lo demás las capas son independientes.

---

## 2. Anatomía del script

### 2.1 Cabecera y constantes

```bash
set -Eeuo pipefail          # error inmediato, variables sin fallo, pipelines activos
export LC_ALL=C             # salida estable para comparar

SETUP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SETUP_DIR/logs"
BACKUP_DIR="$SETUP_DIR/backups"

MARK_BEGIN="# >>> dev-setup >>>"   # marcadores de bloque gestionado
MARK_END="# <<< dev-setup <<<"
```

`set -o pipefail` es importante: hace que un fallo dentro de un pipeline no se esconda.
Tiene un coste que ya se pagó una vez (ver [§6](#6-trampas-con-gnu-bash)).

### 2.2 Flags

El parseo es un `case` straightforward que rellena variables `L_APT`, `L_USER`, …

```bash
--apt) L_APT=1 ;;
--all) L_APT=1 L_USER=1 L_CONFIG=1 … ;;   # --all es la suma de todas
--chsh) CHSH=1 ;;                          # acción aparte, no una capa
--dry-run) DRY=1 ;;
```

`--chsh` es independiente porque no instala nada: solo cambia el shell de login. Por eso
`--all` **no** lo incluye — cambiar el shell de sesión a sesión es una decisión del
usuario, no un efecto colateral de instalar herramientas.

### 2.3 Utilidades

| Función | Para qué |
|---|---|
| `ok` / `warn` / `step` / `die` | salida con color y símbolos; `die` aborta |
| `have` | `command -v` con salida limpia |
| `run` | ejecuta un comando, o lo imprime con `[dry-run]` si `DRY=1` |
| `run_shell` | lo mismo pero para una cadena de shell ya citada |
| `backup_file` | copia el archivo a `backups/` con timestamp antes de tocarlo |
| `apt_update` / `apt_install` | `apt-get update` una sola vez; instala solo lo que falta |
| `gh_release_info` | consulta la API de GitHub y devuelve `tag url` del asset que case |
| `download` | `curl -fL` con reintentos y barra de progreso |
| `install_tar_bin` | descarga un release de GitHub, extrae el binario y lo instala |
| `ensure_uv` | instala uv si no está |
| `init_sudo` | pide `sudo -v` una vez y mantiene la credencial viva |

### 2.4 `init_sudo`: la contraseña se pide una sola vez

```bash
init_sudo() {
  sudo -v || die "autenticación sudo cancelada"
  ( while true; do
      sudo -n true 2>/dev/null      # refresca la credencial sin pedirla
      sleep 50
      kill -0 "$$" 2>/dev/null || exit
    done ) &
  SUDO_KEEP_PID=$!
  trap '… kill "$SUDO_KEEP_PID" …' EXIT
}
```

El proceso en segundo plano refresca el timestamp de sudo cada 50 segundos, para que
`apt install` + `docker` + `chsh` en una sola ejecución no pidan la contraseña tres
veces. El `trap` lo mata al salir, incluso si el script falla.

---

## 3. Idempotencia

El principio central: **ejecutar el script dos veces no cambia nada la segunda vez**.

| Capa | Cómo lo consigue |
|---|---|
| `--apt` | `apt_install` consulta `dpkg-query` y solo pasa a `apt-get` los paquetes que faltan |
| `--user` | cada herramienta se comprueba con `have` antes de instalar; los plugins de zsh se actualizan con `git pull --ff-only` si no tienen cambios locales |
| `--config` | `upsert_block` borra el bloque anterior antes de escribir el nuevo, así que el resultado es el mismo |
| `--docker` | solo configura el repo oficial si `docker` no está instalado |
| `--nvim` | no toca `~/.config/nvim` si ya existe |

### 3.1 `upsert_block`: el corazón de la idempotencia

```bash
upsert_block() {
  local file=$1 block=$2
  touch "$file"
  if grep -qF "$MARK_BEGIN" "$file"; then
    sed -i "\|^${MARK_BEGIN}$|,\|^${MARK_END}$|d" "$file"
  fi
  printf '\n%s\n' "$block" >>"$file"
  sed -i '/./,$!d' "$file"      # quita líneas en blanco acumuladas
}
```

Borra el bloque completo que va de `# >>> dev-setup >>>` a `# <<< dev-setup <<<` y
escribe el nuevo al final. El resto del archivo —lo que el usuario escribió— se
conserva intacto.

El `sed -i '/./,$!d'` del final es un truco: elimina las líneas vacías que quedan al
principio cuando el archivo estaba vacío antes del bloque.

### 3.2 Regla de seguridad: no adopts archivos ajenos

`~/.tmux.conf`, `~/.config/starship.toml` y `~/.dircolors` se gestionan **solo** si
contienen los marcadores. Si existen y no son del script, avisa y no los toca:

```bash
if [[ -f "$file" ]] && ! grep -qF "$MARK_BEGIN" "$file"; then
  warn "~/.config/starship.toml ya existe y no lo gestiona dev-setup; no lo sobrescribo"
  return
fi
```

El caso intermedio —el archivo existe **y** tiene los marcadores— significa que lo
gestiona el script, y entonces sí se actualiza. Así los archivos de texto (`.zshrc`,
`.bashrc`, `.gitconfig`) se gestionan siempre, y los de configuración completa
(`.tmux.conf`, `starship.toml`, `.dircolors`) se adoptan solo si el script los escribió.

---

## 4. Las capas en detalle

### 4.1 `layer_user` — sin sudo

Instala en `~/.local/bin` lo que no está en los repos de Ubuntu:

- **Binarios de release de GitHub** vía `install_tar_bin`: zoxide, lazygit, just, delta.
  La función descarga el tarball, busca el binario por nombre y lo instala con `install -m 0755`.
- **Instaladores oficiales**: starship (`starship.rs/install.sh`), bun (`bun.sh/install`),
  uv (`astral.sh/uv/install.sh`).
- **Neovim estable** en `~/.local/opt/nvim`, con un symlink en `~/.local/bin/nvim` para
  que gane al `/usr/bin/nvim` del sistema.
- **Fuentes Nerd Font** en `~/.local/share/fonts` + `fc-cache`.
- **Plugins de zsh** en `~/.local/share/zsh-plugins` (ver más abajo).

```bash
install_zsh_plugins() {
  for repo in "${ZSH_PLUGINS[@]}"; do
    name="${repo##*/}"
    dir="$ZSH_PLUGIN_DIR/$name"
    if [[ -d "$dir/.git" ]]; then
      if [[ -n "$(git -C "$dir" status --porcelain)" ]]; then
        warn "$name: tiene cambios locales; no actualizo"   # no pisa tu trabajo
        continue
      fi
      git -C "$dir" pull --ff-only --quiet
    else
      git clone --depth 1 --quiet "https://github.com/$repo.git" "$dir"
    fi
  done
}
```

`zsh-completions` no está en los repos de Ubuntu 24.04, por eso va por git; el resto
también se clona para tener siempre la última versión.

### 4.2 `layer_apt` — con sudo

Dos listas: `base` (toolchain: compiladores, bibliotecas de desarrollo) y `cli`
(herramientas de terminal y clientes de base de datos). `apt_install` solo recibe los
paquetes que no están ya instalados:

```bash
apt_install() {
  local p missing=()
  for p in "$@"; do
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed' \
      || missing+=("$p")
  done
  ((${#missing[@]} == 0)) && { ok "apt: ya estaba todo instalado"; return 0; }
  apt_update
  run sudo apt-get install -y --no-install-recommends "${missing[@]}"
}
```

`--no-install-recommends` evita instalar paquetes sugeridos que multiplican el tamaño.

### 4.3 `layer_config` — sin sudo

Escribe (o reescribe) los archivos de configuración. Cada uno tiene su función:

| Función | Archivo | Contenido |
|---|---|---|
| `config_bash` | `~/.bashrc` | bloque mínimo: PATH, eza, bat, starship, zoxide |
| `config_zsh` | `~/.zshenv`, `~/.zprofile`, `~/.zshrc` | la configuración completa de zsh |
| `config_git` | `~/.gitconfig` | delta como pager, `zdiff3`, `colorMoved`, aliases |
| `config_dircolors` | `~/.dircolors` | paleta de colores para ls, eza, tree y el completado |
| `config_tmux` | `~/.tmux.conf` | mouse, scrollback, prefijo `Ctrl+a`, split con `|` y `-` |
| `config_starship` | `~/.config/starship.toml` | el prompt, tema Tokyo Night |
| `config_terminal_font` | gsettings | fija la Nerd Font en gnome-terminal |

`config_git` nunca toca `user.name` ni `user.email`: usa `git config --global --get` para
comprobar si algo ya existe antes de escribirlo.

### 4.4 `layer_docker`

Configura el repo oficial de Docker, instala los paquetes, y te añade al grupo `docker`.
Avisa de que hace falta cerrar sesión para que el grupo aplique.

```bash
if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
  run sudo usermod -aG docker "$USER"
  warn "Cierra sesión y vuelve a entrar para usar Docker sin sudo"
fi
```

### 4.5 `layer_nvim`

Clona LazyVim solo si `~/.config/nvim` no existe, y borra el `.git` del resultado para
que no quede un repo anidado.

### 4.6 `layer_omniroute`

Instala OmniRoute (gateway local de LLMs) y lo conecta a OpenCode. Tres decisiones que no
son obvias:

- **Prefijo propio de npm** (`~/.local/share/omniroute`) en vez del global. El global vive
  dentro de fnm (`node-versions/v24.22.0/installation`), así que desaparecería al cambiar
  de versión de Node.
- **`--allow-scripts`** con la lista publicada por OmniRoute. npm 11 bloquea los scripts de
  ciclo de vida por defecto, y sin ellos el paquete queda sin sus binarios nativos.
- **El proveedor de OpenCode lo escribe `scripts/opencode-providers.py`**, no
  `omniroute setup-opencode`. Ese comando genera el formato de la V1 (`provider`, `npm`,
  `options`); la V2 usa `providers`, `package` y `settings`. El script lee JSONC, conserva
  lo que ya hubiera y guarda backup antes de escribir.

La API key no viaja en la configuración: se guarda en `~/.secrets/omniroute-key` (600) y
OpenCode la lee con la sustitución `{file:…}`.

---

## 5. Logging y backups

Al arrancar, el script se redirige a un log con timestamp:

```bash
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1
```

Así ves la salida en pantalla **y** queda guardada. `tee` con `exec` es la forma
estándar de tener ambos sin duplicar código.

`backup_file` copia cada archivo antes de modificarlo:

```bash
backup_file() {
  [[ -f "$1" ]] || return 0
  local dst="$BACKUP_DIR/$(basename "$1").$(date +%Y%m%d-%H%M%S).bak"
  cp -a "$1" "$dst"
  printf '  backup: %s\n' "$dst"
}
```

Restaurar es copiar el `.bak` de vuelta sobre su destino.

---

## 6. Trampas con GNU Bash

Errores reales encontrados al construir el script:

### 6.1 `grep -q` + `pipefail` = pipeline fallido

```bash
# MAL
if fc-list | grep -qi "$label"; then …

# BIEN
if fc-list | grep -i "$label" >/dev/null; then …
```

`grep -q` sale en cuanto encuentra la coincidencia, lo que provoca `SIGPIPE` en `fc-list`.
Con `set -o pipefail`, el pipeline devuelve el fallo de `fc-list` y el `if` toma la rama
equivocada. El síntoma era que la fuente Nerd Font se reinstalaba en cada ejecución
(descargando 127 MB cada vez).

**Regla:** en este script, `grep -q` solo dentro de un `if`, nunca en un pipeline con
`pipefail` activo. Usa `grep … >/dev/null`.

### 6.2 `printf` con `%` y `\` en los datos

Los `printf` con formato interpretan `%` y `\`. Para datos dinámicos usa `%q` o
`printf '%s'`:

```bash
printf '  %s[dry-run]%s %q\n' "$C_DIM" "$C_OFF" "$@"
```

### 6.3 `set -e` y funciones que devuelven error "a propósito"

`apt_install` usa `dpkg-query … || missing+=(…)` dentro de un `if`, y `grep -q` dentro de
condicionales. Con `set -e`, un comando que falla dentro de un `if` **no** aborta el
script: solo aborta si es el último comando de la función y la función falla. Por eso
las funciones terminan con un `ok`/`return 0` explícito.

---

## 7. Cómo añadir una capa nueva

1. **Añade el flag** en el parseo:

   ```bash
   --foo) L_FOO=1 ;;
   ```

2. **Declárala** junto a las demás: `L_FOO=0` en la lista de flags.

3. **Escribe la función** `layer_foo()` con `step` al principio y `ok`/`warn` al final.

4. **Llámala** en la sección `Main`, en el orden que tenga sentido.

5. **Añádela a `--all`** si quieres que se instale en bloque.

6. **Actualiza** `usage()`, el `README.md` y `verify.sh`.

Plantilla mínima:

```bash
layer_foo() {
  step "Capa foo: lo que sea"
  if ((DRY)); then
    printf '  %s[dry-run]%s lo que haría\n' "$C_DIM" "$C_OFF"
    return 0
  fi
  if have foo; then
    ok "foo ya instalado"
  else
    run install_foo
  fi
  ok "capa foo lista"
}
```

---

## 8. `verify.sh`

Verificación separada y sin sudo, para poder ejecutarla en cualquier momento:

```bash
./verify.sh
```

Se apoya en las mismas ideas: `ok` / `bad` / `warn`, un contador y un resumen final.
Comprueba binarios, fuentes, plugins de zsh, sintaxis, marcadores en los dotfiles y el
estado del sistema.

Las dos comprobaciones que más valor dan, porque detectan la mayoría de los errores
reales:

```bash
# La sintaxis de zsh, sin ejecutar nada
zsh -n "$HOME/.zshrc"

# El TOML de starship, que valida claves y formatos
starship print-config >/dev/null
```

`starship print-config` es especialmente útil: valida cada clave de cada módulo y avisa
de las que no existen (por ejemplo, un módulo mal escrito o una clave que cambió de
nombre entre versiones).
