# Manual de comandos

Referencia de las herramientas que instala `dev-setup`: qué hace cada una, los comandos
que más se usan y los flags que merece la pena conocer.

Todos los ejemplos están verificados contra las versiones instaladas.

---

## Índice

- [Chuleta rápida](#chuleta-rápida)
- [Navegar por directorios — zoxide](#navegar-por-directorios--zoxide)
- [Buscar en el contenido — rg](#buscar-en-el-contenido--rg)
- [Buscar archivos — fd](#buscar-archivos--fd)
- [Listar — eza](#listar--eza)
- [Ver archivos — bat](#ver-archivos--bat)
- [Buscar interactivamente — fzf](#buscar-interactivamente--fzf)
- [Git](#git)
- [GitHub — gh](#github--gh)
- [El prompt — starship](#el-prompt--starship)
- [Tareas — just](#tareas--just)
- [Datos — yq, jq](#datos--yq-jq)
- [Python — uv, ruff](#python--uv-ruff)
- [JavaScript — bun, fnm](#javascript--bun-fnm)
- [dev-setup en sí](#dev-setup-en-sí)
- [Referencia de flags](#referencia-de-flags)

---

## Chuleta rápida

Las treinta órdenes que más se usan en el día a día.

| Orden | Qué hace |
|---|---|
| `ll` | lista detallada con iconos y estado de git |
| `lt` | árbol de directorios |
| `la` | incluye los archivos ocultos |
| `cat` | ver un archivo con colores (sin paginar) |
| `catn` | ver un archivo con números de línea |
| `grep` | busca en el contenido (ripgrep) |
| `find` | busca archivos por nombre (fd) |
| `cd api` | salta al directorio `api` más visitado |
| `Ctrl+T` | busca archivos con fzf |
| `Ctrl+R` | busca en el historial con fzf |
| `Alt+C` | salta a un directorio visitado |
| `↑` | busca en el historial por lo que ya escribiste |
| `gs` | `git status` resumido |
| `gl` | log de git en una línea por commit, con grafo |
| `glp` | log con autor y fecha relativa |
| `gd` | diff con delta, coloreado y navegable |
| `lg` | lazygit: interfaz TUI para git |
| `gco` | checkout |
| `gc` | commit con el editor |
| `gll` | pull con rebase |
| `gp` | push |
| `gsta` / `gstp` | stash / restaurar del stash |
| `reload` | recarga el `.zshrc` |
| `zshcfg` | abre el `.zshrc` en nvim |
| `starcfg` | abre la config de starship en nvim |
| `ports` | puertos en escucha con su proceso |
| `myip` | tu IP pública |

---

## Navegar por directorios — zoxide

zoxide memoriza dónde estás y puntúa cada directorio por frecuencia. `cd` con un
argumento que no es una ruta real salta al mejor candidato.

```bash
z              # lista los directorios más visitados y su puntuación
z api          # salta al directorio que más case con "api"
z -            # directorio anterior
z ~/           # busca bajo el directorio personal
z foo bar     # busca "foo" y "bar" a la vez
```

Comandos de zoxide:

| Comando | Qué hace |
|---|---|
| `zoxide add` | añade un directorio a la base de datos o sube su puntuación |
| `zoxide query` | busca sin cambiar de directorio (útil en scripts) |
| `zoxide remove` | borra un directorio de la base de datos |
| `zoxide edit` | abre la base de datos en el editor |
| `zoxide import` | importa el historial de otra shell |

```bash
zoxide remove ~/proyecto-que-ya-no-existe
zoxide query api
```

### El `cd` inteligente

La función `cd` decide qué hacer:

| Entrada | Resultado |
|---|---|
| `cd` | a casa |
| `cd ..`, `cd /usr`, `cd ~/algo` | `cd` normal, porque la ruta existe |
| `cd api` | salto inteligente de zoxide |

Si prefieres el `cd` normal, quita la función:

```bash
unfunction cd
```

---

## Buscar en el contenido — rg

ripgrep es un `grep` que respeta `.gitignore`, no busca en binarios y es paralizable.

```bash
rg "patrón"                    # busca en todos los archivos
rg -i "patrón"                 # sin distinguir mayúsculas
rg -n "patrón"                 # con número de línea
rg -l "patrón"                 # solo los nombres de los archivos
rg -c "patrón"                 # solo el número de coincidencias por archivo
rg -w "patrón"                 # busca la palabra completa
rg -v "patrón"                 # lo inverso: líneas que NO coinciden
rg -m 3 "patrón"               # máximo 3 coincidencias por archivo
rg -t rust "patrón"            # solo en un tipo de archivo
rg -g "*.toml" "patrón"        # solo en un patrón de nombre
rg -A 3 -B 3 "patrón"          # 3 líneas de contexto antes y después
rg --stats "patrón"            # estadísticas al final
```

### Tipos de archivo más útiles

```bash
rg -t py -t js "patrón"        # Python y JavaScript
rg -t rust -t go "patrón"      # Rust y Go
rg -t json -t yaml "patrón"    # datos
rg -t md "patrón"              # Markdown
```

### Ignorar lo que no te interesa

```bash
rg -g '!node_modules' "patrón"          # excluye una carpeta
rg -g '!*.min.js' "patrón"               # excluye un patrón
rg --no-ignore "patrón"                 # busca también en lo ignorado
rg --hidden "patrón"                    # incluye archivos ocultos
```

### Búsqueda interactiva

```bash
rg --json "patrón" | head          # salida en JSON
```

---

## Buscar archivos — fd

`fd` busca por nombre, ignorando los `.gitignore` y los ocultos.

```bash
fd "patrón"                 # archivos y carpetas que contengan "patrón"
fd -e py                    # solo extensión .py
fd -t d "config"            # solo directorios
fd -t f "test"              # solo ficheros
fd -H "patrón"              # incluye ocultos
fd -I "patrón"              # incluye lo ignorado por git
fd -i "patrón"              # sin distinguir mayúsculas
fd -g "*.toml"              # por patrón de nombre
fd -e rs -e toml            # varias extensiones
fd --changed-within 1d      # modificados en el último día
fd --changed-within 2weeks  # en las dos últimas semanas
fd -E node_modules "x"      # excluye un directorio
fd -x rm {}                 # ejecuta una orden con cada resultado
fd -X ls {}                 # … o con todos juntos
```

```bash
fd -e log -X wc -l          # cuenta las líneas de todos los .log
fd -e py -X ruff check      # pasa ruff a todos los .py
```

---

## Listar — eza

```bash
eza                          # como ls, con iconos
eza -l                       # formato largo
eza -la                      # largo + ocultos
eza --tree --level=2         # árbol
eza --git                    # con el estado de git de cada archivo
eza --git-repos              # con la rama de cada repositorio
eza --icons=always           # iconos siempre, no solo en terminal
eza --sort=size              # por tamaño
eza --sort=modified          # por fecha de modificación
eza --reverse                # orden inverso
eza --only-dirs              # solo directorios
eza --only-files              # solo ficheros
eza --color=always           # color forzando a un pipe
eza --hyperlink=always       # rutas como enlaces clicables
eza --code                   # resumen de líneas de código por lenguaje
```

### `--code`: resumen del proyecto

```console
$ eza --code
 Language  Files  Lines   Code  Comments  Blanks  Code %
 Markdown      6  2.118  1.566         0     552   56.0%  ████████████████
 Shell         2  1.493  1.231       118     144   44.0%  ████████████▋
──────────────────────────────────────────────────────────────────────────
 Total         8  3.611  2.797       118     696  100.0%
```

### Los alias

```bash
ll   # eza -lah --icons --group-directories-first --git
lt   # eza --tree --level=2 --icons
lta  # eza --tree --level=3 --all --icons
la   # eza -a --icons
```

---

## Ver archivos — bat

`bat` muestra archivos con resaltado de sintaxis, números de línea y un borde de
cabecera con el nombre.

```bash
bat archivo.py            # con colores y paginado
bat --paging=never        # sin paginar (para pipes)
bat -n archivo.py         # con números de línea
bat -H 20:30 archivo.py   # resalta las líneas 20 a 30
bat -l python archivo     # fuerza el lenguaje
bat -d archivo.py         # solo las líneas cambiadas respecto a git
bat --diff-context=5      # con 5 líneas de contexto
bat -r 1:50 archivo       # solo un rango de líneas
```

Los alias ya usan `--paging=never` para que `cat` no rompa los pipes:

| Alias | Equivale a |
|---|---|
| `cat` | `bat --paging=never --style=plain` |
| `catp` | `bat --paging=never` |
| `catn` | `bat --paging=never --style=numbers` |

`cat` usa el estilo `plain` a propósito: si no, el resaltado mete secuencias de escape
en la salida de un pipe.

---

## Buscar interactivamente — fzf

### Los tres widgets

| Atajo | Qué abre |
|---|---|
| `Ctrl+T` | buscar archivos, con vista previa |
| `Ctrl+R` | buscar en el historial, con vista previa del comando |
| `Alt+C` | saltar a un directorio visitado (usa zoxide) |

### Atajos dentro de fzf

| Atajo | Acción |
|---|---|
| `Ctrl+F` / `Ctrl+B` | bajar / subir en la lista |
| `Ctrl+A` | seleccionar todo |
| `Ctrl+R` | recargar los resultados |
| `Ctrl+W` | borrar la palabra |
| `Tab` | multi-selección |
| `Enter` | aceptar |
| `Esc` / `Ctrl+C` | cancelar |
| `Alt+Enter` | aceptar en varias líneas (selección múltiple) |

### Opciones de fzf

```bash
export FZF_DEFAULT_OPTS="--height=45% --layout=reverse --border=rounded
  --info=inline --marker='❯' --prompt='🔎 ' --color=fg:#c0caf5,bg:#1a1b26,…"
```

| Variable | Afecta a |
|---|---|
| `FZF_DEFAULT_OPTS` | todas las instancias |
| `FZF_CTRL_T_OPTS` | `Ctrl+T` (archivos) |
| `FZF_CTRL_R_OPTS` | `Ctrl+R` (historial) |
| `FZF_ALT_C_OPTS` | `Alt+C` (directorios) |

### fzf desde un pipe

```bash
fd -e py | fzf --preview 'bat --color=always {}'
cat file.txt | fzf --multi --header='elige varios'
fd | fzf | xargs bat
```

---

## Git

### delta: diffs coloreados

delta ya está configurado como pager de git, así que `git diff` sale coloreado sin
hacer nada.

```bash
git diff                  # coloreado y navegable
git show HEAD             # idem para un commit
git log -p                # idem dentro del log
git diff --word-diff      # diff por palabras
```

En el pager de delta:

| Atajo | Acción |
|---|---|
| `Espacio` / `↓` | bajar |
| `b` / `↑` | subir |
| `n` / `p` | siguiente / anterior cambio |
| `g` / `G` | principio / final |
| `/` | buscar |
| `q` | salir |

### lazygit

```bash
lg          # abre lazygit en el repositorio actual
```

Navegación básica: `↑↓` para moverse entre archivos, `Enter` para ver los cambios,
`p` para el menú de push, `c` para commit, `Esc` para volver.

### Alias de git

```bash
g       # git
gs      # git status -sb
gst     # git status
gd      # git diff
gds     # git diff --staged
ga      # git add
gaa     # git add --all
gc      # git commit -v
gco     # git checkout
gsw     # git switch
gb      # git branch -vv
gl      # git log --oneline --graph --decorate -20
glp     # log con autor y fecha relativa
gll     # git pull --rebase
gp      # git push
gf      # git fetch --all --prune
gr      # git remote -v
grb     # git rebase
gsta    # git stash
gstp    # git stash pop
```

Además, en `~/.gitconfig`:

```bash
git lg     # log con grafo y autor
git st     # status
git co     # checkout
git br     # branch
git last   # log -1 HEAD
git undo   # reset --soft HEAD~1
git unstage # restore --staged
```

### Lo más útil de git, en bruto

```bash
git restore --staged archivo     # sacar del área de preparación
git restore archivo              # descartar cambios
git reset --soft HEAD~1          # deshacer el último commit, sin perder cambios
git commit --amend              # corregir el último commit
git rebase -i HEAD~5            # reescribir los últimos 5 commits
git reflog                      # historial de HEAD, para recuperar refs
git bisect start                # buscar el commit que introdujo un fallo
```

---

## GitHub — gh

```bash
gh auth login            # autenticar
gh auth status           # ver el estado
gh repo create nombre     # crear un repo y subirlo
gh repo view             # ver el repo actual
gh pr create             # crear un pull request
gh pr list               # listar PRs
gh pr checkout 42        # bajarte una PR
gh pr merge 42           # fusionarla
gh issue create          # crear una incidencia
gh issue list            # listar incidencias
gh release create v1.0.0 # crear una release
gh browse                # abrir el repo en el navegador
gh run list              # ver los workflows de CI
gh run watch             # seguir un workflow en vivo
```

Ejemplo de flujo completo:

```bash
gh repo create mi-proyecto --public --source=. --remote=origin --push
gh pr create --fill
gh pr merge --squash --delete-branch
```

---

## El prompt — starship

```bash
starship prompt          # imprime el prompt actual
starship explain         # desglosa qué muestra cada módulo
starship print-config    # la config completa y ya resuelta (valida el TOML)
starship config          # abre el archivo de configuración en el editor
starship preset --list  # lista los presets disponibles
starship preset gruvbox-rainbow > ~/.config/starship.toml
starship module git_branch   # prueba un módulo suelto
starship timings        # cuánto tarda cada módulo
starship toggle <módulo>   # activa o desactiva un módulo
starship bug-report     # abre una incidencia con tu configuración
```

`starship print-config` es el comando de diagnóstico más útil: valida cada clave de
cada módulo y avisa de las que no existen, indicando la línea exacta.

`starship timings` sirve para encontrar el módulo lento si el prompt tarda.

Detalle completo en [prompt-starship.md](prompt-starship.md).

---

## Tareas — just

`just` ejecuta recetas de un `justfile`, como un Makefile pero más sencillo.

```bash
just                  # ejecuta la primera receta
just --list           # lista las recetas
just install          # ejecuta una receta concreta
just build test       # varias en cadena
just --dry-run build  # muestra lo que haría sin ejecutarlo
just --choose         # selector interactivo de receta
just --evaluate       # muestra las variables
```

En un `justfile`:

```make
default:
    @just --list

build:
    cargo build --release

test:
    cargo test

# Una receta con dependencias
lint: fmt
    cargo clippy

# Con argumentos
tag version:
    git tag v{{version}}
    git push --tags
```

Las variables se leen del entorno o se definen arriba del todo:

```make
export RUSTFLAGS := "-C target-cpu=native"
```

Las recetas del propio `dev-setup`:

| Receta | Qué hace |
|---|---|
| `just install` | sistema + usuario + dotfiles + Java |
| `just user` | sin sudo: binarios y configuración |
| `just shell` | solo la terminal: zsh, tmux y plugins |
| `just chsh` | instala zsh y lo deja como shell de login |
| `just heavy` | Docker, VS Code y bases de datos |
| `just full` | todo |
| `just verify` | comprueba el entorno |
| `just dry-run` | muestra qué haría, sin tocar nada |
| `just edit` | abre el `.zshrc` |
| `just prompt` | abre la config de starship |
| `just reload` | recarga la shell actual |

---

## Datos — yq, jq

```bash
yq '.name' file.yml            # extrae un campo
yq -o=json '.' file.yml        # convierte YAML a JSON
yq -o=yaml '.' file.json       # convierte JSON a YAML
yq '.a.b' file.yml             # campos anidados
yq '.[]' file.yml              # todos los elementos
yq '.[] | select(.enabled)' f # filtra
yq -i '.name = "nuevo"' f.yml  # modifica en el sitio
yq '.a[0]' file.yml            # accede a un array
```

`jq` hace lo mismo para JSON y viene con el sistema.

```bash
jq '.items | length' file.json
jq -r '.[] | .name' file.json
```

---

## Python — uv, ruff

### uv: gestor de proyectos y entornos

```bash
uv init                      # crea un proyecto
uv add requests              # añade una dependencia
uv remove requests           # la quita
uv sync                      # instala lo que dice el lockfile
uv lock                      # actualiza el lockfile
uv run python main.py        # ejecuta en el entorno del proyecto
uv run pytest                # ejecuta un comando con las deps del proyecto
uvx ruff check .             # ejecuta una herramienta suelta, sin instalar
uv venv                      # crea un entorno virtual
uv pip install flask         # pip compatible
uv tree                      # árbol de dependencias
uv python install 3.12       # instala una versión de Python
uv tool install ruff         # instala una herramienta globalmente
uv cache clean               # limpia la caché
```

### ruff: linter y formateador de Python

```bash
ruff check .                 # buscar errores
ruff check --fix .           # corregirlos solos
ruff format .                # formatear
ruff format --check .        # solo comprobar el formato
ruff check --select I .      # solo imports
ruff check --statistics       # resumen por regla
ruff rule E501               # explicar una regla
```

---

## JavaScript — bun, fnm

### bun

```bash
bun init                     # crea package.json
bun add chalk                # añade una dependencia
bun remove chalk
bun install                  # instala todas
bun run <script>             # ejecuta un script
bunx <paquete>               # ejecuta un paquete suelto
bun test                     # pruebas
bun build ./index.ts         # compila
bun --version
```

### fnm: versiones de Node

```bash
fnm list                     # versiones instaladas
fnm install 22               # instala una versión
fnm use 22                   # usa una en esta sesión
fnm default 22               # la versión por defecto
fnm current                  # la activa
```

Con `fnm env --use-on-cd` (ya activo en el `.zshrc`), entrar en un directorio con
`.node-version` cambia la versión solo.

---

## IA — OmniRoute y opencode

OmniRoute es un gateway local: **una** API compatible con OpenAI en `:20128` que enruta
hacia varios proveedores y hace fallback cuando uno falla o agota su cuota. OpenCode lo
consume como el proveedor `omniroute`.

```bash
# Estado y control del gateway
systemctl --user status omniroute
systemctl --user restart omniroute
journalctl --user -u omniroute -f
omniroute doctor

# Panel
xdg-open http://127.0.0.1:20128/dashboard

# Qué modelos puede atender ahora mismo
curl -s -H "Authorization: Bearer $(cat ~/.secrets/omniroute-key)" \
  http://127.0.0.1:20128/v1/models | jq -r '.data[].id' | sort

# Una petición suelta, sin opencode
curl -s http://127.0.0.1:20128/v1/chat/completions \
  -H "Authorization: Bearer $(cat ~/.secrets/omniroute-key)" \
  -H 'Content-Type: application/json' \
  -d '{"model":"auto","messages":[{"role":"user","content":"hola"}]}' \
  | jq -r '.choices[0].message.content'

# OpenCode contra el gateway
opencode run --model omniroute/auto "resume este diff"
```

| Modelo | Criterio de elección |
|---|---|
| `omniroute/auto` | equilibrado |
| `omniroute/auto/cheap` | menor coste |
| `omniroute/auto/coding` | código |
| `omniroute/auto/fast` | menor latencia |
| `omniroute/auto/vision` | con visión |
| `omniroute/combo/<nombre>` | orden explícito, el más fiable |

Los combos no salen en `/v1/models`; se crean con `omniroute combo create` y el script de
integración los detecta al volver a ejecutarse.

Si no quieres registrarte en nada, **Cloudflare Playground** da modelos gratis sin cuenta
(GLM-5.2, DeepSeek V4, Kimi K2.7) a cambio de 10-30 s por petición, porque cada llamada
levanta un Chromium headless:

```bash
just omniroute-browser     # Chromium, ~400 MB, solo la primera vez
just omniroute-free        # prueba cada proveedor y crea el combo free
opencode run --model omniroute/combo/free "hola"
```

Para los demás proveedores gratuitos (Groq, Cerebras, Z.AI, OpenRouter…), rellena
`~/.secrets/omniroute-free.env` y ejecuta `just omniroute-free`.

---

## dev-setup en sí

```bash
cd ~/dev-setup

./install.sh --help          # todas las opciones
./install.sh --dry-run --all # qué haría, sin tocar nada
./install.sh --user --config # sin sudo
./install.sh --apt --chsh    # instala zsh y lo deja como shell de login
./verify.sh                  # comprueba el entorno

just install                 # atajo equivalente
```

Archivos que gestiona:

| Archivo | Qué contiene |
|---|---|
| `~/.zshenv` | variables de entorno base |
| `~/.zprofile` | PATH, fnm, uv, directorios de caché |
| `~/.zshrc` | toda la configuración interactiva de zsh |
| `~/.bashrc` | bloque mínimo equivalente para bash |
| `~/.gitconfig` | delta, `zdiff3`, aliases de git |
| `~/.dircolors` | paleta de colores de archivos |
| `~/.tmux.conf` | configuración de tmux |
| `~/.config/starship.toml` | el prompt |

Y tus propias extensiones, que el script **no** toca:

```bash
~/.config/dev-setup/local.sh
```

```bash
# ejemplo
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
alias logs='journalctl -u mi-servicio -f'
```

### Los logs y los backups

```bash
ls -t ~/dev-setup/logs/ | head          # ejecuciones recientes
less ~/dev-setup/logs/$(ls -t ~/dev-setup/logs/ | head -1)
ls ~/dev-setup/backups/                  # copias de cada archivo tocado
```

Para restaurar un backup:

```bash
cp ~/dev-setup/backups/.zshrc.20261020-224550.bak ~/.zshrc
```

---

## Referencia de flags

### Los más útiles de cada herramienta

| Herramienta | Flag | Efecto |
|---|---|---|
| `rg` | `-i` | ignora mayúsculas |
| `rg` | `-l` | solo nombres de archivo |
| `rg` | `-w` | palabra completa |
| `rg` | `-v` | coincide con lo contrario |
| `rg` | `-t` | filtra por tipo de archivo |
| `rg` | `-g` | filtra por patrón de nombre |
| `rg` | `-A` / `-B` | contexto después / antes |
| `rg` | `--stats` | estadísticas de la búsqueda |
| `fd` | `-t d` / `-t f` | solo directorios / ficheros |
| `fd` | `-e` | filtra por extensión |
| `fd` | `-E` | excluye un directorio |
| `fd` | `-x` / `-X` | ejecuta por resultado / con todos |
| `fd` | `--changed-within` | modificados en un periodo |
| `eza` | `--git` | estado de git por archivo |
| `eza` | `--code` | resumen de líneas de código |
| `eza` | `--tree` | vista de árbol |
| `bat` | `-n` | números de línea |
| `bat` | `-H` | resalta un rango de líneas |
| `bat` | `-d` | solo lo cambiado respecto a git |
| `fzf` | `--preview` | vista previa |
| `fzf` | `--multi` | selección múltiple |
| `fzf` | `--exact` | coincidencia exacta |
| `delta` | *(ya es el pager)* | diffs coloreados |

### Atajos de shell

| Atajo | Acción |
|---|---|
| `Ctrl+T` | buscar archivos con fzf |
| `Ctrl+R` | buscar en el historial con fzf |
| `Alt+C` | saltar a un directorio visitado |
| `Tab` | completado con fzf |
| `↑` / `↓` | historial por prefijo |
| `Ctrl+←` / `Ctrl+→` | moverse por palabras |
| `Ctrl+Backspace` | borrar la palabra anterior |
| `Ctrl+X Ctrl+E` | editar la línea en el editor |
| `Alt+.` | último argumento del comando anterior |
| `Mayús+Tab` | completado clásico |

### Para ver la ayuda de cualquier cosa

```bash
comando --help        # ayuda completa
man comando           # página de manual
comando --version     # versión
tldr <comando>        # ejemplos resumidos (si instalas tldr)
```

Todos estos comandos tienen `--help`. Y en zsh, `Ctrl+R` sobre el propio nombre del
comando busca en tu historial cómo lo has usado antes.
