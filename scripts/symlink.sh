link_dir() {
  local src=$1
  local dest=$2

  # Verify source exists in your dotfiles
  if [ ! -d "$src" ]; then
    echo "WARNING: Source '$src' does not exist. Skipping..."
    return
  fi

  # Create the parent directory for the destination if it doesn't exist
  mkdir -p "$(dirname "$dest")"

  # 1. Handle existing destination
  if [ -d "$dest" ] && [ ! -L "$dest" ]; then
    # It's a real directory (not a symlink), so back it up
    local backup="${dest}.backup.$(date +%s)"
    echo "Backing up existing directory: $dest -> $backup"
    mv "$dest" "$backup"
  elif [ -L "$dest" ]; then
    # It's already a symlink, safe to remove so we can update it
    rm "$dest"
  fi

  # 2. Create the Symlink
  ln -s "$src" "$dest"
  echo "Symlinked directory: $src -> $dest"
}
