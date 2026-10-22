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

# Instala OmniRoute (gateway local de LLMs) y lo integra en OpenCode
omniroute:
    ./install.sh --omniroute

# Fija el modelo por defecto (por defecto: auto) y refresca el bloque
omniroute-default model="auto":
    ./scripts/opencode-providers.py --set-default "{{model}}"

# Crea un combo de enrutamiento (nombre y lista de modelos)
omniroute-combo name models:
    omniroute combo create {{name}} --strategy priority --models "{{models}}"

# Estado y registro del gateway
omniroute-status:
    @systemctl --user status omniroute --no-pager || true

omniroute-logs:
    @journalctl --user -u omniroute -f

# Modelos disponibles a través del gateway
omniroute-models:
    @curl -s -H "Authorization: Bearer $(cat ~/.secrets/omniroute-key)" \
        http://127.0.0.1:20128/v1/models | jq -r '.data[].id' | sort

# Añade proveedores gratuitos desde ~/.secrets/omniroute-free.env y crea el combo free
omniroute-free:
    ./scripts/omniroute-free.py

# Qué proveedores gratuitos soporta y dónde sacar cada clave
omniroute-free-list:
    ./scripts/omniroute-free.py --list

# Chromium para el proveedor sin clave de Cloudflare Playground (~400 MB)
omniroute-browser:
    node ~/.local/share/omniroute/lib/node_modules/omniroute/node_modules/playwright/cli.js install chromium

# Abrir el panel de OmniRoute
omniroute-ui:
    @xdg-open http://127.0.0.1:20128/dashboard

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
