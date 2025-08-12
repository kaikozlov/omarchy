# Compression
function compress
  if test (count $argv) -ne 1
    echo "Usage: compress <dir>"
    return 1
  end
  set -l name (string replace -r '/$' '' -- $argv[1])
  tar -czf "$name.tar.gz" "$name"
end

alias decompress='tar -xzf'

# Write iso file to sd card
function iso2sd
  if test (count $argv) -ne 2
    echo "Usage: iso2sd <input_file> <output_device>"
    echo "Example: iso2sd ~/Downloads/ubuntu-25.04-desktop-amd64.iso /dev/sda"
    echo
    echo "Available SD cards:"
    lsblk -d -o NAME | grep -E '^sd[a-z]' | awk '{print "/dev/"$1}'
  else
    sudo dd bs=4M status=progress oflag=sync if="$argv[1]" of="$argv[2]"
    sudo eject $argv[2]
  end
end

# Format an entire drive for a single partition using ext4
function format-drive
  if test (count $argv) -ne 2
    echo "Usage: format-drive <device> <name>"
    echo "Example: format-drive /dev/sda 'My Stuff'"
    echo
    echo "Available drives:"
    lsblk -d -o NAME -n | awk '{print "/dev/"$1}'
    return 1
  end

  set -l device $argv[1]
  set -l label $argv[2]
  echo "WARNING: This will completely erase all data on $device and label it '$label'."
  read -l -P "Are you sure you want to continue? (y/N): " confirm
  if string match -rq '^[Yy]$' -- $confirm
    sudo wipefs -a "$device"
    sudo dd if=/dev/zero of="$device" bs=1M count=100 status=progress
    sudo parted -s "$device" mklabel gpt
    sudo parted -s "$device" mkpart primary ext4 1MiB 100%
    if string match -q '*nvme*' -- "$device"
      set -l partition "$device"p1
    else
      set -l partition "$device"1
    end
    sudo mkfs.ext4 -L "$label" "$partition"
    echo "Drive $device formatted and labeled '$label'."
  end
end

# Transcode a video to a good-balance 1080p that's great for sharing online
function transcode-video-1080p
  if test (count $argv) -lt 1
    echo "Usage: transcode-video-1080p <input_file>"
    return 1
  end
  set -l base (string replace -r '\\.[^.]+$' '' -- $argv[1])
  ffmpeg -i $argv[1] -vf scale=1920:1080 -c:v libx264 -preset fast -crf 23 -c:a copy "$base-1080p.mp4"
end

# Transcode a video to a good-balance 4K that's great for sharing online
function transcode-video-4K
  if test (count $argv) -lt 1
    echo "Usage: transcode-video-4K <input_file>"
    return 1
  end
  set -l base (string replace -r '\\.[^.]+$' '' -- $argv[1])
  ffmpeg -i $argv[1] -c:v libx265 -preset slow -crf 24 -c:a aac -b:a 192k "$base-optimized.mp4"
end

# Transcode PNG to JPG image that's great for shrinking wallpapers
function transcode-png2jpg
  if test (count $argv) -lt 1
    echo "Usage: transcode-png2jpg <input_file>"
    return 1
  end
  set -l base (string replace -r '\\.[^.]+$' '' -- $argv[1])
  magick $argv[1] -quality 95 -strip "$base.jpg"
end

# Open files/URLs using the OS default app
function open
  xdg-open $argv >/dev/null 2>&1 &
end

# Directory navigation with zoxide fallback
function zd
  if test (count $argv) -eq 0
    builtin cd ~; and return
  else if test -d "$argv[1]"
    builtin cd "$argv[1]"
  else
    if functions -q z
      z $argv; and pwd; or echo "Error: Directory not found"
    else
      echo "Error: zoxide not initialized and directory not found"
    end
  end
end


