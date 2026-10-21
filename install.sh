#!/usr/bin/env bash
# ============================================================================
# dev-setup — bootstrap reproducible para Linux Mint 22.3 (base Ubuntu noble)
#
# Uso:
#   ./install.sh --apt --user --config --java     # recomendado (pide sudo)
#   ./install.sh --all                            # todo, incluye DB/Docker/VS Code
#   ./install.sh --user --config                  # sin sudo (solo ~/.local)
#   ./install.sh --dry-run --all                  # muestra qué haría
#
# Principios: idempotente, por capas, sin sobrescribir configs del usuario,
# backups en ./backups y log en ./logs.
# ============================================================================
set -Eeuo pipefail
export LC_ALL=C

SETUP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SETUP_DIR/logs"
BACKUP_DIR="$SETUP_DIR/backups"
mkdir -p "$LOG_DIR" "$BACKUP_DIR"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

MARK_BEGIN="# >>> dev-setup >>>"
MARK_END="# <<< dev-setup <<<"
LOCAL_BIN="$HOME/.local/bin"
ZSH_PLUGIN_DIR="$HOME/.local/share/zsh-plugins"
export PATH="$LOCAL_BIN:$HOME/.bun/bin:$HOME/.opencode/bin:$PATH"

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
L_APT=0 L_USER=0 L_CONFIG=0 L_JAVA=0 L_DOCKER=0 L_VSCODE=0 L_DB=0 L_NVIM=0
DRY=0 CHSH=0
SUDO_KEEP_PID=""

usage() {
  cat <<'EOF'
dev-setup — instala el entorno de ingeniería por capas

Capas:
  --apt        Paquetes de sistema vía apt (toolchain, CLI moderno, clientes DB)
  --user       Binarios en ~/.local/bin: starship, zoxide, yq, lazygit, just,
               delta, bun, ruff, neovim estable; fuentes Nerd Font; plugins de
               zsh (autosuggestions, syntax-highlighting, completions, fzf-tab)
  --config     Dotfiles gestionados: bash/zsh, git, tmux, starship, dircolors
               y la fuente de la terminal (con backup)
  --java       OpenJDK 21 + Maven
  --docker     Docker Engine + compose + buildx (añade tu usuario al grupo docker)
  --vscode     Visual Studio Code (repo oficial de Microsoft)
  --db         MySQL Server, Redis, MongoDB 8 y DB Browser for SQLite
  --nvim       LazyVim sobre Neovim (solo si ~/.config/nvim no existe)
  --all        Todas las capas anteriores (no cambia tu shell)
  --chsh       Cambia tu shell de login a zsh (requiere cerrar sesión)

Opciones:
  --dry-run    Muestra los comandos sin ejecutarlos
  -h, --help   Esta ayuda

Ejemplos:
  ./install.sh --apt --user --config --java
  ./install.sh --user --config
  ./install.sh --all
EOF
}

if (($# == 0)); then usage; exit 0; fi
while (($#)); do
  case "$1" in
    --apt) L_APT=1 ;;
    --user) L_USER=1 ;;
    --config) L_CONFIG=1 ;;
    --java) L_JAVA=1 ;;
    --docker) L_DOCKER=1 ;;
    --vscode) L_VSCODE=1 ;;
    --db) L_DB=1 ;;
    --nvim) L_NVIM=1 ;;
    --all) L_APT=1 L_USER=1 L_CONFIG=1 L_JAVA=1 L_DOCKER=1 L_VSCODE=1 L_DB=1 L_NVIM=1 ;;
    --chsh) CHSH=1 ;;
    --dry-run) DRY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  C_OK=$'\e[32m'; C_WARN=$'\e[33m'; C_ERR=$'\e[31m'; C_DIM=$'\e[2m'; C_OFF=$'\e[0m'
else
  C_OK="" C_WARN="" C_ERR="" C_DIM="" C_OFF=""
fi
ok()   { printf '%s✓%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '%s!%s %s\n' "$C_WARN" "$C_OFF" "$*"; }
step() { printf '\n%s==>%s %s\n' "$C_DIM" "$C_OFF" "$*"; }
die()  { printf '%s✗%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; exit 1; }

trap 'printf "\n%s✗ Fallo en la línea %s. Revisa %s%s\n" "$C_ERR" "$LINENO" "$LOG_FILE" "$C_OFF" >&2; exit 1' ERR

have() { command -v "$1" >/dev/null 2>&1; }

run() {
  if ((DRY)); then
    printf '  %s[dry-run]%s' "$C_DIM" "$C_OFF"
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

run_shell() { # comando compuesto, ya citado
  if ((DRY)); then
    printf '  %s[dry-run]%s %s\n' "$C_DIM" "$C_OFF" "$1"
    return 0
  fi
  bash -c "$1"
}

init_sudo() {
  if ((DRY)); then return 0; fi
  have sudo || die "sudo no está instalado"
  step "Autenticando sudo (se pedirá la contraseña una vez)"
  sudo -v || die "autenticación sudo cancelada"
  ( while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
  SUDO_KEEP_PID=$!
  trap '[[ -n "$SUDO_KEEP_PID" ]] && kill "$SUDO_KEEP_PID" 2>/dev/null || true' EXIT
}

backup_file() {
  [[ -f "$1" ]] || return 0
  local dst="$BACKUP_DIR/$(basename "$1").$(date +%Y%m%d-%H%M%S).bak"
  cp -a "$1" "$dst"
  printf '  backup: %s\n' "$dst"
}

APT_UPDATED=0
apt_update() {
  if ((APT_UPDATED)); then return 0; fi
  run sudo apt-get update
  APT_UPDATED=1
}

apt_install() {
  local p missing=()
  for p in "$@"; do
    if ! dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed'; then
      missing+=("$p")
    fi
  done
  if ((${#missing[@]} == 0)); then
    ok "apt: ya estaba todo instalado"
    return 0
  fi
  apt_update
  run sudo apt-get install -y --no-install-recommends "${missing[@]}"
}

# Devuelve "tag url" del release más reciente cuyo asset case con el regex.
gh_release_info() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" |
    python3 -c '
import json, re, sys
d = json.load(sys.stdin)
pat = re.compile(sys.argv[1])
asset = next(a for a in d["assets"] if pat.search(a["name"]))
print(d["tag_name"], asset["browser_download_url"])
' "$2"
}

download() { # url destino
  run curl -fL --retry 3 --connect-timeout 15 --progress-bar -o "$2" "$1"
}

install_tar_bin() { # repo regex bin
  local repo=$1 regex=$2 bin=$3 info tag url tmp found
  if ((DRY)); then
    printf '  %s[dry-run]%s instalar %s desde GitHub (%s)\n' "$C_DIM" "$C_OFF" "$bin" "$repo"
    return 0
  fi
  info="$(gh_release_info "$repo" "$regex")"
  tag=${info%% *}; url=${info#* }
  tmp="$(mktemp -d)"
  printf '  %s %s\n' "$bin" "$tag"
  download "$url" "$tmp/pkg"
  run tar -xf "$tmp/pkg" -C "$tmp"
  found="$(find "$tmp" -type f -name "$bin" -perm -u+x | head -n1)"
  [[ -n "$found" ]] || die "no encontré el binario $bin dentro del release $tag"
  run install -m 0755 "$found" "$LOCAL_BIN/$bin"
  rm -rf "$tmp"
}

ensure_uv() {
  if have uv; then ok "uv $(uv --version | awk '{print $2}')"; return; fi
  step "Instalando uv"
  run_shell 'curl -LsSf https://astral.sh/uv/install.sh | sh'
}

# ---------------------------------------------------------------------------
# Plugins de zsh (sin sudo): los que no están en apt o queremos la última versión
# ---------------------------------------------------------------------------
ZSH_PLUGINS=(
  "zsh-users/zsh-autosuggestions"
  "zsh-users/zsh-syntax-highlighting"
  "zsh-users/zsh-completions"
  "Aloxaf/fzf-tab"
)

install_zsh_plugins() {
  step "Plugins de zsh en $ZSH_PLUGIN_DIR"
  mkdir -p "$ZSH_PLUGIN_DIR"
  local repo name
  for repo in "${ZSH_PLUGINS[@]}"; do
    name="${repo##*/}"
    local dir="$ZSH_PLUGIN_DIR/$name"
    if [[ -d "$dir/.git" ]]; then
      if [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]; then
        warn "$name: tiene cambios locales; no actualizo"
        continue
      fi
      if ((DRY)); then
        printf '  %s[dry-run]%s actualizar %s\n' "$C_DIM" "$C_OFF" "$name"
      elif run git -C "$dir" pull --ff-only --quiet; then
        ok "$name actualizado"
      fi
    else
      if ((DRY)); then
        printf '  %s[dry-run]%s clonar %s\n' "$C_DIM" "$C_OFF" "$name"
      elif run git clone --depth 1 --quiet "https://github.com/$repo.git" "$dir"; then
        ok "$name instalado"
      fi
    fi
  done
}

# ---------------------------------------------------------------------------
# Fuentes Nerd Font (iconos del prompt)
# ---------------------------------------------------------------------------
install_nerd_font() { # nombre_familia asset_zip carpeta_destino
  local label=$1 asset=$2 dest="$HOME/.local/share/fonts/$3"
  # OJO: sin -q, porque con `set -o pipefail` el SIGPIPE de grep hace fallar el pipeline
  if fc-list 2>/dev/null | grep -i "$label" >/dev/null; then
    ok "fuente $label"
    return
  fi
  if ((DRY)); then
    printf '  %s[dry-run]%s instalar %s\n' "$C_DIM" "$C_OFF" "$label"
    return
  fi
  step "Instalando $label"
  local tmp; tmp="$(mktemp -d)"
  download "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$asset" "$tmp/font.zip"
  run mkdir -p "$dest"
  run unzip -q -o "$tmp/font.zip" -d "$dest"
  run fc-cache -f "$HOME/.local/share/fonts"
  rm -rf "$tmp"
}

# ---------------------------------------------------------------------------
# Capa: usuario (sin sudo)
# ---------------------------------------------------------------------------
layer_user() {
  step "Capa usuario: CLI moderna en ~/.local/bin"
  mkdir -p "$LOCAL_BIN"

  ensure_uv

  if have ruff; then
    ok "ruff $(ruff --version 2>/dev/null | awk '{print $2}')"
  else
    step "Instalando ruff"
    run uv tool install ruff@latest
  fi

  if have starship; then
    ok "starship $(starship --version | head -n1 | awk '{print $2}')"
  else
    step "Instalando starship"
    run_shell 'curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"'
  fi

  if have zoxide; then
    ok "zoxide $(zoxide --version | awk '{print $2}')"
  else
    step "Instalando zoxide"
    install_tar_bin ajeetdsouza/zoxide 'x86_64-unknown-linux-musl\.tar\.gz$' zoxide
  fi

  if have yq; then
    ok "yq $(yq --version | awk '{print $NF}')"
  elif ((DRY)); then
    printf '  %s[dry-run]%s instalar yq (mikefarah)\n' "$C_DIM" "$C_OFF"
  else
    step "Instalando yq (mikefarah)"
    local arch; arch=$(uname -m)
    case "$arch" in x86_64) arch=amd64 ;; aarch64) arch=arm64 ;; esac
    download "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}" "$LOCAL_BIN/yq"
    run chmod +x "$LOCAL_BIN/yq"
  fi

  if have lazygit; then
    ok "lazygit $(lazygit --version | awk -F'[:,]' '{print $2}' | tr -d ' ')"
  else
    step "Instalando lazygit"
    install_tar_bin jesseduffield/lazygit 'lazygit_.*linux_x86_64\.tar\.gz$' lazygit
  fi

  if have just; then
    ok "just $(just --version | awk '{print $2}')"
  else
    step "Instalando just"
    install_tar_bin casey/just 'x86_64-unknown-linux-musl\.tar\.gz$' just
  fi

  if have delta; then
    ok "delta $(delta --version)"
  else
    step "Instalando git-delta"
    install_tar_bin dandavison/delta 'x86_64-unknown-linux-gnu\.tar\.gz$' delta
  fi

  if have bun; then
    ok "bun $(bun --version)"
  else
    step "Instalando bun"
    run_shell 'curl -fsSL https://bun.sh/install | bash'
  fi
  if [[ -x "$HOME/.bun/bin/bun" ]]; then
    run ln -sfn "$HOME/.bun/bin/bun" "$LOCAL_BIN/bun"
    run ln -sfn "$HOME/.bun/bin/bun" "$LOCAL_BIN/bunx"
  fi

  if [[ -x "$HOME/.local/opt/nvim/bin/nvim" ]]; then
    ok "neovim $("$HOME/.local/opt/nvim/bin/nvim" --version | head -n1 | awk '{print $2}') (local)"
  elif ((DRY)); then
    printf '  %s[dry-run]%s instalar Neovim estable en ~/.local/opt/nvim\n' "$C_DIM" "$C_OFF"
  else
    step "Instalando Neovim estable en ~/.local/opt/nvim"
    local info tag url tmp src
    info="$(gh_release_info neovim/neovim 'nvim-linux.*x86_64\.tar\.gz$')"
    tag=${info%% *}; url=${info#* }
    printf '  neovim %s\n' "$tag"
    tmp="$(mktemp -d)"
    download "$url" "$tmp/nvim.tar.gz"
    run tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
    src="$(find "$tmp" -maxdepth 2 -type d -name 'nvim-linux*' | head -n1)"
    [[ -n "$src" ]] || die "estructura inesperada del tarball de Neovim"
    run rm -rf "$HOME/.local/opt/nvim"
    run mkdir -p "$HOME/.local/opt"
    run mv "$src" "$HOME/.local/opt/nvim"
    run ln -sfn "$HOME/.local/opt/nvim/bin/nvim" "$LOCAL_BIN/nvim"
    rm -rf "$tmp"
  fi

  # JetBrainsMono Nerd Font (la que ya usa el usuario) + Meslo (estándar de starship)
  install_nerd_font "JetBrainsMono Nerd" "JetBrainsMono.zip" "JetBrainsMonoNerd"
  install_nerd_font "MesloLGS Nerd" "Meslo.zip" "MesloNerdFont"

  install_zsh_plugins
}

# ---------------------------------------------------------------------------
# Capa: apt
# ---------------------------------------------------------------------------
layer_apt() {
  step "Capa sistema: toolchain y CLI (apt)"
  local base=(
    build-essential cmake ninja-build pkg-config clang lldb gdb
    autoconf automake libtool
    python3-dev python3-venv python3-pip
    libssl-dev libffi-dev zlib1g-dev libsqlite3-dev libreadline-dev
    libbz2-dev liblzma-dev
    unzip zip p7zip-full xz-utils file ca-certificates gnupg
    man-db less
  )
  local cli=(
    zsh zsh-syntax-highlighting zsh-autosuggestions tmux vim
    eza zoxide jq tree htop btop lsof strace ltrace ncdu rsync
    httpie mtr-tiny nmap tcpdump dnsutils net-tools whois traceroute
    wireguard-tools openssh-client
    shellcheck direnv git-lfs gh git-delta just
    sqlite3 postgresql-client mysql-client redis-tools
    fonts-firacode
  )
  apt_install "${base[@]}"
  apt_install "${cli[@]}"
  ok "toolchain y CLI instaladas"
}

# ---------------------------------------------------------------------------
# Capa: Java
# ---------------------------------------------------------------------------
layer_java() {
  step "Capa Java: OpenJDK 21 + Maven"
  apt_install openjdk-21-jdk maven
  if ((DRY)); then
    ok "OpenJDK 21 + Maven (planificado)"
    return 0
  fi
  if have java; then
    ok "Java: $(java -version 2>&1 | head -n1)"
  else
    warn "Java no quedó en PATH; revisa update-alternatives"
  fi
}

# ---------------------------------------------------------------------------
# Capa: Docker
# ---------------------------------------------------------------------------
layer_docker() {
  step "Capa Docker Engine + compose + buildx"
  if have docker; then
    ok "docker $(docker --version)"
  else
    local codename; codename="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-noble}")"
    if ((DRY)); then
      printf '  %s[dry-run]%s configurar repo oficial de Docker (%s)\n' "$C_DIM" "$C_OFF" "$codename"
    else
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
        sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
      printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu %s stable\n' \
        "$(dpkg --print-architecture)" "$codename" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
      APT_UPDATED=0
    fi
    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi
  if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    run sudo usermod -aG docker "$USER"
    warn "Cierra sesión y vuelve a entrar para usar Docker sin sudo"
  fi
}

# ---------------------------------------------------------------------------
# Capa: VS Code
# ---------------------------------------------------------------------------
layer_vscode() {
  step "Capa VS Code (repo oficial de Microsoft)"
  if have code; then
    ok "code $(code --version | head -n1)"
    return
  fi
  if ((DRY)); then
    printf '  %s[dry-run]%s configurar repo de Microsoft y apt install code\n' "$C_DIM" "$C_OFF"
  else
    local tmp; tmp="$(mktemp)"
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >"$tmp"
    sudo install -D -m 0644 "$tmp" /etc/apt/keyrings/microsoft.gpg
    rm -f "$tmp"
    printf 'deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main\n' |
      sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    APT_UPDATED=0
  fi
  apt_install code
}

# ---------------------------------------------------------------------------
# Capa: bases de datos
# ---------------------------------------------------------------------------
layer_db() {
  step "Capa bases de datos: MySQL, Redis, MongoDB y DB Browser"
  apt_install mysql-server redis-server sqlitebrowser

  if dpkg-query -W -f='${Status}' mongodb-org 2>/dev/null | grep -q 'install ok installed'; then
    ok "mongodb-org ya instalado"
    return
  fi
  if ((DRY)); then
    printf '  %s[dry-run]%s configurar repo MongoDB 8.0 y apt install mongodb-org\n' "$C_DIM" "$C_OFF"
    return
  fi
  curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc |
    sudo gpg --yes -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
  printf 'deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse\n' |
    sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list >/dev/null
  APT_UPDATED=0
  apt_install mongodb-org
}

# ---------------------------------------------------------------------------
# Capa: configuración (dotfiles administrados)
# ---------------------------------------------------------------------------
upsert_block() { # archivo bloque
  local file=$1 block=$2
  touch "$file"
  if grep -qF "$MARK_BEGIN" "$file"; then
    sed -i "\|^${MARK_BEGIN}$|,\|^${MARK_END}$|d" "$file"
  fi
  printf '\n%s\n' "$block" >>"$file"
  # quita las líneas en blanco acumuladas al principio del archivo
  sed -i '/./,$!d' "$file"
}

shell_block() { # bash|zsh
  local sh=$1
  cat <<EOF
$MARK_BEGIN
# Generado por ~/dev-setup. Edita el bloque o el script, no ambos.
export PATH="\$HOME/.local/bin:\$HOME/.bun/bin:\$PATH"

if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lah --icons --group-directories-first'
  alias la='eza -a --icons --group-directories-first'
  alias lt='eza --tree --level=2 --icons --group-directories-first'
fi
if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
fi

if command -v starship >/dev/null 2>&1; then eval "\$(starship init $sh)"; fi
if command -v zoxide >/dev/null 2>&1; then eval "\$(zoxide init $sh)"; fi
if command -v direnv >/dev/null 2>&1; then eval "\$(direnv hook $sh)"; fi
if command -v nvim >/dev/null 2>&1; then export EDITOR=nvim VISUAL=nvim; fi

# Extensiones personales (este archivo NO lo gestiona dev-setup)
[ -f "$HOME/.config/dev-setup/local.sh" ] && . "$HOME/.config/dev-setup/local.sh"
$MARK_END
EOF
}

zsh_block() {
  cat <<'ZEOF'
# >>> dev-setup >>>
# Generado por ~/dev-setup. Edita el bloque o el script, no ambos.

# ── PATH ─────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.opencode/bin:$PATH"

# ── Historial ────────────────────────────────────────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=200000
HISTTIMEFORMAT='%F{yellow}[%T]%f '
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS HIST_SAVE_NO_DUPS HIST_VERIFY
setopt HIST_IGNORE_SPACE INTERACTIVE_COMMENTS

# ── Opciones de zsh ──────────────────────────────────────────────────────────
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS EXTENDED_GLOB NOCASEGLOB
setopt NO_BEEP LIST_AMBIGUOUS
unsetopt FLOW_CONTROL BEEP

# ── Colores de archivos (ls, eza, tree y listas de completado) ──────────────
if command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b "$HOME/.dircolors" 2>/dev/null || dircolors -b 2>/dev/null)"
fi

# ── Completado ───────────────────────────────────────────────────────────────
autoload -Uz compinit
[[ -d "$HOME/.local/share/zsh-plugins/zsh-completions/src" ]] && \
  fpath=("$HOME/.local/share/zsh-plugins/zsh-completions/src" $fpath)
mkdir -p "$XDG_CACHE_HOME/zsh" 2>/dev/null
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
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

# ── zsh-autosuggestions: sugiere el comando mientras escribes ────────────────
if [[ -r "$HOME/.local/share/zsh-plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  zstyle ':zsh-autosuggestions:*' suggestion-style 'fg=cyan italic'
  zstyle ':zsh-autosuggestions:*' max-exposure 30
  zstyle ':zsh-autosuggestions:*' fuzzy-match yes
  source "$HOME/.local/share/zsh-plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# ── fzf-tab: el menú de completado se dibuja con fzf ────────────────────────
if [[ -r "$HOME/.local/share/zsh-plugins/fzf-tab/fzf-tab.plugin.zsh" ]]; then
  zstyle ':fzf-tab:*' switch-group '<' '>'
  zstyle ':fzf-tab:*' fzf-flags --color=always --height=45% --layout=reverse \
    --border=rounded --info=inline --marker='❯' --prompt='▸ '
  zstyle ':fzf-tab:*' single-group color red
  zstyle ':fzf-tab:complete:(cd|z|cdpath|pushd):*' fzf-flags \
    --preview='echo $realpath 2>/dev/null | head -1'
  zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags \
    --preview='ps --pid=$word -o comm,args --no-headers'
  zstyle ':fzf-tab:*' use-color yes
  source "$HOME/.local/share/zsh-plugins/fzf-tab/fzf-tab.plugin.zsh"
fi

# ── fzf: Ctrl+T archivos · Ctrl+R historial · Alt+C directorios ─────────────
if command -v fzf >/dev/null 2>&1; then
  export FZF_DEFAULT_OPTS="--height=45% --layout=reverse --border=rounded --info=inline --marker='❯' --prompt='🔎 ' --color=fg:#c0caf5,bg:#1a1b26,hl:#7dcfff,fg+:#ffffff,bg+:#2a2b3c,hl+:#7dcfff,info:#9aa5ce,prompt:#7dcfff,pointer:#f7768e,spinner:#7dcfff,header:#565f89,border:#3b4261"
  export FZF_CTRL_T_OPTS="--toggle-sort --preview-window=right:60%:wrap --bind='ctrl-o:toggle-preview' --header='⇥ pulsa INTRO para ver'"
  export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window=down:3:wrap:hidden --bind='ctrl-r:toggle-preview' --header='⟲ historial · ctrl-o para ver'"
  export FZF_ALT_C_OPTS="--preview 'tree -C -a --level=2 $realpath 2>/dev/null | head -80' --header='⟲ directorios visitados'"
  source <(fzf --zsh)
fi

# ── zoxide: cd inteligente por historial de navegación ───────────────────────
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  # Rutas reales → cd normal; el resto → salto inteligente de zoxide
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
  alias cdr='zoxide remove'
fi

# ── Aliases ──────────────────────────────────────────────────────────────────
# Listar
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lah --icons --group-directories-first --git'
  alias la='eza -a --icons --group-directories-first'
  alias lt='eza --tree --level=2 --icons --group-directories-first'
  alias lta='eza --tree --level=3 --all --icons --group-directories-first'
else
  alias ls='ls --color=auto'
  alias ll='ls -alF --color=auto'
fi
# Ver archivos
if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never --style=plain'
  alias catp='bat --paging=never'
  alias catn='bat --paging=never --style=numbers'
fi
# Buscar
if command -v rg >/dev/null 2>&1; then
  alias grep='rg --color=auto'
  alias rgi='rg --color=auto --ignore-case'
  alias rgh='rg --color=auto --hidden --glob "!.git"'
fi
if command -v fd >/dev/null 2>&1; then
  alias find='fd'
  alias fdf='fd --type f'
  alias fdd='fd --type d'
fi
# Git
alias g='git'
alias gs='git status -sb'
alias gst='git status'
alias gd='git diff'
alias gds='git diff --staged'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit -v'
alias gco='git checkout'
alias gsw='git switch'
alias gb='git branch -vv'
alias gl='git log --oneline --graph --decorate -20'
alias glp='git log --pretty=format:"%C(auto)%h%d %s %C(green)(%cr) %C(bold blue)<%an>" --date=relative -25'
alias gll='git pull --rebase'
alias gp='git push'
alias gf='git fetch --all --prune'
alias gr='git remote -v'
alias grb='git rebase'
alias gsta='git stash'
alias gstp='git stash pop'
if command -v lazygit >/dev/null 2>&1; then
  alias lg='lazygit'
fi
# Navegación
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
# Utilidades
alias reload='source ~/.zshrc && echo "⟳ .zshrc recargado"'
alias zshcfg='nvim ~/.zshrc'
alias starcfg='nvim ~/.config/starship.toml'
alias ports='ss -tulpn'
alias myip='curl -s ifconfig.me && echo'
alias sysinfo='neofetch 2>/dev/null || fastfetch 2>/dev/null || clear'

# ── Atajos de teclado ────────────────────────────────────────────────────────
# Historial por prefijo (↑ / ↓)
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
# Ctrl+← / Ctrl+→ — moverse por palabras
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
# Home / End / Supr / Ctrl+Retroceso
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' kill-line
bindkey '^H' backward-kill-word
# Alt+. — último argumento del comando anterior
bindkey 'escape .' insert-last-argument
# Ctrl+X Ctrl+E — editar la línea actual en el editor
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line
# Mayús+Tab — completado sin fzf
bindkey '^[[Z' complete
# Ctrl+R — historial con fzf
if (( $+widgets[fzf-history-widget] )); then
  zle -N fzf-history-widget
  bindkey '^R' fzf-history-widget
fi

# ── Extensiones personales (este archivo NO lo gestiona dev-setup) ───────────
[[ -f "$HOME/.config/dev-setup/local.sh" ]] && . "$HOME/.config/dev-setup/local.sh"

# ── Editores y gestores de versiones ─────────────────────────────────────────
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

# ── direnv ───────────────────────────────────────────────────────────────────
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# ── Prompt ───────────────────────────────────────────────────────────────────
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# ── Syntax highlighting (SIEMPRE al final: no puede ir antes de los widgets) ─
if [[ -r "$HOME/.local/share/zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$HOME/.local/share/zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
fi
# <<< dev-setup <<<
ZEOF
}

zshenv_block() {
  cat <<'ZEOF'
# >>> dev-setup >>>
# Generado por ~/dev-setup. Edita el bloque o el script, no ambos.

export EDITOR="nvim"
export VISUAL="$EDITOR"
export PAGER="less"
export LESS='-R -F -X -M -i -N'
export LESSHISTFILE="$HOME/.lesshst"
export COLORTERM="truecolor"

export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.opencode/bin:$PATH"
# <<< dev-setup <<<
ZEOF
}

zprofile_block() {
  cat <<'ZEOF'
# >>> dev-setup >>>
# Generado por ~/dev-setup. Edita el bloque o el script, no ambos.

export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.opencode/bin:$PATH"

# Node.js con fnm (cambia de versión según el .node-version del proyecto)
if [ -x "$HOME/.local/share/fnm/fnm" ]; then
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# Python con uv
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# Cachés de zsh
mkdir -p "$XDG_CACHE_HOME/zsh" 2>/dev/null

# tmux
[ -d "$HOME/.config/tmux" ] && export TMUX_CONF_DIR="$HOME/.config/tmux"
# <<< dev-setup <<<
ZEOF
}

config_bash() {
  step "Configurando ~/.bashrc (bloque administrado)"
  backup_file "$HOME/.bashrc"
  upsert_block "$HOME/.bashrc" "$(shell_block bash)"
  ok ".bashrc actualizado (abre una terminal nueva o: source ~/.bashrc)"
}

config_zsh() {
  step "Configurando zsh (~/.zshenv, ~/.zprofile, ~/.zshrc)"
  backup_file "$HOME/.zshenv"
  backup_file "$HOME/.zprofile"
  backup_file "$HOME/.zshrc"
  upsert_block "$HOME/.zshenv" "$(zshenv_block)"
  upsert_block "$HOME/.zprofile" "$(zprofile_block)"
  upsert_block "$HOME/.zshrc" "$(zsh_block)"
  ok ".zshrc actualizado (abre una terminal nueva o: source ~/.zshrc)"
}

config_git() {
  step "Configurando git (sin tocar tu identidad)"
  backup_file "$HOME/.gitconfig"
  if have delta && ! git config --global --get core.pager >/dev/null; then
    git config --global core.pager delta
    git config --global interactive.diffFilter 'delta --color-only'
    git config --global delta.navigate true
    git config --global delta.line-numbers true
    git config --global delta.side-by-side false
  fi
  git config --global --get merge.conflictStyle >/dev/null || git config --global merge.conflictStyle zdiff3
  git config --global --get diff.colorMoved >/dev/null || git config --global diff.colorMoved zebra
  git config --global --get fetch.prune >/dev/null || git config --global fetch.prune true
  git config --global --get rerere.enabled >/dev/null || git config --global rerere.enabled true
  local alias_pair name cmd
  for alias_pair in "lg:log --graph --pretty=format:%C(auto)%h%d %s %C(green)(%cr) %C(bold blue)<%an>%Creset --abbrev-commit" \
                    "st:status" "co:checkout" "br:branch" "last:log -1 HEAD" \
                    "undo:reset --soft HEAD~1" "unstage:restore --staged"; do
    name=${alias_pair%%:*}; cmd=${alias_pair#*:}
    git config --global --get "alias.$name" >/dev/null || git config --global "alias.$name" "$cmd"
  done
  ok "git configurado"
}

config_dircolors() {
  step "Configurando ~/.dircolors (colores de archivos)"
  local file="$HOME/.dircolors"
  if [[ -f "$file" ]] && ! grep -qF "$MARK_BEGIN" "$file"; then
    warn "~/.dircolors ya existe y no lo gestiona dev-setup; no lo sobrescribo"
    return
  fi
  backup_file "$file"
  upsert_block "$file" "$(dircolors_block)"
  ok "~/.dircolors actualizado"
}

dircolors_block() {
  cat <<'ZEOF'
# >>> dev-setup >>>
# Generado por ~/dev-setup. Colores para ls, eza, tree y el completado de zsh.

DIR   01;38;5;39
LINK  01;38;5;45
ORPHAN 40;31;01
SOCK  01;38;5;170
FIFO  40;33;01
DOOR  01;38;5;170
BLK   40;33;01
CHR   40;33;01
EXEC  01;38;5;114
REG   00;38;5;252
MISSING 00;38;5;203

*.jpg  01;38;5;203
*.jpeg 01;38;5;203
*.png  01;38;5;203
*.gif  01;38;5;203
*.webp 01;38;5;203
*.bmp  01;38;5;203
*.svg  01;38;5;203
*.ico  01;38;5;203
*.mp4  01;38;5;140
*.mkv  01;38;5;140
*.mov  01;38;5;140
*.webm 01;38;5;140
*.mp3  01;38;5;141
*.flac 01;38;5;141
*.wav  01;38;5;141
*.ogg  01;38;5;141
*.tar  01;38;5;179
*.gz   01;38;5;179
*.bz2  01;38;5;179
*.xz   01;38;5;179
*.zip  01;38;5;179
*.7z   01;38;5;179
*.rar  01;38;5;179
*.iso  01;38;5;179
*.pdf  01;38;5;180
*.doc  01;38;5;180
*.docx 01;38;5;180
*.xls  01;38;5;180
*.xlsx 01;38;5;180
*.ppt  01;38;5;180
*.pptx 01;38;5;180
*.odt  01;38;5;180
*.ods  01;38;5;180
*.md   00;38;5;253
*.txt  00;38;5;252
*.log  00;38;5;244
*.json 00;38;5;186
*.yaml 00;38;5;186
*.yml  00;38;5;186
*.toml 00;38;5;186
*.lock 00;38;5;244
*.conf 00;38;5;252
*.ini  00;38;5;252
*.env  00;38;5;252
*.html 01;38;5;37
*.htm  01;38;5;37
*.css  01;38;5;37
*.js  01;38;5;37
*.ts  01;38;5;37
*.jsx  01;38;5;37
*.tsx 01;38;5;37
*.vue  01;38;5;37
*.svelte 01;38;5;37
*.py  01;38;5;221
*.pyc 01;38;5;244
*.ipynb 01;38;5;221
*.sh  01;38;5;115
*.bash 01;38;5;115
*.zsh 01;38;5;115
*.fish 01;38;5;115
*.rb  01;38;5;161
*.go  01;38;5;73
*.rs  01;38;5;209
*.java 01;38;5;214
*.kt  01;38;5;147
*.c  01;38;5;111
*.h  01;38;5;111
*.cpp 01;38;5;111
*.hpp 01;38;5;111
*.cs  01;38;5;81
*.php 01;38;5;176
*.swift 01;38;5;215
*.dart 01;38;5;215
*.lua 01;38;5;118
*.ex  01;38;5;130
*.exs 01;38;5;130
*.sql 01;38;5;204
*.db  01;38;5;204
*.sqlite 01;38;5;204
*.bak  00;38;5;244
*.tmp  00;38;5;244
*.swp  00;38;5;244
# <<< dev-setup <<<
ZEOF
}

config_tmux() {
  step "Configurando tmux"
  local file="$HOME/.tmux.conf"
  if [[ -f "$file" ]] && ! grep -qF "$MARK_BEGIN" "$file"; then
    warn "~/.tmux.conf ya existe y no lo gestiona dev-setup; no lo sobrescribo"
    return
  fi
  backup_file "$file"
  upsert_block "$file" "$(tmux_block)"
  ok "~/.tmux.conf actualizado"
}

tmux_block() {
  cat <<'ZEOF'
# >>> dev-setup >>>
# tmux — configuración de dev-setup
set -g mouse on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -sg escape-time 10
set -g focus-events on
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
setw -g mode-keys vi
set -g status-interval 5
set -g status-left-length 40
set -g status-right-length 60
set -g status-left "#[fg=colour39]#[bold] tmux #[default]"
set -g status-right "#[fg=colour244]%H:%M "

# Split con | y -
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %
# Prefijo Ctrl+b
unbind C-b
set -g prefix C-a
# Recargar configuración
bind r source-file ~/.tmux.conf \; display "Config recargada"
# Copiar en modo vi
bind -T copy-mode-vi v send -X "begin-selection"
bind -T copy-mode-vi y send -X "copy-selection-and-cancel"
# Scroll con Shift+PageUp/Down
bind -n S-PageUp send -X scroll-up 5
bind -n S-PageDown send -X scroll-down 5
# <<< dev-setup <<<
ZEOF
}

config_starship() {
  step "Configurando starship"
  mkdir -p "$HOME/.config"
  local file="$HOME/.config/starship.toml"
  if [[ -f "$file" ]] && ! grep -qF "$MARK_BEGIN" "$file"; then
    warn "~/.config/starship.toml ya existe y no lo gestiona dev-setup; no lo sobrescribo"
    return
  fi
  backup_file "$file"
  upsert_block "$file" "$(starship_block)"
  ok "~/.config/starship.toml actualizado"
}

starship_block() {
  cat <<'ZEOF'
# >>> dev-setup >>>
# Prompt de starship — Tokyo Night, colorido e informativo.
add_newline = true
command_timeout = 2000
format = """
$os\
$username\
$hostname\
$directory\
$git_branch\
$git_commit\
$git_status\
$python\
$nodejs\
$bun\
$golang\
$rust\
$java\
$kotlin\
$ruby\
$php\
$dotnet\
$swift\
$elixir\
$docker_context\
$container\
$aws\
$gcloud\
$direnv\
${custom.ai}\
$cmd_duration\
$status\
$jobs\
$shlvl\
$battery\
$memory_usage\
$time\
$character"""

[os]
style = "bold #7aa2f7"
format = "[ $os ]"

[username]
show_always = false
style_user = "bold #9ece6a"
style_root = "bold #f7768e"
format = " [$user]($style)"

[hostname]
ssh_only = false
style = "bold #2ac3de"
format = "[$hostname]($style) "
ssh_symbol = "🌐 "

[directory]
style = "bold #7dcfff"
truncation_length = 3
truncate_to_repo = true
truncation_symbol = "…/"
format = "[$path]($style) "

[git_branch]
symbol = " "
style = "bold #9ece6a"
format = "on [$symbol$branch]($style) "

[git_commit]
style = "bold #565f89"
format = "([$hash]($style))"
only_detached = false
tag_symbol = "  "

[git_status]
style = "#e0af68"
format = "([$all_status$ahead_behind]($style) )"
stashed = "≡"
untracked = "??"

[python]
symbol = " "
style = "bold #e0af68"
format = "via [$symbol py $version]($style) "

[nodejs]
symbol = " "
style = "bold #9ece6a"
format = "via [$symbol node.js $version]($style) "

[bun]
symbol = " "
style = "bold #e0af68"
format = "via [$symbol bun $version]($style) "

[golang]
symbol = " "
style = "bold #2ac3de"
format = "via [$symbol go $version]($style) "

[rust]
symbol = " "
style = "bold #ff9e64"
format = "via [$symbol rs $version]($style) "

[java]
symbol = " "
style = "bold #f7768e"
format = "via [$symbol java $version]($style) "

[kotlin]
symbol = " "
style = "bold #bb9af7"
format = "via [$symbol kt $version]($style) "

[ruby]
symbol = " "
style = "bold #f7768e"
format = "via [$symbol rb $version]($style) "

[php]
symbol = " "
style = "bold #bb9af7"
format = "via [$symbol php $version]($style) "

[dotnet]
symbol = " "
style = "bold #2ac3de"
format = "via [$symbol dotnet $version]($style) "

[swift]
symbol = " "
style = "bold #ff9e64"
format = "via [$symbol swift $version]($style) "

[elixir]
symbol = " "
style = "bold #bb9af7"
format = "via [$symbol ex $version]($style) "

[docker_context]
symbol = " "
style = "bold #2ac3de"
format = "via [$symbol ctx.$context]($style) "

[container]
symbol = " "
style = "bold #2ac3de"

[aws]
symbol = " "
style = "bold #ff9e64"
format = "via [$symbol aws.$profile]($style) "

[gcloud]
symbol = " "
style = "bold #ff9e64"
format = "via [$symbol gcloud.$project]($style) "

[direnv]
disabled = false
style = "bold #9ece6a"
format = "[$direnv]($style) "

[custom.ai]
command = "echo ${OPENCODE:+opencode}"
when = "test -n \"$OPENCODE\""
ignore_timeout = true
style = "bold #2ac3de"
format = "[$output]($style) "

[cmd_duration]
min_time = 2000
style = "bold #565f89"
format = "[took $duration]($style) "

[status]
disabled = false
style = "bold #f7768e"
format = "[$status]($style)"

[jobs]
symbol = " "
style = "bold #e0af68"
format = "[$symbol$number_of_jobs]($style) "

[shlvl]
style = "bold #565f89"
format = "[$shlvl]($style) "

[battery]
full_symbol = " "
charging_symbol = " "
discharging_symbol = " "
format = "[$symbol$percentage]($style) "

[[battery.display]]
threshold = 30
style = "bold yellow"

[memory_usage]
disabled = false
threshold = 75
style = "bold #9ece6a"
format = "[$symbol$memory_usage]($style) "

[time]
disabled = false
time_format = "%H:%M"
style = "bold #565f89"
format = "([$time]($style) )"

[character]
success_symbol = "[❯](bold #9ece6a)"
error_symbol = "[❯](bold #f7768e)"
vicmd_symbol = "[❯](bold #e0af68)"
# <<< dev-setup <<<
ZEOF
}

config_terminal_font() {
  command -v gsettings >/dev/null 2>&1 || return 0
  # Solo gnome-terminal; en otras terminales se elige a mano
  local profile schema font="MesloLGS Nerd Font 12"
  profile="$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'\"" | awk '{print $NF}')"
  [[ -n "$profile" ]] || return 0
  schema="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$profile/"
  gsettings set "$schema" use-system-font false 2>/dev/null || return 0
  gsettings set "$schema" font "$font" 2>/dev/null || true
  gsettings set "$schema" bold-is-bright true 2>/dev/null || true
  ok "gnome-terminal: fuente $font (para los iconos del prompt)"
}

layer_config() {
  step "Capa configuración: shell, git, tmux, starship"
  if ((DRY)); then
    printf '  %s[dry-run]%s escribir bloques en ~/.bashrc, ~/.zshenv, ~/.zprofile, ~/.zshrc, ~/.gitconfig, ~/.tmux.conf, ~/.dircolors y ~/.config/starship.toml\n' "$C_DIM" "$C_OFF"
    return 0
  fi
  config_bash
  config_zsh
  config_git
  config_dircolors
  config_tmux
  config_starship
  config_terminal_font
}

layer_nvim() {
  step "Capa Neovim: LazyVim"
  if ((DRY)); then
    printf '  %s[dry-run]%s clonar LazyVim en ~/.config/nvim (si no existe)\n' "$C_DIM" "$C_OFF"
    return 0
  fi
  if [[ -e "$HOME/.config/nvim" ]]; then
    warn "~/.config/nvim ya existe; no instalo LazyVim encima"
    return
  fi
  run git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
  run rm -rf "$HOME/.config/nvim/.git"
  ok "LazyVim instalado (abre nvim para completar)"
}

# ---------------------------------------------------------------------------
# Estado final
# ---------------------------------------------------------------------------
status() {
  step "Estado"
  local c
  for c in node pnpm bun uv ruff gh starship zoxide yq lazygit just delta nvim tmux zsh docker code java mvn mysql mongod redis-cli sqlite3 eza bat fd rg fzf; do
    printf '  %-10s ' "$c"
    if have "$c"; then
      printf '%s%s%s\n' "$C_OK" "$(command -v "$c")" "$C_OFF"
    else
      printf '%s—%s\n' "$C_DIM" "$C_OFF"
    fi
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
  die "No ejecutes este script como root; usa tu usuario y sudo cuando haga falta."
fi

STEP=0
for flag in "$L_APT" "$L_USER" "$L_CONFIG" "$L_JAVA" "$L_DOCKER" "$L_VSCODE" "$L_DB" "$L_NVIM"; do
  if ((flag)); then STEP=1; fi
done
if ((STEP == 0)); then die "No elegiste ninguna capa. Usa --help."; fi

if ((L_APT || L_JAVA || L_DOCKER || L_VSCODE || L_DB || CHSH)); then
  init_sudo
fi

if ((L_USER)); then layer_user; fi
if ((L_APT)); then layer_apt; fi
if ((L_JAVA)); then layer_java; fi
if ((L_DOCKER)); then layer_docker; fi
if ((L_VSCODE)); then layer_vscode; fi
if ((L_DB)); then layer_db; fi
if ((L_CONFIG)); then layer_config; fi
if ((L_NVIM)); then layer_nvim; fi

if ((CHSH)); then
  if have zsh; then
    if [[ "$SHELL" != "$(command -v zsh)" ]]; then
      run sudo chsh -s "$(command -v zsh)" "$USER"
      warn "Cierra sesión y vuelve a entrar para que zsh sea tu shell"
    fi
  else
    warn "zsh no está instalado; instala la capa --apt antes de --chsh"
  fi
fi

status
printf '\nLog: %s\n' "$LOG_FILE"
if ((L_APT || L_JAVA || L_DOCKER || L_VSCODE || L_DB)); then
  printf 'Recarga tu shell: source ~/.bashrc   (o abre una terminal nueva)\n'
fi
