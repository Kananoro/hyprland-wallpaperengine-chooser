#!/usr/bin/env bash

#Fix some errors with nvidia (if you use AMD please leave empty "")
NVIDIA_ENV="__GL_THREADED_OPTIMIZATIONS=0"
# Wallpaper Engine Folder
STEAM_DIR="$HOME/.local/share/Steam/steamapps/workshop/content/431960"
# Hyprland conf folder
WALLPAPERCONF="$HOME/.config/hypr/wallpaperengine.conf"

# Default flags and options
DEFAULT_FLAGS=("--disable-mouse" "--scaling fill")
OPTIONS=("--disable-mouse" "--disable-parallax" "--no-fullscreen-pause" "--silent" "--noautomute")
SCALING_OPTIONS=(stretch fit fill default)

# Delete base folder from choices
BASE_ID=$(basename "$STEAM_DIR")

# Choose monitor
MON=$(hyprctl monitors | awk '/Monitor/ && /DP/ {print $2}' | wofi --dmenu -p "Monitor")
[[ -z "$MON" ]] && exit 0

# Gather wallpapers with preview and title
items=()
while read -r id; do
  [[ "$id" == "$BASE_ID" ]] && continue
  preview_file=""
  title_file="$STEAM_DIR/$id/project.json"
  title=""
  if [[ -f "$title_file" ]]; then
    title=$(grep -Po '"title"\s*:\s*"\K[^"]+' "$title_file")
  fi
  for ext in png jpg gif; do
    [[ -f "$STEAM_DIR/$id/preview.$ext" ]] && { preview_file="$STEAM_DIR/$id/preview.$ext"; break; }
  done
  if [[ -n "$title" ]]; then
    display="$id ($title)"
  else
    display="$id"
  fi
  if [[ -n "$preview_file" ]]; then
    items+=("img:$preview_file:text:$display")
  else
    items+=("$display")
  fi
done < <(find "$STEAM_DIR" -maxdepth 1 -type d -printf '%f\n')

# Choose wallpaper
CHOICE=$(printf '%s\n' "${items[@]}" | wofi --dmenu --allow-images -p "Wallpaper ID")
[[ -z "$CHOICE" ]] && exit 0
if [[ "$CHOICE" == img:* ]]; then
  text=${CHOICE##*:text:}
else
  text=$CHOICE
fi
ID=${text%%[\ \(\)]*}

#Check if  config file exists
mkdir -p "$(dirname "$WALLPAPERCONF")"
touch "$WALLPAPERCONF"

# Change previous launch parameters?
CHANGE=$(printf 'No\nYes' | wofi --dmenu -p "Change previous launch parameters?")

# Parse existing flags for this monitor
current_line=$(grep -m1 "^exec-once = .*linux-wallpaperengine --screen-root $MON" "$WALLPAPERCONF")
current_flags=()
current_scaling=""
if [[ -n "$current_line" ]]; then
  flags_part=${current_line#*--fps 30}
  flags_part=${flags_part%&}
  read -r -a parts <<< "$flags_part"
  for f in "${parts[@]}"; do
    for opt in "${OPTIONS[@]}"; do
      [[ "$f" == "$opt" ]] && current_flags+=("$opt")
    done
    [[ " ${SCALING_OPTIONS[*]} " =~ " $f " ]] && current_scaling=$f
  done
fi

# Choose flags
FLAGS=()
SCALING="$current_scaling"
if [[ "$CHANGE" == "Yes" ]]; then
  for flag in "${OPTIONS[@]}"; do
    if printf '%s\n' "${current_flags[@]}" | grep -qx "$flag"; then
      def="Yes"
    else
      def="No"
    fi
    if [[ "$def" == "Yes" ]]; then
      ANSWER=$(printf 'Yes\nNo' | wofi --dmenu -p "Enable ${flag}?")
    else
      ANSWER=$(printf 'No\nYes' | wofi --dmenu -p "Enable ${flag}?")
    fi
    [[ "$ANSWER" == "Yes" ]] && FLAGS+=("$flag")
  done
  SCALING=$(printf '%s\n' "${SCALING_OPTIONS[@]}" | wofi --dmenu -p "Choose scaling")
  [[ -z "$SCALING" ]] && SCALING="fill"
else
  if [[ ${#current_flags[@]} -gt 0 ]]; then
    FLAGS=("${current_flags[@]}")
  else
    FLAGS=("${DEFAULT_FLAGS[@]}")
  fi
  [[ -n "$current_scaling" ]] && SCALING="$current_scaling"
fi
FLAGS+=("--scaling" "$SCALING")

# Kill dublicate for choosen monitor
pkill -f "linux-wallpaperengine --screen-root $MON"

# Build and run command with NVIDIA fix
CMD=(linux-wallpaperengine --screen-root "$MON" --fps 30)
CMD+=("${FLAGS[@]}")
CMD+=("$ID")
(
  export $NVIDIA_ENV
  setsid bash -c "$NVIDIA_ENV ${CMD[*]}" &>/dev/null &
)

# Update exec-once
sed -i "/^exec-once = .*linux-wallpaperengine --screen-root $MON/d" "$WALLPAPERCONF"
EXEC_LINE="exec-once = $NVIDIA_ENV ${CMD[*]} &"
printf "%s\n" "$EXEC_LINE" >> "$WALLPAPERCONF"
