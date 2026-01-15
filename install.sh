#!/bin/bash

# --- 0. Setup & Safety ---
set -e # Exit immediately on error
set -u # Treat unset variables as error

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/dotfiles_backups/$(date +%Y%m%d_%H%M%S)"

# --- 0.5 Sudo Keep-Alive ---
# Ask for sudo upfront so the script doesn't pause later
echo "🔑 Requesting sudo access upfront..."
sudo -v

# Keep sudo alive in background
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

# --- 1. Helper Functions ---

backup_item() {
  local target=$1
  # Backup only if it exists and is NOT a symlink
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "📦 Backing up $(basename "$target") to $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    mv "$target" "$BACKUP_DIR/"
  elif [ -L "$target" ]; then
    # If it's a symlink, just remove it to update
    rm "$target"
  fi
}

link_dir() {
  local src=$1
  local dest=$2
  if [ ! -d "$src" ]; then
    echo "⚠️  Source folder missing: $src"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  backup_item "$dest"
  echo "🔗 Linking $src -> $dest"
  ln -s "$src" "$dest"
}

link_file() {
  local src=$1
  local dest=$2
  if [ ! -f "$src" ]; then
    echo "⚠️  Source file missing: $src"
    return
  fi
  backup_item "$dest"
  echo "🔗 Linking $src -> $dest"
  ln -sf "$src" "$dest"
}

setup_macos_defaults() {
  echo "🍎 Tweaking macOS settings..."
  # Fast Key Repeat
  defaults write NSGlobalDomain KeyRepeat -int 2
  defaults write NSGlobalDomain InitialKeyRepeat -int 15
  # Finder Tweaks
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write com.apple.finder ShowPathbar -bool true
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  # Restart UI elements
  killall Finder 2>/dev/null || true
  killall Dock 2>/dev/null || true
}

configure_docker() {
  echo "🐳 Configuring Docker..."
  if [ "$machine" == "linux" ]; then
    if ! getent group docker >/dev/null; then
      sudo groupadd docker
    fi
    if ! groups "$USER" | grep -q "\bdocker\b"; then
      echo "   Adding $USER to docker group..."
      sudo usermod -aG docker "$USER"
    fi
    if command -v systemctl &>/dev/null; then
      echo "   Starting Docker service..."
      sudo systemctl enable docker --now
    fi
  elif [ "$machine" == "macos" ]; then
    if ! pgrep -x "Docker" >/dev/null; then
      echo "   ⚠️  Docker Desktop is not running. Start it manually."
    fi
  fi
}

# --- 2. OS Detection ---
OS="$(uname -s)"
case "${OS}" in
Linux*) machine=linux ;;
Darwin*) machine=macos ;;
*) machine="UNKNOWN:${OS}" ;;
esac
echo "🖥️  Detected platform: $machine"

# --- 3. Installation Logic ---

if [ "$machine" == "macos" ]; then
  echo "🍎 Starting macOS setup..."

  if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi

  echo "Installing apps from Brewfile..."
  brew bundle --file="$DOTFILES_DIR/macos/Brewfile" || true

  # Run macOS defaults
  setup_macos_defaults

elif [ "$machine" == "linux" ]; then
  if [ -f /etc/fedora-release ]; then
    echo "🐧 Starting Fedora setup..."
    sudo dnf update -y

    # Install basics (ensure unzip/curl are here for tools later)
    sudo dnf install -y unzip curl git zsh

    # Install packages from list
    if [ -f "$DOTFILES_DIR/linux/packages.txt" ]; then
      grep -vE '^\s*#|^\s*$' "$DOTFILES_DIR/linux/packages.txt" | xargs sudo dnf install -y
    fi

    echo "Installing Ghostty..."
    sudo dnf copr enable -y scottames/ghostty
    sudo dnf install -y ghostty

    echo "Installing GitHub CLI..."
    sudo dnf install dnf5-plugins
    sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
    sudo dnf install gh --repo gh-cli
  else
    echo "❌ Unsupported Linux distribution."
    exit 1
  fi
fi

# --- 4. Linking Dotfiles ---
echo "🔗 Symlinking configurations..."

link_file "$DOTFILES_DIR/configs/zsh/.zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/configs/zsh/.bashrc" "$HOME/.bashrc"
link_file "$DOTFILES_DIR/configs/git/.gitconfig" "$HOME/.gitconfig"

# Global Git Ignore
link_file "$DOTFILES_DIR/configs/git/.gitignore_global" "$HOME/.gitignore_global"
git config --global core.excludesfile "$HOME/.gitignore_global"

CONFIG_SRC="$DOTFILES_DIR/configs"
CONFIG_DEST="$HOME/.config"

link_dir "$CONFIG_SRC/nvim" "$CONFIG_DEST/nvim"
link_dir "$CONFIG_SRC/ghostty" "$CONFIG_DEST/ghostty"
link_dir "$CONFIG_SRC/kitty" "$CONFIG_DEST/kitty"

# --- 5. Tooling Setup ---

# Docker
configure_docker

# Starship Prompt
echo "🚀 Installing Starship prompt..."
if ! command -v starship &>/dev/null; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# LINK THE CONFIG FILE
# This puts your file at ~/.config/starship.toml
link_file "$DOTFILES_DIR/configs/starship/starship.toml" "$HOME/.config/starship.toml"

# Go Tools
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
echo "🐹 Installing Go tools..."
if command -v go &>/dev/null; then
  go install github.com/pressly/goose/v3/cmd/goose@latest
  go install github.com/air-verse/air@latest
  go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
else
  echo "⚠️  Go not found. Skipping Go tools."
fi

# Python (UV)
echo "🐍 Installing UV (Python)..."
curl -LsSf https://astral.sh/uv/install.sh | sh

# --- 6. Completion & Reload ---
echo "✅ Setup complete!"

if [ -d "$BACKUP_DIR" ]; then
  echo "ℹ️  Old configs backed up to: $BACKUP_DIR"
fi

echo "🔄 Reloading shell..."
exec "$SHELL" -l
