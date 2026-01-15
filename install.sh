#!/bin/bash

# --- 0. Setup & Safety ---
set -e # Exit immediately on error
set -u # Treat unset variables as error

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/dotfiles_backups/$(date +%Y%m%d_%H%M%S)"

# --- 0.5 Sudo Keep-Alive ---
echo "🔑 Requesting sudo access upfront..."
sudo -v

# Keep sudo alive in the background
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

# --- 1. Helper Functions ---

# Function to handle backups
# Moves the file/folder to a centralized backup directory
backup_item() {
  local target=$1

  # Only backup if it exists and is NOT a symlink
  # (We don't care about backing up old symlinks)
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "📦 Backing up $(basename "$target") to $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    mv "$target" "$BACKUP_DIR/"
  elif [ -L "$target" ]; then
    # If it's a symlink, just remove it so we can replace it
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

  # Run backup logic
  backup_item "$dest"

  echo "🔗 Linking $src -> $dest"
  ln -s "$src" "$dest"
}

link_file() {
  local src=$1
  local dest=$2

  # Run backup logic
  backup_item "$dest"

  echo "🔗 Linking $src -> $dest"
  ln -sf "$src" "$dest"
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

elif [ "$machine" == "linux" ]; then
  if [ -f /etc/fedora-release ]; then
    echo "🐧 Starting Fedora setup..."
    sudo dnf update -y

    if [ -f "$DOTFILES_DIR/linux/packages.txt" ]; then
      grep -vE '^\s*#|^\s*$' "$DOTFILES_DIR/linux/packages.txt" | xargs sudo dnf install -y
    fi

    echo "Installing Ghostty..."
    sudo dnf copr enable -y scottames/ghostty
    sudo dnf install -y ghostty
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

CONFIG_SRC="$DOTFILES_DIR/configs"
CONFIG_DEST="$HOME/.config"

link_dir "$CONFIG_SRC/nvim" "$CONFIG_DEST/nvim"
link_dir "$CONFIG_SRC/ghostty" "$CONFIG_DEST/ghostty"
link_dir "$CONFIG_SRC/kitty" "$CONFIG_DEST/kitty"

# --- 5. Tooling Setup ---

# Ensure Go is in path if we just installed it
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin

echo "🐹 Installing Go tools..."
if command -v go &>/dev/null; then
  go install github.com/pressly/goose/v3/cmd/goose@latest
  go install github.com/air-verse/air@latest
  go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
else
  echo "⚠️  Go not found. Skipping Go tools."
fi

echo "🐍 Installing UV (Python)..."
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "✅ Setup complete!"

# If we created a backup, tell the user where it is
if [ -d "$BACKUP_DIR" ]; then
  echo "ℹ️  Old configs backed up to: $BACKUP_DIR"
fi

# --- 6. Reload Shell ---
echo "🔄 Reloading shell..."
exec "$SHELL" -l
