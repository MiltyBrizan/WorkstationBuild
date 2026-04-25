#!/bin/bash

# macOS Developer Setup Script
# Automates: https://medium.com/@dorangao/the-only-macos-developer-setup-guide-youll-ever-need-1879bf7a8960

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

step()    { echo -e "\n${BLUE}${BOLD}==> ${1}${NC}"; }
ok()      { echo -e "  ${GREEN}✓${NC} ${1}"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  ${1}"; }
fail()    { echo -e "  ${RED}✗${NC} ${1}"; }
header()  { echo -e "\n${BOLD}${1}${NC}"; }

# ── Preflight ────────────────────────────────────────────────────────────────
clear
header "macOS Developer Setup"
echo "────────────────────────────────────────────────"
echo "This script installs and configures a complete"
echo "professional developer environment on your Mac."
echo "────────────────────────────────────────────────"
echo ""

# Collect Git identity upfront — needed before any brew install (git config)
echo "Git configuration:"
read -rp "  Full name  : " GIT_NAME
read -rp "  Email      : " GIT_EMAIL
echo ""

# Optional components
header "Optional components (y to include, Enter to skip):"
read -rp "  iTerm2 (terminal)       [y/N] " OPT_ITERM2
read -rp "  Alfred (launcher)       [y/N] " OPT_ALFRED
read -rp "  Google Cloud CLI        [y/N] " OPT_GCLOUD
read -rp "  Cursor (AI code editor) [y/N] " OPT_CURSOR
read -rp "  ChatGPT Desktop         [y/N] " OPT_CHATGPT
read -rp "  Docker Desktop          [y/N] " OPT_DOCKER
read -rp "  GitHub CLI (gh)         [y/N] " OPT_GH
read -rp "  AWS CLI                 [y/N] " OPT_AWSCLI
read -rp "  Node.js dev tools       [y/N] " OPT_NODE_TOOLS
read -rp "  React.js tooling        [y/N] " OPT_REACT
read -rp "  pnpm                    [y/N] " OPT_PNPM
read -rp "  asdf (version manager)  [y/N] " OPT_ASDF
read -rp "  PostgreSQL              [y/N] " OPT_POSTGRES
read -rp "  Redis                   [y/N] " OPT_REDIS
echo ""

confirm() { [[ "${1:-n}" =~ ^[Yy]$ ]]; }

# ── Xcode Command Line Tools ─────────────────────────────────────────────────
step "Xcode Command Line Tools"
if xcode-select -p &>/dev/null; then
  ok "Already installed ($(xcode-select -p))"
else
  warn "Installing — a dialog will appear. Click Install and wait."
  xcode-select --install
  echo ""
  read -rp "  Press Enter once the Xcode CLT installation has finished..."
  ok "Xcode CLT ready"
fi

# ── Homebrew ─────────────────────────────────────────────────────────────────
step "Homebrew"
if command -v brew &>/dev/null; then
  ok "Already installed ($(brew --version | head -1))"
else
  warn "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Apple Silicon: add to PATH immediately so the rest of the script works
  if [[ "$(uname -m)" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    # Persist for future shells
    if ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
      ok "Added Homebrew to ~/.zprofile"
    fi
  fi
fi

step "Updating Homebrew"
brew update
brew upgrade
ok "Homebrew is up to date"

# ── Git ───────────────────────────────────────────────────────────────────────
step "Git"
if brew list git &>/dev/null 2>&1; then
  ok "Already installed ($(git --version))"
else
  brew install git
  ok "$(git --version)"
fi

git config --global user.name  "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
git config --global core.excludesfile "$HOME/.gitignore_global"
ok "Configured: $GIT_NAME <$GIT_EMAIL>"

# Global .gitignore — filters macOS/editor noise from every repo
cat > "$HOME/.gitignore_global" << 'GITIGNORE'
# macOS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
.AppleDouble
.LSOverride
Icon?

# Editors
.vscode/
.idea/
*.swp
*.swo
*~

# Node
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.npm

# Python
__pycache__/
*.py[cod]
*.pyo
.Python
*.egg-info/
dist/
build/
.venv/
venv/
ENV/

# Environment / secrets
.env
.env.local
.env.*.local

# Logs
*.log
logs/
GITIGNORE

ok "Global .gitignore created at ~/.gitignore_global"

# ── iTerm2 ───────────────────────────────────────────────────────────────────
if confirm "$OPT_ITERM2"; then
  step "iTerm2"
  if [[ -d "/Applications/iTerm.app" ]]; then
    ok "Already installed"
  else
    brew install --cask iterm2
    ok "iTerm2 installed — set as default terminal in iTerm2 > Make iTerm2 Default Term"
  fi
fi

# ── Alfred ────────────────────────────────────────────────────────────────────
if confirm "$OPT_ALFRED"; then
  step "Alfred"
  if [[ -d "/Applications/Alfred.app" ]] || [[ -d "/Applications/Alfred 5.app" ]]; then
    ok "Already installed"
  else
    brew install --cask alfred
    ok "Alfred installed — launch it and grant Accessibility permissions to activate"
  fi
fi

# ── VS Code ───────────────────────────────────────────────────────────────────
step "Visual Studio Code"
if [[ -d "/Applications/Visual Studio Code.app" ]]; then
  ok "Already installed"
else
  brew install --cask visual-studio-code
  ok "VS Code installed"
fi

# Wire up the 'code' shell command without requiring the GUI step
CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
if [[ -f "$CODE_BIN" ]] && ! command -v code &>/dev/null; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$CODE_BIN" "$HOME/.local/bin/code"
  # Add ~/.local/bin to PATH if not already there
  if ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
  fi
  ok "'code' command available (via ~/.local/bin)"
fi

# ── Node.js ───────────────────────────────────────────────────────────────────
step "Node.js"
if command -v node &>/dev/null; then
  ok "Already installed (Node $(node -v) / npm $(npm -v))"
else
  brew install node
  ok "Node $(node -v) / npm $(npm -v)"
fi

# ── Claude Code ───────────────────────────────────────────────────────────────
step "Claude Code"
if command -v claude &>/dev/null; then
  ok "Already installed ($(claude --version 2>/dev/null || echo 'run claude to verify'))"
else
  npm install -g @anthropic-ai/claude-code
  ok "Claude Code installed: $(claude --version 2>/dev/null || echo 'run claude to verify')"
fi

# ── Python 3 ─────────────────────────────────────────────────────────────────
step "Python 3"
if brew list python &>/dev/null 2>&1; then
  ok "Already installed ($(python3 --version))"
else
  brew install python
  ok "$(python3 --version)"
fi
warn "Use 'python3' and 'pip3' — never touch the system Python"

# ── GitHub CLI ───────────────────────────────────────────────────────────────
if confirm "$OPT_GH"; then
  step "GitHub CLI"
  if command -v gh &>/dev/null; then
    ok "Already installed (gh $(gh --version | head -1 | awk '{print $3}'))"
  else
    brew install gh
    ok "gh $(gh --version | head -1 | awk '{print $3}') installed — run 'gh auth login' to authenticate"
  fi
fi

# ── AWS CLI ──────────────────────────────────────────────────────────────────
if confirm "$OPT_AWSCLI"; then
  step "AWS CLI"
  if command -v aws &>/dev/null; then
    ok "Already installed ($(aws --version 2>&1 | awk '{print $1}'))"
  else
    brew install awscli
    ok "AWS CLI $(aws --version 2>&1 | awk '{print $1}') installed — run 'aws configure' to set credentials"
  fi
fi

# ── Node.js dev tools ─────────────────────────────────────────────────────────
if confirm "$OPT_NODE_TOOLS"; then
  step "Node.js dev tools (TypeScript, ESLint, Prettier)"
  if command -v tsc &>/dev/null; then
    ok "TypeScript already installed ($(tsc --version))"
  else
    npm install -g typescript ts-node
    ok "TypeScript $(tsc --version)"
  fi
  if command -v eslint &>/dev/null; then
    ok "ESLint already installed ($(eslint --version))"
  else
    npm install -g eslint
    ok "ESLint $(eslint --version)"
  fi
  if command -v prettier &>/dev/null; then
    ok "Prettier already installed ($(prettier --version))"
  else
    npm install -g prettier
    ok "Prettier $(prettier --version)"
  fi
fi

# ── React.js tooling ──────────────────────────────────────────────────────────
if confirm "$OPT_REACT"; then
  step "React.js tooling (Vite)"
  if command -v vite &>/dev/null; then
    ok "Already installed (Vite $(vite --version))"
  else
    npm install -g vite
    ok "Vite $(vite --version) installed — scaffold a new React project with: npm create vite@latest"
  fi
fi

# ── Google Cloud CLI ─────────────────────────────────────────────────────────
if confirm "$OPT_GCLOUD"; then
  step "Google Cloud CLI"
  if command -v gcloud &>/dev/null; then
    ok "Already installed ($(gcloud --version | head -1))"
  else
    brew install --cask google-cloud-sdk
    ok "gcloud installed — run 'gcloud init' to authenticate"
  fi
fi

# ── Cursor ────────────────────────────────────────────────────────────────────
if confirm "$OPT_CURSOR"; then
  step "Cursor"
  if [[ -d "/Applications/Cursor.app" ]]; then
    ok "Already installed"
  else
    brew install --cask cursor
    ok "Cursor installed — sign in to activate AI features"
  fi
fi

# ── ChatGPT Desktop ───────────────────────────────────────────────────────────
if confirm "$OPT_CHATGPT"; then
  step "ChatGPT Desktop"
  if [[ -d "/Applications/ChatGPT.app" ]]; then
    ok "Already installed"
  else
    brew install --cask chatgpt
    ok "ChatGPT Desktop installed (requires macOS 14 Sonoma + Apple Silicon)"
  fi
fi

# ── Docker Desktop ────────────────────────────────────────────────────────────
if confirm "$OPT_DOCKER"; then
  step "Docker Desktop"
  if [[ -d "/Applications/Docker.app" ]]; then
    ok "Already installed"
  else
    brew install --cask docker
    ok "Docker Desktop installed — launch it from Applications to finish setup"
  fi
fi

# ── Oh My Zsh ─────────────────────────────────────────────────────────────────
step "Oh My Zsh"
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  ok "Already installed"
else
  # RUNZSH=no   — don't switch shells mid-script
  # CHSH=no     — don't try to chsh (zsh is already default on modern macOS)
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ok "Oh My Zsh installed"
fi

# ── Yarn ─────────────────────────────────────────────────────────────────────
step "Yarn"
if command -v yarn &>/dev/null; then
  ok "Already installed (Yarn $(yarn --version))"
else
  brew install yarn
  ok "Yarn $(yarn --version)"
fi

# ── pnpm ─────────────────────────────────────────────────────────────────────
if confirm "$OPT_PNPM"; then
  step "pnpm"
  if command -v pnpm &>/dev/null; then
    ok "Already installed (pnpm $(pnpm --version))"
  else
    brew install pnpm
    ok "pnpm $(pnpm --version)"
  fi
fi

# ── asdf ─────────────────────────────────────────────────────────────────────
if confirm "$OPT_ASDF"; then
  step "asdf (universal version manager)"
  if command -v asdf &>/dev/null; then
    ok "Already installed ($(asdf --version))"
  else
    brew install asdf
    ASDF_INIT='. "$(brew --prefix asdf)/libexec/asdf.sh"'
    if ! grep -qF 'asdf.sh' "$HOME/.zshrc" 2>/dev/null; then
      echo "$ASDF_INIT" >> "$HOME/.zshrc"
    fi
    ok "asdf installed — add plugins with: asdf plugin add <name>"
  fi
fi

# ── Databases ─────────────────────────────────────────────────────────────────
if confirm "$OPT_POSTGRES"; then
  step "PostgreSQL"
  if brew list postgresql@16 &>/dev/null 2>&1; then
    ok "Already installed"
  else
    brew install postgresql@16
    brew services start postgresql@16
    ok "PostgreSQL 16 installed and started"
  fi
fi

if confirm "$OPT_REDIS"; then
  step "Redis"
  if brew list redis &>/dev/null 2>&1; then
    ok "Already installed"
  else
    brew install redis
    brew services start redis
    ok "Redis installed and started"
  fi
fi

# ── Cleanup ───────────────────────────────────────────────────────────────────
step "Homebrew cleanup"
brew cleanup
ok "Old versions removed"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────"
echo -e "${GREEN}${BOLD}Setup complete!${NC}"
echo "────────────────────────────────────────────────"
echo ""
echo "What was installed:"
echo "  • Xcode Command Line Tools"
echo "  • Homebrew"
echo "  • Git $(git --version | awk '{print $3}')"
echo "  • VS Code  (shell command: code .)"
echo "  • Node $(node -v) / npm $(npm -v)"
echo "  • Claude Code"
echo "  • $(python3 --version)"
echo "  • Oh My Zsh"
echo "  • Yarn $(yarn --version)"
confirm "$OPT_ITERM2"      && echo "  • iTerm2"
confirm "$OPT_ALFRED"      && echo "  • Alfred"
confirm "$OPT_GH"          && echo "  • GitHub CLI $(gh --version 2>/dev/null | head -1 | awk '{print $3}')"
confirm "$OPT_AWSCLI"      && echo "  • AWS CLI $(aws --version 2>&1 | awk '{print $1}')"
confirm "$OPT_NODE_TOOLS"  && echo "  • TypeScript $(tsc --version 2>/dev/null || echo ''), ESLint, Prettier"
confirm "$OPT_REACT"       && echo "  • Vite $(vite --version 2>/dev/null || echo '')"
confirm "$OPT_GCLOUD"      && echo "  • Google Cloud CLI"
confirm "$OPT_CURSOR"      && echo "  • Cursor"
confirm "$OPT_CHATGPT"     && echo "  • ChatGPT Desktop"
confirm "$OPT_DOCKER"      && echo "  • Docker Desktop"
confirm "$OPT_PNPM"        && echo "  • pnpm $(pnpm --version 2>/dev/null || echo '')"
confirm "$OPT_ASDF"        && echo "  • asdf"
confirm "$OPT_POSTGRES"    && echo "  • PostgreSQL 16"
confirm "$OPT_REDIS"       && echo "  • Redis"
echo ""
echo "Next steps:"
echo "  1. Restart Terminal (or: source ~/.zshrc)"
confirm "$OPT_GH"      && echo "  2. Run: gh auth login"
confirm "$OPT_AWSCLI"  && echo "  3. Run: aws configure  (set Access Key, Secret, region, output)"
confirm "$OPT_GCLOUD"  && echo "  3. Run: gcloud init"
confirm "$OPT_REACT"   && echo "  4. Scaffold a React app: npm create vite@latest"
confirm "$OPT_DOCKER"  && echo "  5. Launch Docker Desktop from Applications"
echo "  6. Set up a dotfiles repo on GitHub to preserve this config"
echo ""