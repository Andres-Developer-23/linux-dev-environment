#!/usr/bin/env bash
# Verificación del entorno dev-setup. No requiere sudo.
set -uo pipefail
export LC_ALL=C
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.opencode/bin:$PATH"

if [[ -t 1 ]]; then
  G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; D=$'\e[2m'; N=$'\e[0m'
else
  G="" Y="" R="" D="" N=""
fi

okc=0 failc=0
ok()      { printf '  %s✓%s %s\n' "$G" "$N" "$*"; okc=$((okc+1)); }
bad()     { printf '  %s✗%s %s\n' "$R" "$N" "$*"; failc=$((failc+1)); }
warn()    { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
section() { printf '\n%s%s%s\n' "$D" "$*" "$N"; }

cmd() { # nombre [args...]
  local name=$1; shift
  if command -v "$name" >/dev/null 2>&1; then
    if (($#)); then
      ok "$name: $("$name" "$@" 2>&1 | sed -n '1p')"
    else
      ok "$name: $(command -v "$name")"
    fi
  else
    bad "$name no encontrado"
  fi
}

opt() { # herramienta opcional
  local name=$1; shift
  if command -v "$name" >/dev/null 2>&1; then
    if (($#)); then
      ok "$name: $("$name" "$@" 2>&1 | sed -n '1p')"
    else
      ok "$name: $(command -v "$name")"
    fi
  else
    warn "$name no instalado (capa opcional)"
  fi
}

section "Binarios base"
cmd git --version
cmd node --version
cmd npm --version
cmd pnpm --version
cmd uv --version
cmd gh --version
cmd python3 --version

section "CLI moderna"
cmd starship --version
cmd zoxide --version
cmd yq --version
cmd lazygit --version
cmd just --version
cmd delta --version
cmd nvim --version
cmd bat --version
cmd fd --version
cmd rg --version
cmd fzf --version

section "Sistema"
cmd zsh --version
cmd tmux -V
opt code --version
opt java -version
opt mvn -version
opt docker --version
opt docker compose version

section "Bases de datos (opcional)"
opt sqlite3 --version
opt psql --version
opt mysql --version
opt redis-cli --version
opt mongod --version

section "Fuente"
if fc-list 2>/dev/null | grep -i 'JetBrainsMono Nerd' >/dev/null; then
  ok "JetBrainsMono Nerd Font instalada"
else
  bad "JetBrainsMono Nerd Font ausente"
fi
if fc-list 2>/dev/null | grep -i 'Meslo.*Nerd' >/dev/null; then
  ok "Meslo Nerd Font instalada (iconos del prompt)"
else
  warn "Meslo Nerd Font ausente (recomendada para starship)"
fi

section "zsh"
if command -v zsh >/dev/null 2>&1; then
  for p in zsh-autosuggestions zsh-syntax-highlighting zsh-completions fzf-tab; do
    if [[ -d "$HOME/.local/share/zsh-plugins/$p" ]]; then
      ok "plugin $p"
    else
      bad "plugin $p ausente"
    fi
  done
  if zsh -n "$HOME/.zshrc" 2>/dev/null; then
    ok "~/.zshrc sin errores de sintaxis"
  else
    bad "~/.zshrc tiene errores de sintaxis"
  fi
  if zsh -n "$HOME/.zshenv" 2>/dev/null && zsh -n "$HOME/.zprofile" 2>/dev/null; then
    ok "~/.zshenv y ~/.zprofile sin errores de sintaxis"
  else
    bad "~/.zshenv o ~/.zprofile tienen errores de sintaxis"
  fi
  if command -v starship >/dev/null 2>&1 && starship print-config >/dev/null 2>"$HOME/.cache/starship-verify.log"; then
    ok "starship.toml válido"
  else
    bad "starship.toml con errores: $(head -3 "$HOME/.cache/starship-verify.log" 2>/dev/null | tr '\n' ' ')"
  fi
else
  warn "zsh no instalado; ejecuta: ./install.sh --apt"
fi

section "Dotfiles"
if grep -qF '# >>> dev-setup >>>' "$HOME/.bashrc" 2>/dev/null; then
  ok "bloque dev-setup en ~/.bashrc"
else
  bad "bloque dev-setup ausente en ~/.bashrc"
fi
if grep -qF '# >>> dev-setup >>>' "$HOME/.zshrc" 2>/dev/null; then
  ok "bloque dev-setup en ~/.zshrc"
else
  bad "bloque dev-setup ausente en ~/.zshrc"
fi
[[ -f "$HOME/.zshenv" ]] && ok "~/.zshenv presente" || warn "sin ~/.zshenv"
[[ -f "$HOME/.zprofile" ]] && ok "~/.zprofile presente" || warn "sin ~/.zprofile"
[[ -f "$HOME/.gitconfig" ]] && ok "~/.gitconfig presente" || warn "sin ~/.gitconfig"
[[ -f "$HOME/.tmux.conf" ]] && ok "~/.tmux.conf presente" || warn "sin ~/.tmux.conf"
[[ -f "$HOME/.dircolors" ]] && ok "~/.dircolors presente" || warn "sin ~/.dircolors"
[[ -f "$HOME/.config/starship.toml" ]] && ok "~/.config/starship.toml presente" || warn "sin starship.toml"

section "Entorno"
if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
  ok "usuario en grupo docker"
else
  warn "usuario fuera del grupo docker (opcional)"
fi
printf '  shell actual: %s\n' "$SHELL"
printf '  shell de login: %s\n' "$(getent passwd "$USER" | cut -d: -f7)"

printf '\nResumen: %sOK%s, %sfallos%s\n' "$G$okc" "$N" "$R$failc" "$N"
((failc == 0))
