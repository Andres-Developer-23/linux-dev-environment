# La shell: zsh en detalle

Configuración completa de zsh que instala `dev-setup`, archivo por archivo, opción por
opción.

---

## 1. Los tres archivos

zsh lee hasta tres archivos, en este orden:

| Archivo | Cuándo se carga | Qué va ahí |
|---|---|---|
| `~/.zshenv` | **siempre**, incluso en scripts no interactivos | variables de entorno que cualquier proceso zsh necesita |
| `~/.zprofile` | solo en shells de **login** (la primera terminal de la sesión) | PATH, gestores de versiones, cosas que se inicializan una vez |
| `~/.zshrc` | solo en shells **interactivos** | todo lo demás: prompt, alias, plugins, atajos |

El orden importa: `.zshenv` se lee antes que `.zprofile`, así que las variables `XDG_*`
que define `.zshenv` ya existen cuando `.zprofile` calcula rutas de caché.

### `~/.zshenv` — entorno base

```bash
export EDITOR="nvim"
export VISUAL="$EDITOR"
export PAGER="less"
export LESS='-R -F -X -M -i -N'      # color, no paginar si cabe, no vaciar pantalla
export LESSHISTFILE="$HOME/.lesshst"
export COLORTERM="truecolor"

export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.opencode/bin:$PATH"
```

`LESS='-R -F -X -M -i -N'` es elconjunto estándar para que `less` se comporte bien en
una terminal:

- `-R` — interpreta los códigos de color del archivo
- `-F` — sale solo si el contenido cabe en una pantalla
- `-X` — no borra la pantalla al salir
- `-M` — no hace pausa al llegar al final
- `-i` — la búsqueda ignora mayúsculas
- `-N` — muestra el número de línea

### `~/.zprofile` — arranque de sesión

```bash
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.opencode/bin:$PATH"

# Node.js con fnm (cambia de versión según el .node-version del proyecto)
if [ -x "$HOME/.local/share/fnm/fnm" ]; then
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# Python con uv
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

mkdir -p "$XDG_CACHE_HOME/zsh" 2>/dev/null
```

fnm con `--use-on-cd` cambia automáticamente a la versión de Node que pida el
proyecto en el que entras, leyendo `.node-version` o `.nvmrc`.

### `~/.zshrc` — configuración interactiva

Todo lo que sigue va en este archivo. Está organized en secciones para que sea
fácil de leer y de modificar.

---

## 2. Historial

```bash
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000        # líneas en memoria
SAVEHIST=200000        # líneas guardadas en disco
HISTTIMEFORMAT='%F{yellow}[%T]%f '

setopt APPEND_HISTORY          # añade al archivo, no sobrescribe
setopt SHARE_HISTORY           # historial compartido entre sesiones abiertas
setopt HIST_IGNORE_DUPS        # ignora duplicados consecutivos
setopt HIST_IGNORE_ALL_DUPS    # elimina duplicados de todo el historial
setopt HIST_REDUCE_BLANKS      # quita espacios sobrantes
setopt HIST_SAVE_NO_DUPS       # no guarda duplicados al escribir
setopt HIST_VERIFY             # no ejecuta la línea expandida hasta confirmarla
setopt HIST_IGNORE_SPACE       # ignora comandos que empiezan por espacio
```

`SHARE_HISTORY` es la diferencia importante: con varias terminales abiertas, el
historial es uno solo. Escribes `git commit` en una y lo encuentras con `↑` en otra.

`HIST_VERIFY` es una salvaguarda: si escribes `rm *.log` y el glob se expande a
`rm a.log b.log c.log`, zsh te enseña la línea expandida y te pide confirmar antes de
borrar.

El formato del timestamp es relativo: `5m`, `2h`, `3d` — se calcula al vuelo.

---

## 3. Opciones de zsh

```bash
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS EXTENDED_GLOB NOCASEGLOB
setopt NO_BEEP LIST_AMBIGUOUS
unsetopt FLOW_CONTROL BEEP
```

| Opción | Qué hace |
|---|---|
| `AUTO_CD` | escribir el nombre de un directorio cambia a él |
| `AUTO_PUSHD` | cada `cd` añade al stack de directorios (`cd -` los recorre) |
| `PUSHD_IGNORE_DUPS` | no repite directorios en el stack |
| `EXTENDED_GLOB` | glob avanzado: `*(.om[1,10])`, `^foo`, `#bar` |
| `NOCASEGLOB` | los globs no distinguen mayúsculas |
| `LIST_AMBIGUOUS` | no autocompleta cuando hay varias coincidencias |
| `FLOW_CONTROL` *(desactivado)* | `Ctrl+S` deja de congelar la terminal |

Con `EXTENDED_GLOB` puedes hacer cosas como:

```bash
ls *(.om[1,5])        # los 5 archivos más grandes
ls ^*.log              # todo menos los .log
ls *(.Lm+10)           # archivos de más de 10 MB
```

---

## 4. Colores de archivos

```bash
if command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b "$HOME/.dircolors" 2>/dev/null || dircolors -b 2>/dev/null)"
fi
```

`~/.dircolors` define una paleta de 256 colores por tipo de archivo: directorios en
azul, ejecutables en verde, imágenes en rojo, código en otro tono… El mismo `LS_COLORS`
lo usan `ls`, `eza`, `tree` y las listas de completado de zsh, así que todo se ve
coherente.

```bash
DIR   01;38;5;39      # directorios
LINK  01;38;5;45      # enlaces simbólicos
EXEC  01;38;5;114     # ejecutables
REG   00;38;5;252     # archivos normales
*.py  01;38;5;221     # por extensión
```

El formato es `TIPO ATRIBUTOS;COLOR-FG;COLOR-BG`, y los `*` al principio aplican a
extensiones.

---

## 5. Completado

```bash
autoload -Uz compinit
[[ -d "$HOME/.local/share/zsh-plugins/zsh-completions/src" ]] && \
  fpath=("$HOME/.local/share/zsh-plugins/zsh-completions/src" $fpath)
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
```

`compinit` genera el índice de completados; `zcompdump` es ese índice cacheado, en
`~/.cache/zsh/zcompdump`. Se regenera solo cuando cambia el conjunto de funciones.

Después, los estilos:

```bash
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}▸ %d%f'
zstyle ':completion:*:warnings' format '%F{red}✗ sin coincidencias para: %d%f'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/compcache"
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' verbose yes
zstyle ':completion:*' list-prompt ''
zstyle ':completion:*' select-prompt ''
zstyle ':completion:*' matcher-list \
  'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*' 'r:^=*' 'l:^=*' \
  'r:/*' 'l:/*' 'r:*' 'l:*'
```

| Estilo | Efecto |
|---|---|
| `menu select` | menú navegable con flechas |
| `group-name ''` | sin el nombre del grupo entre paréntesis |
| `descriptions format` | encabezado del grupo en amarillo |
| `warnings format` | error en rojo cuando no hay coincidencias |
| `list-colors` | los archivos del completado usan los colores de `.dircolors` |
| `matcher-list` | búsqueda insensible a mayúsculas, y por prefijo, sufijo, ruta… |

`matcher-list` es lo que hace que `git checkout<Tab>` encuentre ramas por el final del
nombre, o que `cd /u<Tab>` encuentre rutas que terminan en `/u`.

---

## 6. Plugins

### zsh-autosuggestions

```bash
zstyle ':zsh-autosuggestions:*' suggestion-style 'fg=cyan italic'
zstyle ':zsh-autosuggestions:*' max-exposure 30
zstyle ':zsh-autosuggestions:*' fuzzy-match yes
```

Mientras escribes, aparece a la derecha la continuación más probable del comando, en
gris azulado y cursiva. `Ctrl+F` o `→` la acepta; `Alt+→` acepta solo una palabra.

- `max-exposure 30` — máximo 30 sugerencias expuestas
- `fuzzy-match yes` — acepta coincidencias aproximadas

### zsh-syntax-highlighting

```bash
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
```

Colorea la línea mientras la escribes: los comandos en verde, las cadenas en amarillo, los
comentarios en gris. `main` es el resaltador principal, `brackets` los corchetes y
`pattern` los patrones de glob.

**Este plugin va siempre al final del `.zshrc`.** Si se carga antes de que estén
definidos los widgets, rompe el resaltado.

### fzf-tab

```bash
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:*' fzf-flags --color=always --height=45% --layout=reverse \
  --border=rounded --info=inline --marker='❯' --prompt='▸ '
zstyle ':fzf-tab:*' single-group color red
zstyle ':fzf-tab:complete:(cd|z|cdpath|pushd):*' fzf-flags \
  --preview='echo $realpath 2>/dev/null | head -1'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags \
  --preview='ps --pid=$word -o comm,args --no-headers'
```

Convierte el menú de completado en una ventana de fzf. Los `preview` específicos hacen
que al completar un directorio veas su ruta real, y al completar un PID veas el proceso.

`switch-group '<' '>'` permite volver al grupo anterior con `<` y `>`.

---

## 7. fzf

```bash
export FZF_DEFAULT_OPTS="--height=45% --layout=reverse --border=rounded --info=inline
  --marker='❯' --prompt='🔎 ' --color=fg:#c0caf5,bg:#1a1b26,hl:#7dcfff,…"
source <(fzf --zsh)
```

`fzf --zsh` es la integración oficial: instala los widgets y los atajos.

| Atajo | Widget | Qué busca |
|---|---|---|
| `Ctrl+T` | `fzf-file-widget` | archivos, con vista previa |
| `Ctrl+R` | `fzf-history-widget` | en el historial |
| `Alt+C` | `fzf-cd-widget` | directorios visitados (usa zoxide) |

`FZF_CTRL_R_OPTS` incluye un atajo extra: `Ctrl+O` abre la vista previa del comando
en el historial, para ver qué hace antes de ejecutarlo.

---

## 8. zoxide: `cd` inteligente

```bash
eval "$(zoxide init zsh)"

cd() {
  if (( $# == 0 )); then
    builtin cd
  elif [[ "$1" == "-" || "$1" == +* || "$1" == "~" || "$1" == "~/"* \
          || "$1" == /* || -d "$1" ]]; then
    builtin cd "$@"
  else
    z "$@"
  fi
}
```

zoxide registra cada directorio en el que entras y los ordena por frecuencia. La función
`cd` decide:

- **sin argumentos** → `cd` normal (a casa)
- **ruta real** (`..`, `/usr/local`, `~`, un directorio que existe) → `cd` normal
- **cualquier otra cosa** → salto inteligente de zoxide

Así `cd api` te lleva al directorio `api` que más has visitado, pero `cd ../otro`
sigue funcionando como siempre.

Comandos útiles:

```bash
z              # lista los directorios más visitados con su puntuación
z api          # salta al mejor match
z -            # directorio anterior
z -            # el primero/last (con el prefijo)
zoxide remove ~/proyecto-que-ya-no-existe
```

---

## 9. Aliases

Se declaran con `if command -v … ; then` para que el archivo funcione igual en una
máquina sin alguna de las herramientas.

```bash
# Listar
alias ls='eza --icons --group-directories-first'
alias ll='eza -lah --icons --group-directories-first --git'
alias la='eza -a --icons --group-directories-first'
alias lt='eza --tree --level=2 --icons --group-directories-first'
alias lta='eza --tree --level=3 --all --icons --group-directories-first'

# Ver
alias cat='bat --paging=never --style=plain'
alias catp='bat --paging=never'
alias catn='bat --paging=never --style=numbers'

# Buscar
alias grep='rg --color=auto'
alias rgi='rg --color=auto --ignore-case'
alias rgh='rg --color=auto --hidden --glob "!.git"'
alias find='fd'
alias fdf='fd --type f'
alias fdd='fd --type d'

# Git
alias g='git'
alias gs='git status -sb'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias glp='git log --pretty=format:"%C(auto)%h%d %s %C(green)(%cr) %C(bold blue)<%an>" --date=relative -25'
alias lg='lazygit'

# Navegar
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Utilidades
alias reload='source ~/.zshrc && echo "⟳ .zshrc recargado"'
alias zshcfg='nvim ~/.zshrc'
alias starcfg='nvim ~/.config/starship.toml'
alias ports='ss -tulpn'
alias myip='curl -s ifconfig.me && echo'
```

Notas:

- `cat` usa `--style=plain`: sin el `bat` se pierde el resaltado al encadenar, por
  ejemplo en un pipe. `catp` mantiene el estilo completo y `catn` añade números de línea.
- `grep` → `rg` cambia el comportamiento: `rg` respeta `.gitignore` y no busca en
  binarios. Para el `grep` clásico, `command grep`.
- `glp` (log prettified) muestra el autor y la fecha relativa de cada commit.

### Ver los alias

```bash
alias            # todos
alias | grep git # solo los de git
unalias grep     # quitar uno temporalmente
```

---

## 10. Atajos de teclado

```bash
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
```

`↑` y `↓` buscan en el historial por el prefijo que ya escribiste: si escribes `git st`
y pulsas `↑`, recorre solo los comandos que empiezan por `git st`.

El resto:

```bash
bindkey '^[[1;5C' forward-word        # Ctrl+→
bindkey '^[[1;5D' backward-word       # Ctrl+←
bindkey '^[[H' beginning-of-line      # Home
bindkey '^[[F' end-of-line            # End
bindkey '^[[3~' kill-line             # Supr
bindkey '^H' backward-kill-word      # Ctrl+Retroceso
bindkey 'escape .' insert-last-argument  # Alt+.
bindkey '^[[Z' complete               # Mayús+Tab
```

`Alt+.` inserta el último argumento del comando anterior: `mkdir -p /tmp/x` y luego
`cd Alt+.` → `cd /tmp/x`.

`Ctrl+X Ctrl+E` abre la línea actual en el editor, para corregir un comando largo sin
volver a escribirlo.

### Ver y cambiar los atajos

```bash
bindkey -L          # lista todos
bindkey -l          # lista los de lectura
bindkey '^X^Q' quoted-insert   # asigna uno nuevo
```

---

## 11. Editores y gestores de versiones

```bash
if command -v nvim >/dev/null 2>&1; then
  export EDITOR=nvim
  export VISUAL=nvim
  alias vim='nvim'
  alias vi='nvim'
fi

if [ -x "$HOME/.local/share/fnm/fnm" ]; then
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
```

`fnm env --use-on-cd` cambia de versión de Node automáticamente al entrar en un
proyecto con `.node-version`.

---

## 12. direnv

```bash
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
```

direnv carga las variables de un `.envrc` al entrar en el directorio y las descarga al
salir. Muy útil en proyectos de Python con un `.env` propio.

Uso:

```bash
echo 'export FLASK_ENV=development' > .envrc
direnv allow .envrc
```

---

## 13. Personalizar

Todo lo anterior vive en `~/.zshrc`, dentro del bloque `dev-setup`. Hay dos formas de
cambiarlo:

**1. Editando el bloque a mano.** Funciona, pero la próxima ejecución de
`./install.sh --config` lo sobrescribe.

**2. Editando `install.sh` y ejecutando el script.** Es la forma recomendada: el cambio
queda en el repositorio y se propaga a otras máquinas.

```bash
# 1. edita el bloque zsh_block() en install.sh
vim ~/dev-setup/install.sh

# 2. aplica
cd ~/dev-setup && ./install.sh --config
```

Para recargar sin reejecutar el script:

```bash
reload
```

---

## 14. Diagnóstico

```bash
# ¿Qué está cargado?
echo $ZSH_VERSION
print -l $fpath
print -l $functions | grep -i fzf

# ¿La configuración es válida?
zsh -n ~/.zshrc && echo "sintaxis OK"

# ¿Por qué no funciona un alias?
alias ls
whence -w ls
type ls

# ¿Qué plugin da problemas?
zle-line-init
```

Para depurar el arranque, `zsh -x ~/.zshrc` muestra cada comando que se ejecuta.

Para la referencia de las herramientas que usa esta configuración, mira
[comandos.md](comandos.md).
