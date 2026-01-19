#!/bin/bash
set -euo pipefail

# ==============================
#   ⛏️ BINCRAFT - Minecraft Server Manager
# ==============================

SERVER_SCRIPT="mcbserver"
LGSM_URL="https://linuxgsm.sh"
LGSM_INSTALLER="linuxgsm.sh"

# Script directory and config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.bincraft.conf"

# Load preferences if present
AUTO_RESTART_PREF="prompt" # options: prompt, always, never
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE" || true
fi

# Kleuren (Minecraft themed)
GREEN="\e[32m"      # ✓ Emerald - Success
YELLOW="\e[33m"     # ⚠ Gold - Warning
RED="\e[31m"        # ✗ Redstone - Error
CYAN="\e[36m"       # ⬥ Diamond - Info
PURPLE="\e[35m"     # ✦ Enchanted - Special
BLUE="\e[34m"       # ⬢ Lapis - Details
GRAY="\e[90m"       # ◇ Stone - Inactive
RESET="\e[0m"

clear

cat << "EOF"
 ██████╗ ██╗███╗   ██╗ ██████╗██████╗  █████╗ ███████╗████████╗
 ██╔══██╗██║████╗  ██║██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝
 ██████╔╝██║██╔██╗ ██║██║     ██████╔╝███████║█████╗     ██║   
 ██╔══██╗██║██║╚██╗██║██║     ██╔══██╗██╔══██║██╔══╝     ██║   
 ██████╔╝██║██║ ╚████║╚██████╗██║  ██║██║  ██║██║        ██║   
 ╚═════╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝ 

        � LinuxGSM Minecraft Server Manager by BRDC.nl
        ⛏️  Mine • 🔨 Craft • 🛡️ Protect • 💎 Optimize
EOF

echo -e "${CYAN}⬢ Mining the world for server installations...${RESET}"

# === PROGRESS BAR ===
show_progress() {
  local MESSAGE="$1"
  local BLOCKS="▓▓▓▓▓▓▓▓▓▓"
  echo -ne "${GRAY}[          ] 0% - ${MESSAGE}${RESET}\r"
  sleep 0.3
  echo -ne "${CYAN}[${BLOCKS:0:3}       ] 30% - ${MESSAGE}${RESET}\r"
  sleep 0.3
  echo -ne "${CYAN}[${BLOCKS:0:6}    ] 60% - ${MESSAGE}${RESET}\r"
  sleep 0.3
  echo -ne "${GREEN}[${BLOCKS}] 100% - ${MESSAGE}${RESET}\r"
  echo
}

# === USER DETECTIE ===
show_progress "Scanning for servers"

mapfile -t USERS < <(
  getent passwd |
  awk -F: '$3 >= 1000 && $7 !~ /(false|nologin)$/ {print $1 ":" $6}'
)

VALID_USERS=()

for ENTRY in "${USERS[@]}"; do
  USERNAME="${ENTRY%%:*}"
  HOMEDIR="${ENTRY##*:}"

  if [[ -d "$HOMEDIR" ]] && [[ -x "$HOMEDIR/$SERVER_SCRIPT" ]]; then
    VALID_USERS+=("$USERNAME")
  fi
done

if [ "${#VALID_USERS[@]}" -eq 0 ]; then
  echo -e "${YELLOW}⚠ No existing Minecraft servers found.${RESET}"
  echo -e "${CYAN}💡 Use the install option to craft a new server!${RESET}"
else
  echo -e "${GREEN}💎 Found ${#VALID_USERS[@]} server(s) loaded in inventory!${RESET}"
fi

# === FUNCTIES ===
run_cmd() {
  local USERNAME="$1"
  local CMD="${2:-}"
  local INTERACTIVE="${3:-false}"

  if [[ -z "$CMD" ]]; then
    echo -e "${RED}⚔️ No command given for $USERNAME${RESET}"
    return 1
  fi

  # If this is an interactive request (console), run in foreground so the
  # user can interact directly with the child process.
  if [[ "$INTERACTIVE" == true ]]; then
    su - "$USERNAME" -c "cd ~ || exit 1; ./$SERVER_SCRIPT $CMD"
    local EXIT_STATUS=$?
    if [ $EXIT_STATUS -ne 0 ]; then
      echo -e "${RED}🔥 Warning: Command '$CMD' failed for $USERNAME (exit $EXIT_STATUS)${RESET}"
      return 1
    fi
    return 0
  fi

  # Non-interactive: run in background and forward signals while waiting.
  su - "$USERNAME" -c "cd ~ || exit 1; exec ./$SERVER_SCRIPT $CMD" &
  local CHILD_PID=$!

  # Save existing trap and set new one
  local OLD_TRAP
  OLD_TRAP=$(trap -p INT TERM)
  trap 'kill -TERM "$CHILD_PID" 2>/dev/null || true' INT TERM

  wait "$CHILD_PID"
  local EXIT_STATUS=$?

  # Restore previous trap
  eval "$OLD_TRAP" 2>/dev/null || trap - INT TERM

  if [ $EXIT_STATUS -ne 0 ]; then
    echo -e "${RED}🔥 Warning: Command '$CMD' failed for $USERNAME (exit $EXIT_STATUS)${RESET}"
    return 1
  fi
  return 0
}

execute_with_loader() {
  local FUNC="$1"; shift || return 1
  local TMP
  TMP=$(mktemp)

  clear
  echo -e "${CYAN}⬢ ${PURPLE}Loading...${RESET}"

  ( $FUNC "$@" ) >"$TMP" 2>&1 &
  local CHILD_PID=$!

  local BLOCKS="▓▓▓▓▓▓▓▓▓▓"
  local len=${#BLOCKS}
  local i=0

  while kill -0 "$CHILD_PID" 2>/dev/null; do
    local filled=$(( (i % (len+1)) ))
    local bar=""
    bar+="${BLOCKS:0:filled}"
    for ((j=filled;j<len;j++)); do bar+=" "; done
    printf "\r${GRAY}[${bar}] ${CYAN}%s${RESET}" "${BLOCKS:0:filled}"
    sleep 0.15
    i=$((i+1))
  done

  wait "$CHILD_PID"
  local EXIT_STATUS=$?
  printf "\n"
  cat "$TMP"
  rm -f "$TMP"
  return $EXIT_STATUS
}

# Wrapper helpers that call execute_with_loader with original functions
run_cmd_with_loader() { execute_with_loader run_cmd "$@"; }
server_status_with_loader() { execute_with_loader server_status "$@"; }
restart_server_with_loader() { execute_with_loader restart_server "$@"; }
monitor_server_with_loader() { execute_with_loader monitor_server "$@"; }
show_logs_with_loader() { execute_with_loader show_logs "$@"; }
maintenance_user_with_loader() { execute_with_loader maintenance_user "$@"; }
update_all_servers_with_loader() { execute_with_loader update_all_servers "$@"; }
show_server_ports_with_loader() { execute_with_loader show_server_ports "$@"; }

maintenance_user() {
  local USERNAME="$1"
  local VALIDATE="${2:-false}"

  echo
  echo -e "${YELLOW}========================================${RESET}"
  echo -e "${GREEN}⛏️  Full Maintenance for: ${CYAN}$USERNAME${RESET}"
  echo -e "${YELLOW}========================================${RESET}"

  echo -e "${BLUE}📋 Mining server data...${RESET}"
  run_cmd "$USERNAME" details
  
  echo -e "${BLUE}📦 Crafting backup chest...${RESET}"
  run_cmd "$USERNAME" backup
  
  echo -e "${BLUE}⏸️  Stopping world simulation...${RESET}"
  run_cmd "$USERNAME" stop

  if [[ "$VALIDATE" == true ]]; then
    echo -e "${PURPLE}🔮 Enchanting files with validation magic...${RESET}"
    run_cmd "$USERNAME" validate
  fi

  echo -e "${BLUE}🧱 Building updates...${RESET}"
  run_cmd "$USERNAME" update
  
  echo -e "${BLUE}⚙️  Smelting LinuxGSM updates...${RESET}"
  run_cmd "$USERNAME" update-lgsm
  
  echo -e "${BLUE}▶️  Respawning server...${RESET}"
  run_cmd "$USERNAME" start
}

install_new_server() {
  echo
  # Prevent concurrent installs with a lock file
  LOCK_FILE="$SCRIPT_DIR/.install.lock"
  if [[ -f "$LOCK_FILE" ]]; then
    echo -e "${YELLOW}⚠️ An install is already in progress (lock present). Try again later.${RESET}"
    return 1
  fi
  echo $$ > "$LOCK_FILE"
  trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

  echo -e "${PURPLE}╔════════════════════════════════════════╗${RESET}"
  echo -e "${PURPLE}║    🏗️  CRAFT NEW SERVER INSTALLATION   ║${RESET}"
  echo -e "${PURPLE}╚════════════════════════════════════════╝${RESET}"
  echo
  
  # Username input
  read -rp "🎮 Enter new username for server (e.g., mcserver1): " NEW_USER
  
  if [[ -z "$NEW_USER" ]]; then
    echo -e "${RED}⚔️ Username cannot be empty!${RESET}"
    return 1
  fi
  
  # Check if user exists
  if id "$NEW_USER" &>/dev/null; then
    echo -e "${RED}⚔️ User '$NEW_USER' already exists!${RESET}"
    return 1
  fi
  
  echo -e "${CYAN}⬢ Creating new player: $NEW_USER${RESET}"
  
  # Create user
  if ! useradd -m -s /bin/bash "$NEW_USER"; then
    echo -e "${RED}🔥 Failed to create user!${RESET}"
    return 1
  fi
  
  echo -e "${GREEN}✓ User created successfully!${RESET}"
  
  # Set password
  echo -e "${YELLOW}🔐 Set password for $NEW_USER:${RESET}"
  if ! passwd "$NEW_USER"; then
    echo -e "${RED}🔥 Failed to set password!${RESET}"
    return 1
  fi
  
  echo -e "${CYAN}⬢ Installing LinuxGSM in /home/$NEW_USER...${RESET}"
  
  # Download and install LinuxGSM
  if ! su - "$NEW_USER" -c "
    cd ~ || exit 1
    wget -O $LGSM_INSTALLER $LGSM_URL
    chmod +x $LGSM_INSTALLER
    ./$LGSM_INSTALLER $SERVER_SCRIPT
  "; then
    echo -e "${RED}🔥 Failed to install LinuxGSM!${RESET}"
    return 1
  fi
  
  echo -e "${GREEN}💎 LinuxGSM installed successfully!${RESET}"
  echo
  echo -e "${YELLOW}📚 Next steps:${RESET}"
  echo -e "${CYAN}   1. Switch user: ${GREEN}su - $NEW_USER${RESET}"
  echo -e "${CYAN}   2. Install game: ${GREEN}./$SERVER_SCRIPT install${RESET}"
  echo -e "${CYAN}   3. Start server: ${GREEN}./$SERVER_SCRIPT start${RESET}"
  echo
  # Offer to run install and start automatically
  read -rp "🔧 Run './$SERVER_SCRIPT install' now for $NEW_USER? (y/N): " RUN_INSTALL
  if [[ "$RUN_INSTALL" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}⬢ Running initial install for $NEW_USER...${RESET}"
    # Run interactively so the admin can respond to any LinuxGSM prompts
    if ! run_cmd "$NEW_USER" install true; then
      echo -e "${YELLOW}⚠️ The install command exited with an error or requires manual interaction.${RESET}"
      echo -e "${YELLOW}⚠️ If prompts appeared, finish them in the user's shell: su - $NEW_USER${RESET}"
    else
      echo -e "${GREEN}✓ Install command completed.${RESET}"
    fi

    read -rp "▶️  Start server now? (y/N): " START_NOW
    if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
      echo -e "${CYAN}⬢ Starting server for $NEW_USER...${RESET}"
      if run_cmd "$NEW_USER" start; then
        echo -e "${GREEN}✓ Server started.${RESET}"
      else
        echo -e "${RED}⚠️ Failed to start server automatically. Try: su - $NEW_USER && ./$SERVER_SCRIPT start${RESET}"
      fi
    fi
    echo
  fi
  
  # Add to valid users
  VALID_USERS+=("$NEW_USER")
  
  # Cleanup lock
  rm -f "$LOCK_FILE"
  trap - EXIT INT TERM
  
  echo -e "${GREEN}🏰 Server installation crafted successfully!${RESET}"
}

show_console() {
  local USERNAME="$1"
  echo -e "${CYAN}📺 Opening console for: $USERNAME${RESET}"
  echo -e "${YELLOW}⚠️  Press CTRL+B then D to exit console${RESET}"
  sleep 2
  run_cmd "$USERNAME" console true
}

monitor_server() {
  local USERNAME="$1"
  echo -e "${CYAN}🔍 Running health check for: $USERNAME${RESET}"
  run_cmd "$USERNAME" monitor
}

show_logs() {
  local USERNAME="$1"
  echo -e "${CYAN}🪓 Chopping logs for: $USERNAME${RESET}"
  su - "$USERNAME" -c "
    cd ~ || exit 1
    if [ -d log ]; then
      echo -e '${BLUE}📋 Last 50 log entries:${RESET}'
      tail -n 50 log/console/*.log 2>/dev/null || echo -e '${YELLOW}⚠️  No logs found${RESET}'
    else
      echo -e '${YELLOW}⚠️  Log directory not found${RESET}'
    fi
  "
}

server_status() {
  local USERNAME="$1"
  echo -e "${CYAN}🗺️ Checking world status for: $USERNAME${RESET}"
  run_cmd "$USERNAME" details
}

restart_server() {
  local USERNAME="$1"
  echo -e "${YELLOW}🔄 Respawning world for: $USERNAME${RESET}"
  run_cmd "$USERNAME" restart
}

update_all_servers() {
  echo
  echo -e "${CYAN}🧱 Updating all servers...${RESET}"
  if [ "${#VALID_USERS[@]}" -eq 0 ]; then
    echo -e "${YELLOW}⚠️ No servers available.${RESET}"
    return 1
  fi
  for U in "${VALID_USERS[@]}"; do
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}⛏️  Updating: ${CYAN}$U${RESET}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    
    echo -e "${BLUE}🧱 Building game updates for $U...${RESET}"
    run_cmd "$U" update
    
    echo -e "${BLUE}⚙️  Smelting LinuxGSM updates for $U...${RESET}"
    run_cmd "$U" update-lgsm
    
    echo -e "${GREEN}✓ Updates completed for $U${RESET}"
    echo
  done
  echo -e "${GREEN}💎 All servers updated successfully!${RESET}"
}

check_running_states() {
  echo
  echo -e "${CYAN}🔎 Checking run state for all servers...${RESET}"
  if [ "${#VALID_USERS[@]}" -eq 0 ]; then
    echo -e "${YELLOW}⚠️ No servers available.${RESET}"
    return 1
  fi
  for U in "${VALID_USERS[@]}"; do
    if su - "$U" -c "cd ~ || exit 1; ./$SERVER_SCRIPT status >/dev/null 2>&1"; then
      STATUS="${GREEN}RUNNING${RESET}"
    else
      # Non-zero exit could mean stopped or an error; try a simple pid check
      PID_OUT=$(su - "$U" -c "pgrep -u $U -f '$SERVER_SCRIPT' || true")
      if [[ -n "$PID_OUT" ]]; then
        STATUS="${GREEN}RUNNING${RESET}"
      else
        STATUS="${RED}STOPPED${RESET}"
      fi
    fi

    echo -e "${PURPLE}• ${CYAN}$U${RESET}: ${STATUS}"
  done
}

show_server_ports() {
  echo
  echo -e "${CYAN}🔌 Server port information...${RESET}"
  if [ "${#VALID_USERS[@]}" -eq 0 ]; then
    echo -e "${YELLOW}⚠️ No servers available.${RESET}"
    return 1
  fi
  
  echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  printf "${CYAN}%-20s ${BLUE}%-15s ${GREEN}%-10s${RESET}\n" "SERVER" "PORT" "QUERY PORT"
  echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  
  for U in "${VALID_USERS[@]}"; do
    PROP_PATH=$(su - "$U" -c "bash -lc 'find ~ -maxdepth 4 -type f -name server.properties -print -quit'" 2>/dev/null || true)
    
    if [[ -z "$PROP_PATH" ]]; then
      printf "${CYAN}%-20s ${YELLOW}%-15s ${YELLOW}%-10s${RESET}\n" "$U" "Not installed" "-"
      continue
    fi
    
    # Read server-port and query.port from server.properties
    SERVER_PORT=$(su - "$U" -c "grep -E '^server-port=' '$PROP_PATH' 2>/dev/null | cut -d= -f2" || echo "25565")
    QUERY_PORT=$(su - "$U" -c "grep -E '^query.port=' '$PROP_PATH' 2>/dev/null | cut -d= -f2" || echo "-")
    ENABLE_QUERY=$(su - "$U" -c "grep -E '^enable-query=' '$PROP_PATH' 2>/dev/null | cut -d= -f2" || echo "false")
    
    # If query is disabled, show that instead of port
    if [[ "$ENABLE_QUERY" != "true" ]]; then
      printf "${CYAN}%-20s ${BLUE}%-15s ${GRAY}%-10s${RESET}\n" "$U" "$SERVER_PORT" "(disabled)"
    else
      printf "${CYAN}%-20s ${BLUE}%-15s ${GREEN}%-10s${RESET}\n" "$U" "$SERVER_PORT" "$QUERY_PORT"
    fi
  done
  
  echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

configure_query_only() {
  if [ "${#VALID_USERS[@]}" -eq 0 ]; then
    echo -e "${YELLOW}⚠️ No servers available.${RESET}"
    return 1
  fi

  # Server selection
  if [ "${#VALID_USERS[@]}" -eq 1 ]; then
    local USERNAME="${VALID_USERS[0]}"
  else
    echo
    echo -e "${CYAN}🎮 Select server to configure:${RESET}"
    select USERNAME in "${VALID_USERS[@]}"; do
      if [[ -n "$USERNAME" ]]; then
        break
      else
        echo -e "${RED}⚔️ Invalid selection${RESET}"
      fi
    done
  fi

  # Find server.properties
  PROP_PATH=$(su - "$USERNAME" -c "bash -lc 'find ~ -maxdepth 4 -type f -name server.properties -print -quit'" 2>/dev/null || true)

  if [[ -z "$PROP_PATH" ]]; then
    echo -e "${YELLOW}⚠️ Could not locate server.properties for $USERNAME. Ensure the server is installed.${RESET}"
    return 1
  fi

  echo
  echo -e "${PURPLE}⚙️  Configure query for: ${CYAN}$USERNAME${RESET}"
  echo -e "${CYAN}🔌 Server query allows monitoring tools and server lists to connect${RESET}"
  echo "1) Disable query (default, most secure)"
  echo "2) Enable query (allows external monitoring)"
  read -rp "Query setting [1]: " QUERY_CH
  QUERY_CH=${QUERY_CH:-1}
  
  case "$QUERY_CH" in
    1) 
      ENABLE_QUERY_VAL="false"
      QUERY_PORT_VAL=""
      ;;
    2) 
      ENABLE_QUERY_VAL="true"
      read -rp "Query port [25565]: " QUERY_PORT_INPUT
      QUERY_PORT_VAL=${QUERY_PORT_INPUT:-25565}
      ;;
    *) 
      ENABLE_QUERY_VAL="false"
      QUERY_PORT_VAL=""
      ;;
  esac

  # Apply query settings
  su - "$USERNAME" -c "bash -lc '
    set -e
    prop=\"$PROP_PATH\"
    if grep -qE \"^enable-query=\" \"\$prop\"; then
      sed -i -E \"s/^enable-query=.*/enable-query=$ENABLE_QUERY_VAL/\" \"\$prop\"
    else
      echo \"enable-query=$ENABLE_QUERY_VAL\" >> \"\$prop\"
    fi
    if [[ \"$ENABLE_QUERY_VAL\" == \"true\" ]]; then
      if grep -qE \"^query.port=\" \"\$prop\"; then
        sed -i -E \"s/^query.port=.*/query.port=$QUERY_PORT_VAL/\" \"\$prop\"
      else
        echo \"query.port=$QUERY_PORT_VAL\" >> \"\$prop\"
      fi
    fi
  '
  "
  
  if [[ "$ENABLE_QUERY_VAL" == "true" ]]; then
    echo -e "${GREEN}✓ Query enabled on port ${QUERY_PORT_VAL} for ${USERNAME}${RESET}"
  else
    echo -e "${GREEN}✓ Query disabled for ${USERNAME}${RESET}"
  fi

  echo -e "${CYAN}🔔 Restart the server to apply changes (./$SERVER_SCRIPT restart).${RESET}"
  
  # Handle auto-restart preference
  if [[ "${AUTO_RESTART_PREF:-prompt}" == "always" ]]; then
    echo -e "${CYAN}⬢ AUTO_RESTART_PREF=always — restarting server now...${RESET}"
    run_cmd "$USERNAME" restart || echo -e "${YELLOW}⚠️ Restart request failed.${RESET}"
  elif [[ "${AUTO_RESTART_PREF:-prompt}" == "prompt" ]]; then
    read -rp "Restart server now? (y/N): " RR
    if [[ "$RR" =~ ^[Yy]$ ]]; then
      run_cmd "$USERNAME" restart || echo -e "${YELLOW}⚠️ Restart failed.${RESET}"
    fi
  else
    echo -e "${GRAY}ℹ AUTO_RESTART_PREF=never — not restarting.${RESET}"
  fi
}

configure_server() {
  local USERNAME="$1"
  echo
  echo -e "${PURPLE}⚙️  Configure world for: ${CYAN}$USERNAME${RESET}"

  # Find server.properties in common locations under the user's home
  PROP_PATH=$(su - "$USERNAME" -c "bash -lc 'find ~ -maxdepth 4 -type f -name server.properties -print -quit'" 2>/dev/null || true)

  if [[ -z "$PROP_PATH" ]]; then
    echo -e "${YELLOW}⚠️ Could not locate server.properties for $USERNAME. Ensure the server is installed.${RESET}"
    return 1
  fi

  echo -e "${BLUE}📍 Found config: ${CYAN}$PROP_PATH${RESET}"

  # Gamemode selection
  echo "1) Survival  2) Creative  3) Adventure  4) Spectator"
  read -rp "Choose gamemode [1]: " GM_CH
  GM_CH=${GM_CH:-1}
  case "$GM_CH" in
    1) GM_VAL=0 ;;
    2) GM_VAL=1 ;;
    3) GM_VAL=2 ;;
    4) GM_VAL=3 ;;
    *) GM_VAL=0 ;;
  esac

  # Level type selection with short descriptions
  echo "1) NORMAL      - Standard world with varied biomes and underground layers"
  echo "2) FLAT        - Superflat surface with customizable presets (includes tunnel-friendly with 60 stone layers)."
  echo "3) AMPLIFIED   - Tall terrain with extreme cliffs and valleys (may need more RAM)."
  echo "4) LARGEBIOMES - Bigger biome sizes; good for exploration-oriented worlds."
  read -rp "Choose world type [1]: " WT_CH
  WT_CH=${WT_CH:-1}
  case "$WT_CH" in
    1) LEVEL_TYPE="DEFAULT" ;;
    2) LEVEL_TYPE="FLAT" ;;
    3) LEVEL_TYPE="AMPLIFIED" ;;
    4) LEVEL_TYPE="LARGEBIOMES" ;;
    *) LEVEL_TYPE="DEFAULT" ;;
  esac

  # Write changes to server.properties (replace or append)
  su - "$USERNAME" -c "bash -lc '
    set -e
    prop=\"$PROP_PATH\"
    if grep -qE '^gamemode=' \"\$prop\"; then
      sed -i -E 's/^gamemode=.*/gamemode=$GM_VAL/' \"\$prop\"
    else
      echo "gamemode=$GM_VAL" >> \"\$prop\"
    fi
    if grep -qE '^level-type=' \"\$prop\"; then
      sed -i -E 's/^level-type=.*/level-type=$LEVEL_TYPE/' \"\$prop\"
    else
      echo "level-type=$LEVEL_TYPE" >> \"\$prop\"
    fi
  '
  "

  echo -e "${GREEN}✓ Gamemode set to ${GM_VAL} and world type to ${LEVEL_TYPE}${RESET}"

  # Query configuration
  echo
  echo -e "${CYAN}🔌 Configure server query (used by monitoring tools and server lists)${RESET}"
  echo "1) Disable query (default, most secure)"
  echo "2) Enable query (allows external monitoring)"
  read -rp "Query setting [1]: " QUERY_CH
  QUERY_CH=${QUERY_CH:-1}
  case "$QUERY_CH" in
    1) 
      ENABLE_QUERY_VAL="false"
      QUERY_PORT_VAL=""
      ;;
    2) 
      ENABLE_QUERY_VAL="true"
      read -rp "Query port [25565]: " QUERY_PORT_INPUT
      QUERY_PORT_VAL=${QUERY_PORT_INPUT:-25565}
      ;;
    *) 
      ENABLE_QUERY_VAL="false"
      QUERY_PORT_VAL=""
      ;;
  esac

  # Apply query settings
  su - "$USERNAME" -c "bash -lc '
    set -e
    prop=\"$PROP_PATH\"
    if grep -qE \"^enable-query=\" \"\$prop\"; then
      sed -i -E \"s/^enable-query=.*/enable-query=$ENABLE_QUERY_VAL/\" \"\$prop\"
    else
      echo \"enable-query=$ENABLE_QUERY_VAL\" >> \"\$prop\"
    fi
    if [[ \"$ENABLE_QUERY_VAL\" == \"true\" ]]; then
      if grep -qE \"^query.port=\" \"\$prop\"; then
        sed -i -E \"s/^query.port=.*/query.port=$QUERY_PORT_VAL/\" \"\$prop\"
      else
        echo \"query.port=$QUERY_PORT_VAL\" >> \"\$prop\"
      fi
    fi
  '
  "
  
  if [[ "$ENABLE_QUERY_VAL" == "true" ]]; then
    echo -e "${GREEN}✓ Query enabled on port ${QUERY_PORT_VAL}${RESET}"
  else
    echo -e "${GREEN}✓ Query disabled${RESET}"
  fi

  if [[ "$LEVEL_TYPE" == "FLAT" ]]; then
    echo -e "${CYAN}ℹ Flat worlds require 'generator-settings'. Choose a preset matching your server's Minecraft version.${RESET}"

    # Ask user which preset format to use (modern 1.13+ vs legacy <1.13)
    echo "1) Modern (Minecraft 1.13+) - uses namespaced block ids"
    echo "2) Legacy (pre-1.13) - uses numeric/legacy preset format"
    read -rp "Which format is your server? [1]: " VER_CH
    VER_CH=${VER_CH:-1}

    if [[ "$VER_CH" -eq 1 ]]; then
      echo "Modern presets (recommended for 1.13+):"
      echo "1) Standard Flat — Grass top, 2 dirt layers, bedrock bottom"
      echo "2) Tunnel-friendly Flat — bedrock, 60 stone layers, 3 dirt, grass (perfect for tunneling!)"
      echo "3) Minimal Surface — bedrock, dirt, grass (thin underground)"
      echo "4) Void w/ spawn platform — minimal platform for builders"
      echo "5) City-builder base — thin layers, no decoration"
      echo "6) Paste custom generator-settings string"
      read -rp "Choose preset [1]: " GP_CH
      GP_CH=${GP_CH:-1}
      case "$GP_CH" in
        1)
          GS_VAL="minecraft:bedrock,2*minecraft:dirt,minecraft:grass_block;minecraft:plains;decoration"
          ;;
        2)
          GS_VAL="minecraft:bedrock,60*minecraft:stone,3*minecraft:dirt,minecraft:grass_block;minecraft:plains;decoration"
          ;;
        3)
          GS_VAL="minecraft:bedrock,minecraft:dirt,minecraft:grass_block;minecraft:plains;decoration"
          ;;
        4)
          # void-ish using structure settings; small legacy-style placeholder
          GS_VAL="minecraft:air;minecraft:plains;"
          ;;
        5)
          GS_VAL="minecraft:bedrock,minecraft:dirt,minecraft:grass_block;minecraft:plains;"
          ;;
        6)
          read -rp "generator-settings: " GS_VAL
          ;;
        *)
          GS_VAL="minecraft:bedrock,2*minecraft:dirt,minecraft:grass_block;minecraft:plains;decoration"
          ;;
      esac
    else
      echo "Legacy presets (pre-1.13 legacy superflat strings):"
      echo "1) Classic Grass — 3;7,2,3;1;" 
      echo "2) Tunnel-friendly — bedrock, 60 stone layers, 3 dirt, grass (perfect for tunneling!)"
      echo "3) Thin Surface — smaller layer stack"
      echo "4) Void w/ small platform (legacy preset)"
      echo "5) Classic Superflat — compatible with older servers"
      echo "6) Paste custom legacy preset string"
      read -rp "Choose preset [1]: " GP_CH
      GP_CH=${GP_CH:-1}
      case "$GP_CH" in
        1)
          GS_VAL="3;7,2x3,2:1;"
          ;;
        2)
          GS_VAL="3;7,60*1,3*3,2;"
          ;;
        3)
          GS_VAL="3;2*minecraft:grass,minecraft:dirt,minecraft:bedrock;"
          ;;
        4)
          GS_VAL="2;0,0,0;"
          ;;
        5)
          GS_VAL="3;2*minecraft:grass,minecraft:dirt,minecraft:bedrock;minecraft:plains;"
          ;;
        6)
          read -rp "generator-settings (legacy): " GS_VAL
          ;;
        *)
          GS_VAL="3;7,2,3;1;"
          ;;
      esac
    fi

    if [[ -n "$GS_VAL" ]]; then
      su - "$USERNAME" -c "bash -lc '
        prop=\"$PROP_PATH\"
        gs_val=\"$GS_VAL\"
        if grep -qE \"^generator-settings=\" \"\$prop\"; then
          sed -i -E \"s|^generator-settings=.*|generator-settings=\$gs_val|\" \"\$prop\"
        else
          echo \"generator-settings=\$gs_val\" >> \"\$prop\"
        fi
      '
      "
      echo -e "${GREEN}✓ generator-settings updated.${RESET}"
    else
      echo -e "${YELLOW}↩️  Skipping generator-settings.${RESET}"
    fi
  fi

  echo -e "${CYAN}🔔 Done. Restart the server to apply changes (./$SERVER_SCRIPT restart).${RESET}"
  # Handle auto-restart preference
  if [[ "${AUTO_RESTART_PREF:-prompt}" == "always" ]]; then
    echo -e "${CYAN}⬢ AUTO_RESTART_PREF=always — restarting server now...${RESET}"
    run_cmd "$USERNAME" restart || echo -e "${YELLOW}⚠️ Restart request failed.${RESET}"
  elif [[ "${AUTO_RESTART_PREF:-prompt}" == "prompt" ]]; then
    read -rp "Restart server now? (y/N) [also set preference? a=always, n=never]: " RR
    case "$RR" in
      [Yy]*) run_cmd "$USERNAME" restart || echo -e "${YELLOW}⚠️ Restart failed.${RESET}" ;;
      a|A)
        AUTO_RESTART_PREF="always"
        echo "AUTO_RESTART_PREF=always" > "$CONFIG_FILE"
        echo -e "${GREEN}✓ Preference saved: always restart after config.${RESET}"
        run_cmd "$USERNAME" restart || echo -e "${YELLOW}⚠️ Restart failed.${RESET}"
        ;;
      n|N)
        AUTO_RESTART_PREF="never"
        echo "AUTO_RESTART_PREF=never" > "$CONFIG_FILE"
        echo -e "${GREEN}✓ Preference saved: never restart after config.${RESET}"
        ;;
      *) ;;
    esac
  else
    echo -e "${GRAY}ℹ AUTO_RESTART_PREF=never — not restarting.${RESET}"
  fi
}


delete_server() {
  local USERNAME="$1"
  echo
  echo -e "${RED}🗑️  REMOVE SERVER: ${CYAN}$USERNAME${RESET}"
  read -rp "Type the username to confirm deletion: " CONF
  if [[ "$CONF" != "$USERNAME" ]]; then
    echo -e "${YELLOW}↩️  Confirmation did not match. Aborting.${RESET}"
    return 1
  fi

  echo -e "${CYAN}⬢ Attempting to stop server for $USERNAME...${RESET}"
  run_cmd "$USERNAME" stop 2>/dev/null || true
  sleep 2

  echo -e "${CYAN}⬢ Removing user and home directory for $USERNAME...${RESET}"
  if userdel -r "$USERNAME" 2>/dev/null; then
    # Remove from VALID_USERS
    local NEW_LIST=()
    for u in "${VALID_USERS[@]}"; do
      if [[ "$u" != "$USERNAME" ]]; then
        NEW_LIST+=("$u")
      fi
    done
    VALID_USERS=("${NEW_LIST[@]}")
    echo -e "${GREEN}✓ User and files removed.${RESET}"
  else
    echo -e "${RED}⚠️ Failed to remove user. You may need to run this script as root.${RESET}"
    return 1
  fi
}


backup_management() {
  local USERNAME="$1"
  
  echo
  echo -e "${PURPLE}📦 Backup Management for: $USERNAME${RESET}"
  echo "1) 💾 Create new backup"
  echo "2) 📋 List backups"
  echo "3) 🔄 Restore from backup"
  echo "4) 🗑️  Cleanup old backups"
  echo "5) 🔙 Back"
  read -rp "> " BACKUP_CHOICE
  
  case "$BACKUP_CHOICE" in
    1)
      echo -e "${CYAN}⬢ Crafting backup chest...${RESET}"
      run_cmd "$USERNAME" backup
      ;;
    2)
      echo -e "${CYAN}📋 Backup inventory:${RESET}"
      su - "$USERNAME" -c "ls -lh backups/ 2>/dev/null || echo 'No backups found'"
      ;;
    3)
      echo -e "${YELLOW}⚠️  Manual restore required - check backup directory${RESET}"
      su - "$USERNAME" -c "ls backups/ 2>/dev/null"
      ;;
    4)
      read -rp "Delete backups older than how many days? " DAYS
      su - "$USERNAME" -c "find backups/ -name '*.tar.gz' -mtime +$DAYS -delete 2>/dev/null"
      echo -e "${GREEN}✓ Cleanup complete!${RESET}"
      ;;
    *)
      echo -e "${YELLOW}↩️  Returning...${RESET}"
      ;;
  esac
}

send_command() {
  local USERNAME="$1"
  echo -e "${PURPLE}💬 Send console command to: $USERNAME${RESET}"
  read -rp "Command: " CONSOLE_CMD
  
  if [[ -z "$CONSOLE_CMD" ]]; then
    echo -e "${RED}⚔️ No command provided!${RESET}"
    return 1
  fi
  
  su - "$USERNAME" -c "
    cd ~ || exit 1
    ./$SERVER_SCRIPT send '$CONSOLE_CMD'
  "
}

# === USER SELECTIE ===
select_user() {
  local FUNC="$1"
  local ARG="${2:-}"

  if [ "${#VALID_USERS[@]}" -eq 0 ]; then
    echo -e "${RED}⚔️ No servers available! Craft one first.${RESET}"
    return 1
  fi

  # If there's only one server available, run the requested function immediately
  if [ "${#VALID_USERS[@]}" -eq 1 ]; then
    local SINGLE_USER="${VALID_USERS[0]}"
    $FUNC "$SINGLE_USER" "$ARG"
    return $?
  fi

  echo
  echo -e "${CYAN}🎮 Select your world:${RESET}"
  select USER in "${VALID_USERS[@]}" "ALL"; do
    if [[ "$USER" == "ALL" ]]; then
      for U in "${VALID_USERS[@]}"; do
        $FUNC "$U" "$ARG"
      done
      break
    elif [[ -n "$USER" ]]; then
      $FUNC "$USER" "$ARG"
      break
    else
      echo -e "${RED}⚔️ Invalid selection${RESET}"
    fi
  done
}

# Like select_user but do NOT offer the "ALL" option — useful for interactive
# actions where broadcasting to all servers is not appropriate (e.g. console).
select_user_no_all() {
  local FUNC="$1"
  local ARG="${2:-}"

  if [ "${#VALID_USERS[@]}" -eq 0 ]; then
    echo -e "${RED}⚔️ No servers available! Craft one first.${RESET}"
    return 1
  fi

  if [ "${#VALID_USERS[@]}" -eq 1 ]; then
    local SINGLE_USER="${VALID_USERS[0]}"
    $FUNC "$SINGLE_USER" "$ARG"
    return $?
  fi

  echo
  echo -e "${CYAN}🎮 Select your world:${RESET}"
  select USER in "${VALID_USERS[@]}"; do
    if [[ -n "$USER" ]]; then
      $FUNC "$USER" "$ARG"
      break
    else
      echo -e "${RED}⚔️ Invalid selection${RESET}"
    fi
  done
}

# === MENU (persistent) ===
main_menu() {
  while true; do
    echo
    echo -e "${PURPLE}╔════════════════════════════════════════╗${RESET}"
    echo -e "${PURPLE}║      ⛏️  CHOOSE YOUR ADVENTURE  ⛏️       ║${RESET}"
    echo -e "${PURPLE}╚════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${CYAN}┌─ BASIC OPERATIONS${RESET}"
    echo -e "${CYAN}│${RESET}"
    echo "├─ 1)  📊 Show server details"
    echo "├─ 2)  ▶️  Start server"
    echo "├─ 3)  ⏹️  Stop server"
    echo "├─ 4)  🔄 Restart server"
    echo "├─ 5)  📺 Open console"
    echo "├─ 6)  🔍 Monitor server health"
    echo "├─ 7)  🪓 View logs"
    echo "├─ 8)  🗺️  Check server status"
    echo "├─ 9)  🔌 Show server ports"
    echo -e "${CYAN}│${RESET}"
    echo -e "${CYAN}┌─ MAINTENANCE & UPDATES${RESET}"
    echo -e "${CYAN}│${RESET}"
    echo "├─ 10) 💾 Backup server"
    echo "├─ 11) 📦 Backup management"
    echo "├─ 12) 🧱 Full maintenance mode"
    echo "├─ 13) 🔄 Update all servers"
    echo -e "${CYAN}│${RESET}"
    echo -e "${CYAN}┌─ ADVANCED${RESET}"
    echo -e "${CYAN}│${RESET}"
    echo "├─ 14) 💬 Send console command"
    echo "├─ 15) 🏗️  Install new server"
    echo -e "${CYAN}│${RESET}"
    echo "├─ 16) 🔎 Check running states (all servers)"
    echo "├─ 17) ⚙️  Configure world"
    echo "├─ 18) 🗑️  Remove server"
    echo -e "${CYAN}│${RESET}"
    echo "└─ 19) 🚪 Exit"
    echo
    read -rp "⛏️  Your choice: " CHOICE

    VALIDATE=false
    if [[ "$CHOICE" == "12" ]]; then
      read -rp "🔮 Enchant with VALIDATE magic? (y/N): " ANSWER
      [[ "$ANSWER" =~ ^[Yy]$ ]] && VALIDATE=true
    fi

    case "$CHOICE" in
      1)
        select_user server_status_with_loader
        ;;
      2)
        select_user run_cmd_with_loader start
        ;;
      3)
        select_user run_cmd_with_loader stop
        ;;
      4)
        select_user restart_server_with_loader
        ;;
      5)
        select_user_no_all show_console
        ;;
      6)
        select_user monitor_server_with_loader
        ;;
      7)
        select_user_no_all show_logs_with_loader
        ;;
      8)
        select_user server_status_with_loader
        ;;
      9)
        show_server_ports_with_loader
        echo
        read -rp "⚙️  Configure query settings for a server? (y/N): " CONFIG_QUERY
        if [[ "$CONFIG_QUERY" =~ ^[Yy]$ ]]; then
          configure_query_only
        fi
        ;;
      10)
        select_user run_cmd_with_loader backup
        ;;
      11)
        select_user_no_all backup_management
        ;;
      12)
        select_user maintenance_user_with_loader "$VALIDATE"
        ;;
      13)
        update_all_servers_with_loader
        ;;
      14)
        select_user_no_all send_command
        ;;
      15)
        install_new_server
        ;;
      16)
        execute_with_loader check_running_states
        ;;
      17)
        select_user_no_all configure_server
        ;;
      18)
        select_user_no_all delete_server
        ;;
      19)
        echo -e "${YELLOW}👋 Logging out of the world... Your progress has been saved!${RESET}"
        exit 0
        ;;
      *)
        echo -e "${RED}⚔️ Invalid option - Try again, adventurer!${RESET}"
        ;;
    esac
    echo
    read -rp "Press Enter to return to the menu..." _
    clear
  done
}

# Start interactive menu
main_menu
