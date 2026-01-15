#!/bin/bash

# Main configuration entry point

# 1. Set specific flags for debugging and safety
set -e # Exit immediatly if a command exits with a non-zero status
set -u # Treat unset variables as an error

# 2. Detect current OS
OS="$(uname -s)"
case "${OS}" in
Linux*) machine=linux ;;
Darwin*) machine=macos ;;
*) machine="UNKNOWN:${OS}" ;;
esac

echo "Detected platform: $machine"

# 3. Installation logic

if [ "$machine" == "macos" ]; then
  echo "Starting macOS setup..."
  # Verify homebrew Installation
  if ! command -v brew &>/dev/null; then
    echo "Installing homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  # Run Brewfile (installs all apps defined in macos/Brewfile)
  echo "Installing apps from Brewfile..."
  brew bundle --file=./macos/Brewfile

elif [ "$machine" == "linux" ]; then
  # Check for Fedora specifically
  if [ -f /etc/fedora-release ]; then
    echo "Starting Fedora setup..."
    sudo dnf update -y
    # Install packages from list, ignoring comments
    grep -vE '^#' "$PWD/linux/packages.txt" | xargs sudo dnf install -y
  else
    echo "Unsupported Linux distribution."
    exit 1
  fi
fi

# 4. Linking Dotfiles (Symlinking)
echo "Symlinking configurations..."
# Backup existing files is recommended here in a real scenario
ln -sf "$PWD/configs/zsh/.zshrc" "$HOME/.zshrc"
ln -sf "$PWD/configs/zsh/.bashrc" "$HOME/.bashrc"
ln -sf "$PWD/configs/git/.gitconfig" "$HOME/.gitconfig"

# Directories
CONFIGS="$PWD/configs"

link_dir "$CONFIGS/nvim" "$HOME/.config/nvim"
link_dir "$CONFIGS/ghostty" "$HOME/.config/ghostty"
link_dir "$CONFIGS/kitty" "$HOME/.config/kitty"

# 5. Go tooling
go install github.com/pressly/goose/v3/cmd/goose@latest
go install github.com/air-verse/air@latest
go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest

echo "Setup complete! Please restart your shell."
