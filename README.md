# linux-dev-environment

Bootstrap reproducible de un entorno de terminal y desarrollo para **Linux Mint 22.3
(base Ubuntu 24.04 "noble")**, pensado para ingeniería de software.

El objetivo es que una máquina nueva quede con una terminal cómoda —zsh con prompt
informativo, fzf, zoxide, alias útiles— y con el toolchain de desarrollo listo, sin
tocar a mano veinte archivos de configuración.

**Principios:** por capas · idempotente · no sobrescribe tu configuración · backup de
cada archivo tocado · log de cada ejecución.

---

## Índice

- [Qué instala](#qué-instala)
- [Inicio rápido](#inicio-rápido)
- [Las capas](#las-capas)
- [La terminal](#la-terminal)
- [IA: OmniRoute + OpenCode](#ia-omniroute--opencode)
- [Verificación](#verificación)
- [Cómo está construido](#cómo-está-construido)
- [Documentación](#documentación)
- [Qué NO toca](#qué-no-toca)
- [Solución de problemas](#solución-de-problemas)

---

## Qué instala

### Herramientas de terminal (en `~/.local/bin`, sin sudo)

| Herramienta | Para qué |
|---|---|
| **starship** | Prompt de la shell: rama, hash, versiones, batería, RAM, hora |
| **zoxide** | `cd` inteligente: salta al directorio que más has visitado |
| **fzf** | Búsqueda difusa: archivos, historial y directorios |
| **eza** | `ls` moderno con iconos y árbol de git |
| **bat** | `cat` con resaltado de sintaxis y números de línea |
| **ripgrep** | `grep` rápido, respeta `.gitignore` |
| **fd** | `find` moderno |
| **delta** | Diffs de git coloreados y navegables |
| **lazygit** | Interfaz TUI para git |
| **just** | Runner de tareas (Makefile en Rust) |
| **yq** | Manipulador de YAML |
| **bun**, **ruff** | Runtime de JS y linter de Python |

### Plugins de zsh (en `~/.local/share/zsh-plugins`)

| Plugin | Para qué |
|---|---|
| **zsh-autosuggestions** | Completa el comando en gris mientras escribes |
| **zsh-syntax-highlighting** | Colorea el comando mientras lo escribes |
| **zsh-completions** | Cientos de completados extra (`k`, `kill`, `ssh`…) |
| **fzf-tab** | El menú de completado se dibuja con fzf |

### Fuentes

**JetBrainsMono Nerd Font** y **Meslo Nerd Font** en `~/.local/share/fonts`. Las Nerd
Fonts traen los iconos que usa el prompt; sin ellas verás cuadritos en vez de iconos.

---

## Inicio rápido

```bash
git clone https://github.com/Andres-Developer-23/linux-dev-environment.git ~/dev-setup
cd ~/dev-setup

# Recomendado: sistema + usuario + dotfiles + Java (pide sudo una vez)
./install.sh --apt --user --config --java

# Añade Docker y VS Code
./install.sh --docker --vscode

# Añade MySQL, Redis, MongoDB y DB Browser
./install.sh --db

# Ver qué haría, sin tocar nada
./install.sh --dry-run --all

# Comprobar el estado
./verify.sh
```

Para zsh como shell de login:

```bash
./install.sh --apt --chsh
# cierra sesión y vuelve a entrar
```

También con `just`:

```bash
just install   # sistema + usuario + dotfiles + Java
just user      # sin sudo
just verify    # comprueba el entorno
just full      # todo, incluidas capas pesadas
```

---

## Las capas

Cada capa es independiente y se puede ejecutar por separado. Las que necesitan root
piden `sudo` **una sola vez**: el script mantiene la credencial viva con un proceso en
segundo plano mientras dura la ejecución.

| Flag | Qué instala | ¿sudo? |
|---|---|---|
| `--apt` | `build-essential`, CMake, Ninja, Clang, GDB, headers de Python/OpenSSL, **zsh**, zsh-syntax-highlighting, zsh-autosuggestions, tmux, vim, eza, zoxide, jq, tree, htop, btop, ncdu, nmap, tcpdump, httpie, shellcheck, direnv, git-lfs, gh, git-delta, just, clientes de MySQL/Postgres/Redis/SQLite, fuentes Fira Code | Sí |
| `--user` | Todo lo de `~/.local/bin`, las Nerd Fonts y los plugins de zsh | No |
| `--config` | `~/.zshenv`, `~/.zprofile`, `~/.zshrc`, `~/.bashrc`, git, tmux, dircolors, starship y la fuente de la terminal | No |
| `--java` | OpenJDK 21 + Maven | Sí |
| `--docker` | Docker Engine, CLI, containerd, buildx y compose; te añade al grupo `docker` | Sí |
| `--vscode` | Visual Studio Code desde el repo oficial de Microsoft | Sí |
| `--db` | MySQL Server, Redis, MongoDB 8 y DB Browser for SQLite | Sí |
| `--nvim` | LazyVim sobre Neovim (solo si `~/.config/nvim` no existe) | No |
| `--omniroute` | OmniRoute: gateway local de LLMs en `:20128`, servicio de usuario y proveedor `omniroute` en OpenCode | No |
| `--all` | Todas las anteriores (no cambia tu shell) | Sí |
| `--chsh` | Cambia tu shell de login a zsh | Sí |

Añadir `--dry-run` a cualquier combinación muestra exactamente qué comandos se ejecutarían
sin tocar nada.

---

## La terminal

### Prompt

Tema *Tokyo Night*, compacto e informativo. En un repositorio git con Python y Node:

```
…/api │  main │  9233af2 │ ! │  v3.12.3 │  v24.22.0 │  14:30 ❯
```

En tu carpeta personal:

```
~ │  v3.12.3 │ opencode │  14:30 ❯
```

Los segmentos van separados por una línea vertical tenue, y cada uno lleva su icono de
Nerd Font.

- **directorio** — truncado a 3 niveles, con `…/` cuando recorta
- **rama de git** + **hash corto** + **estado** (`!` modificado, `?` sin seguimiento, `≡` stashed)
- **versiones de lenguaje** — solo si el proyecto las usa (Python, Node, Go, Rust, Java, Kotlin, Ruby, PHP, .NET, Swift, Elixir, Bun)
- **contexto de Docker, AWS y GCP** — solo si están activos
- **opencode** — marca cuando estás dentro de una sesión de opencode
- **duración** — solo si el comando tardó más de 2 s
- **código de salida** — con una ✗ roja cuando el comando falla
- **batería** — por debajo del 30 %
- **RAM** — por encima del 75 %
- **hora**

El hostname solo aparece por SSH y el sistema operativo no se muestra: en local serían
ruido constante.

El prompt cambia de color según el resultado: `❯` verde si el último comando fue
correcto, rojo si falló.

### Atajos de teclado

| Atajo | Acción |
|---|---|
| `Ctrl+T` | buscar archivos con fzf |
| `Ctrl+R` | buscar en el historial con fzf |
| `Alt+C` | saltar a un directorio visitado |
| `Tab` | completado con menú fzf |
| `↑` / `↓` | buscar en el historial por lo que ya escribiste |
| `Ctrl+←` / `Ctrl+→` | moverse por palabras |
| `Ctrl+Backspace` | borrar la palabra anterior |
| `Ctrl+X Ctrl+E` | editar la línea actual en el editor |
| `Alt+.` | insertar el último argumento del comando anterior |
| `Mayús+Tab` | completado clásico, sin fzf |

### Manual de comandos

La referencia completa de las herramientas instaladas —rg, fd, eza, bat, zoxide, fzf,
delta, lazygit, gh, just, yq, uv, ruff, bun— está en
**[docs/comandos.md](docs/comandos.md)**, con una chuleta rápida de las treinta órdenes
más usadas al principio.

### Aliases

```bash
# Listar
ls  ll  la  lt  lta          # eza con iconos, árbol y estado de git

# Ver
cat  catp  catn              # bat con estilo plain, paginado o numerado

# Buscar
grep  rgi  rgh               # ripgrep (normal, sin mayúsculas, con ocultos)
find  fdf  fdd               # fd (todo, solo ficheros, solo directorios)

# Git
g  gs  gst  gd  gds  ga  gaa  gc  gco  gsw  gb  gl  glp  gll  gp  gf  gr  grb
gsta  gstp  lg               # + lazygit

# Navegar
..  ...  ....                # subir directorios

# Utilidades
reload  zshcfg  starcfg  ports  myip  sysinfo
```

### `cd` inteligente

zoxide aprende de por dónde te mueves:

```bash
cd api            # salta al directorio "api" que más has visitado
cd ..             # sube un nivel (ruta real: funciona normal)
cd -              # directorio anterior
```

La función `cd` comprueba si el argumento es una ruta real; si lo es, hace un `cd`
normal, y si no, delega en zoxide. Así nunca pierdes el comportamiento estándar.

---

## IA: OmniRoute + OpenCode

[OmniRoute](docs/omniroute.md) es un gateway local (MIT) que expone **una sola API
compatible con OpenAI** en `127.0.0.1:20128` y enruta cada petición hacia los proveedores
que conectes, con fallback automático cuando uno falla o agota su cuota.

```bash
./install.sh --omniroute                    # ~3 GB, servicio systemd --user
xdg-open http://127.0.0.1:20128/dashboard    # conecta proveedores y crea la clave
just omniroute-default                      # importa el catálogo y usa omniroute/auto
opencode run --model omniroute/auto "…"
```

OpenCode V2 lo ve como un proveedor más (`providers.omniroute`) con las rutas de
enrutamiento `auto`, `auto/cheap`, `auto/coding`, `auto/fast`, `auto/vision` y
`auto/best-coding`, más tus combos (`combo/<nombre>`).

```bash
# Un combo es la forma fiable de tener fallback: orden explícito, sin sorpresas
omniroute combo create dev --strategy priority \
  --models "gemini/gemini-3-flash-preview,gemini/gemini-3.8-flash"
just omniroute-default combo/dev

opencode run --model omniroute/combo/dev "resume este diff"
```

El gateway se instala **cerrado a loopback y con clave obligatoria**. Por defecto OmniRoute
escucha en `0.0.0.0` y sin autenticación: la unidad de systemd lo corrige con
`OMNIROUTE_SERVER_HOST=127.0.0.1` y `REQUIRE_API_KEY=true`.

| Receta | Para qué |
|---|---|
| `just omniroute` | Instala la capa |
| `just omniroute-models` | Lista los modelos que el gateway puede atender |
| `just omniroute-combo nombre modelos` | Crea un combo de enrutamiento |
| `just omniroute-default [modelo]` | Fija el modelo por defecto (por defecto `auto`) |
| `just omniroute-status` | Estado del servicio |
| `just omniroute-logs` | Registro en vivo |
| `just omniroute-ui` | Abre el panel en el navegador |

OmniRoute **organiza** el acceso, no regala cuotas: cada proveedor impone sus límites y sus
términos. El paso de conectar proveedores es interactivo y se hace una vez en el panel.

---

## Verificación

```bash
./verify.sh
```

Comprueba binarios clave, las Nerd Fonts, los plugins de zsh, la sintaxis de
`~/.zshrc`, la validez de `starship.toml`, los marcadores en los dotfiles, el grupo
`docker` y tu shell de login. Termina con un resumen de `OK` / `fallos`.

---

## Cómo está construido

```
dev-setup/
├── install.sh              # bootstrap por capas (1329 líneas)
├── verify.sh               # verificación sin sudo
├── justfile                # atajos: just install / just verify
├── LICENSE
├── .gitignore
├── README.md
└── docs/
    ├── comandos.md           # manual de comandos de todas las herramientas
    ├── architecture.md       # cómo funciona install.sh por dentro
    ├── shell-zsh.md          # la configuración de zsh en detalle
    ├── prompt-starship.md    # el prompt módulo a módulo
    ├── troubleshooting.md    # problemas frecuentes
    └── android-flutter.md    # SDK de Android y Flutter
```

`backups/` y `logs/` se crean al ejecutar y están fuera del control de versiones.

Detalle completo en [docs/architecture.md](docs/architecture.md).

---

## Documentación

| Documento | Contenido |
|---|---|
| [comandos.md](docs/comandos.md) | **Manual de comandos**: chuleta rápida y referencia de cada herramienta |
| [architecture.md](docs/architecture.md) | Capas, idempotencia, bloques gestionados, backups, cómo añadir una capa |
| [shell-zsh.md](docs/shell-zsh.md) | `.zshenv` / `.zprofile` / `.zshrc`, historial, completado, plugins, fzf, alias |
| [prompt-starship.md](docs/prompt-starship.md) | Cada módulo del prompt, cómo cambiar colores, iconos y qué mostrar |
| [omniroute.md](docs/omniroute.md) | Gateway local de LLMs: instalación, clave, proveedores, fallback e integración con OpenCode V2 |
| [troubleshooting.md](docs/troubleshooting.md) | Cuadritos en el prompt, `starship: command not found`, sudo, shell por defecto… |
| [android-flutter.md](docs/android-flutter.md) | SDK de Android, Flutter y Gradle |

---

## Qué NO toca

- Tu identidad de git (`user.name`, `user.email`) ni tu editor (`zed --wait`).
- `~/.tmux.conf`, `~/.config/starship.toml` y `~/.dircolors` **si ya existen y no
  contienen el bloque `dev-setup`**: en ese caso avisa y los deja como están.
- `~/.config/nvim` si ya existe.
- Paquetes ya instalados (apt solo recibe los que faltan).
- El contenido de tus shells: todo lo que escribe el script va dentro de un bloque
  marcado.

```bash
# >>> dev-setup >>>
...
# <<< dev-setup <<<
```

Puedes borrar el bloque a mano o restaurar el backup de `~/dev-setup/backups/`.

### Tus propias extensiones

El script carga, si existe, `~/.config/dev-setup/local.sh` desde el bloque gestionado
de zsh y de bash. **Ese archivo no lo gestiona `dev-setup`**: es tuyo, sobrevive a las
ejecuciones y es el sitio donde poner todo lo que quieras añadir.

```bash
mkdir -p ~/.config/dev-setup
cat > ~/.config/dev-setup/local.sh <<'EOF'
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

alias deploy='kubectl --context=produccion'
EOF
```

---

## Solución de problemas

Problemas frecuentes resueltos en [docs/troubleshooting.md](docs/troubleshooting.md).
Los más comunes:

| Síntoma | Causa | Solución |
|---|---|---|
| Cuadritos en vez de iconos | falta la Nerd Font | `Preferencias → Perfil → Fuente → Meslo Nerd Font` |
| `starship: command not found` | `~/.local/bin` no está en el PATH | abre una terminal nueva |
| `zsh` no es tu shell | falta `--chsh` | `./install.sh --apt --chsh` y cierra sesión |
| `sudo` pide la contraseña | es lo esperado | el script la pide una vez y la mantiene viva |

---

## Licencia

MIT — ver [LICENSE](LICENSE).
