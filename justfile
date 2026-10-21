set shell := ["bash", "-uc"]

default:
    @just --list

# Sistema + usuario + dotfiles + Java
install:
    ./install.sh --apt --user --config --java

# Todo, incluidas capas pesadas (Docker, VS Code, DB, LazyVim)
full:
    ./install.sh --all

# Solo binarios de ~/.local y configuración (sin sudo)
user:
    ./install.sh --user --config

# Solo la terminal: zsh, tmux y los plugins
shell:
    ./install.sh --apt --user --config

# Instala zsh y lo deja como shell de login (pide sudo)
chsh:
    ./install.sh --apt --chsh

# Lo pesado: Docker, VS Code y bases de datos
heavy:
    ./install.sh --docker --vscode --db

# Comprobar el entorno
verify:
    ./verify.sh

# Ver qué haría, sin tocar nada
dry-run:
    ./install.sh --dry-run --all

# Editar la configuración de zsh
edit:
    nvim ~/.zshrc

# Editar el prompt
prompt:
    nvim ~/.config/starship.toml

# Editar este proyecto
edit-self:
    nvim install.sh

# Recargar la shell en la terminal actual
reload:
    @source ~/.zshrc && echo "⟳ .zshrc recargado"
