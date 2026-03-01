#!/bin/bash
set -euo pipefail

# =========================================================
#   ⛏️ BINCRAFT 2.1 - SERVER MANAGER (ENGLISH VERSION)
#   Updates: Update All, Permissions fix, Config fix
# =========================================================

# Settings
SERVER_SCRIPT="mcbserver"
LGSM_URL="https://linuxgsm.sh"
LGSM_INSTALLER="linuxgsm.sh"

# 1. Root Check
if [[ $EUID -ne 0 ]]; then
   echo -e "\e[31m❌  ERROR: This script must be run as ROOT (sudo).\e[0m"
   echo -e "    Usage: sudo $0"
   exit 1
fi

# 2. Dependency Check
for tool in wget curl awk sed grep useradd su tail; do
    if ! command -v "$tool" &> /dev/null; then
        echo -e "\e[31m❌  Missing tool: '$tool'. Please install it first (apt install $tool).\e[0m"
        exit 1
    fi
done

# Colors
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
CYAN="\e[36m"
PURPLE="\e[35m"
BLUE="\e[34m"
RESET="\e[0m"
BOLD="\e[1m"

# Global variable for user list
VALID_USERS=()

# =========================================================
#   HELPER FUNCTIONS
# =========================================================

refresh_users() {
  VALID_USERS=()
  # Find users with ID >= 1000 and check if they have the script
  mapfile -t FOUND_USERS < <(getent passwd | awk -F: '$3 >= 1000 {print $1 ":" $6}')
  
  for ENTRY in "${FOUND_USERS[@]}"; do
    USERNAME="${ENTRY%%:*}"
    HOMEDIR="${ENTRY##*:}"
    
    # Check if directory and script exist
    if [[ -d "$HOMEDIR" ]] && [[ -f "$HOMEDIR/$SERVER_SCRIPT" ]]; then
      VALID_USERS+=("$USERNAME")
    fi
  done
}

run_as_user() {
    local USERNAME="$1"
    local CMD="$2"
    local INTERACTIVE="${3:-false}"

    if [[ "$INTERACTIVE" == "true" ]]; then
        # Run in foreground (for updates, console, install)
        su - "$USERNAME" -c "./$SERVER_SCRIPT $CMD"
    else
        # Run silently (for start/stop/status checks)
        su - "$USERNAME" -c "./$SERVER_SCRIPT $CMD" > /dev/null 2>&1
    fi
    return $?
}

# =========================================================
#   CORE FUNCTIONS
# =========================================================

install_new_server() {
    echo -e "\n${PURPLE}${BOLD}🏗️  INSTALL NEW SERVER${RESET}"
    
    while true; do
        read -rp "   Choose name (lowercase, no spaces): " NEW_USER
        if [[ "$NEW_USER" =~ ^[a-z0-9_-]+$ ]]; then
            if id "$NEW_USER" &>/dev/null; then
                echo -e "${RED}   ⚠️  User already exists!${RESET}"
            else
                break
            fi
        else
            echo -e "${RED}   ⚠️  Invalid characters.${RESET}"
        fi
    done

    echo -e "${BLUE}   Creating user system...${RESET}"
    useradd -m -s /bin/bash "$NEW_USER"
    echo -e "${YELLOW}   🔐 Set password for $NEW_USER:${RESET}"
    passwd "$NEW_USER"

    echo -e "${BLUE}   Downloading LinuxGSM...${RESET}"
    su - "$NEW_USER" -c "wget -q -O $LGSM_INSTALLER $LGSM_URL && chmod +x $LGSM_INSTALLER && ./$LGSM_INSTALLER $SERVER_SCRIPT"

    # Java check
    if ! su - "$NEW_USER" -c "java -version" &>/dev/null; then
        echo -e "${YELLOW}   ⚠️  WARNING: Java does not appear to be installed.${RESET}"
        echo -e "       Install it later using: apt install openjdk-21-jre-headless"
        read -rp "       Press Enter to continue..."
    fi

    echo -e "\n${GREEN}🚀 Starting installation... (Follow instructions on screen!)${RESET}"
    # Run in foreground so inputs work
    su - "$NEW_USER" -c "./$SERVER_SCRIPT install"

    echo -e "\n${GREEN}✅ Installation complete!${RESET}"
    refresh_users
}

update_single_server() {
    local USERNAME="$1"
    echo -e "\n${PURPLE}⬆️  UPDATING: ${CYAN}$USERNAME${RESET}"
    
    echo -e "${BLUE}   > Updating script (LGSM)...${RESET}"
    su - "$USERNAME" -c "./$SERVER_SCRIPT update-lgsm"
    
    echo -e "${BLUE}   > Updating game...${RESET}"
    # IMPORTANT: Runs interactively so you see errors
    su - "$USERNAME" -c "./$SERVER_SCRIPT update"
    
    echo -e "${GREEN}✅ Update complete for $USERNAME.${RESET}"
}

update_all_servers() {
    refresh_users
    if [ "${#VALID_USERS[@]}" -eq 0 ]; then
        echo -e "${YELLOW}No servers found.${RESET}"
        return
    fi

    echo -e "\n${PURPLE}🚀 STARTING BULK UPDATE (${#VALID_USERS[@]} servers)${RESET}"
    echo -e "${YELLOW}This runs server-by-server to prevent errors.${RESET}"
    sleep 2

    for U in "${VALID_USERS[@]}"; do
        echo -e "\n${PURPLE}======================================${RESET}"
        echo -e "${PURPLE}📦 PROCESSING: ${CYAN}$U${RESET}"
        echo -e "${PURPLE}======================================${RESET}"
        
        # 1. Script Update
        echo -e "${BLUE}➡️  Updating LinuxGSM core...${RESET}"
        su - "$U" -c "./$SERVER_SCRIPT update-lgsm"

        # 2. Game Update
        echo -e "${BLUE}➡️  Checking for game updates...${RESET}"
        su - "$U" -c "./$SERVER_SCRIPT update"

        echo -e "${GREEN}✓ $U has been updated.${RESET}"
        sleep 1
    done

    echo -e "\n${GREEN}✅ ALL SERVERS UPDATED!${RESET}"
}

configure_server() {
    local USERNAME="$1"
    echo -e "\n${PURPLE}⚙️  CONFIGURATION: ${CYAN}$USERNAME${RESET}"
    
    PROP_FILE=$(find "/home/$USERNAME" -name "server.properties" | head -n 1)
    
    if [[ -z "$PROP_FILE" ]]; then
        echo -e "${RED}❌ Cannot find server.properties. Is the server installed?${RESET}"
        return
    fi

    CUR_PORT=$(grep "^server-port" "$PROP_FILE" | cut -d'=' -f2 | tr -d '[:space:]')
    CUR_MODE=$(grep "^gamemode" "$PROP_FILE" | cut -d'=' -f2 | tr -d '[:space:]')
    
    echo -e "   Current Port: ${BLUE}$CUR_PORT${RESET}"
    echo -e "   Current Mode: ${BLUE}$CUR_MODE${RESET}"
    
    echo -e "\n   What would you like to change?"
    echo "   1) Gamemode (survival/creative)"
    echo "   2) Server Port"
    echo "   3) Cancel"
    read -rp "   Choice: " CONF_OPT

    case "$CONF_OPT" in
        1)
            echo "   choose: 1=survival, 2=creative"
            read -r GM_INPUT
            if [[ "$GM_INPUT" == "2" ]]; then VAL="creative"; else VAL="survival"; fi
            sed -i "s/^[[:space:]]*gamemode[[:space:]]*=.*/gamemode=$VAL/" "$PROP_FILE"
            echo -e "${GREEN}   ✓ Gamemode set to $VAL${RESET}"
            ;;
        2)
            read -rp "   New port (e.g. 25565): " NEW_PORT
            if [[ "$NEW_PORT" =~ ^[0-9]+$ ]]; then
                sed -i "s/^[[:space:]]*server-port[[:space:]]*=.*/server-port=$NEW_PORT/" "$PROP_FILE"
                sed -i "s/^[[:space:]]*query\.port[[:space:]]*=.*/query.port=$NEW_PORT/" "$PROP_FILE"
                echo -e "${GREEN}   ✓ Port set to $NEW_PORT${RESET}"
            else
                echo -e "${RED}   Invalid number.${RESET}"
            fi
            ;;
        *) return ;;
    esac

    read -rp "   Restart server to apply changes? (y/N): " RSTRT
    if [[ "$RSTRT" =~ ^[Yy]$ ]]; then
        su - "$USERNAME" -c "./$SERVER_SCRIPT restart"
    fi
}

show_status_all() {
    refresh_users
    if [ "${#VALID_USERS[@]}" -eq 0 ]; then
        echo -e "${YELLOW}No servers found.${RESET}"
        return
    fi
    
    echo -e "\n${PURPLE}📊 SERVER STATUS OVERVIEW${RESET}"
    printf "%-15s %-10s %-10s\n" "USER" "STATUS" "PORT"
    echo "-------------------------------------"
    
    for U in "${VALID_USERS[@]}"; do
        if su - "$U" -c "./$SERVER_SCRIPT status" | grep -q "STARTED"; then
            STAT="${GREEN}ONLINE${RESET}"
        else
            STAT="${RED}OFFLINE${RESET}"
        fi
        
        PROP=$(find "/home/$U" -name "server.properties" 2>/dev/null | head -n 1)
        if [[ -f "$PROP" ]]; then
            PORT=$(grep "^server-port" "$PROP" | cut -d'=' -f2 | tr -d '[:space:]')
        else
            PORT="?"
        fi
        
        printf "%-15s %-18b %-10s\n" "$U" "$STAT" "$PORT"
    done
    echo
}

# =========================================================
#   MAIN MENU
# =========================================================

main_menu() {
    while true; do
        refresh_users
        
        echo -e "${PURPLE}╔════════════════════════════════════╗${RESET}"
        echo -e "${PURPLE}║       BINCRAFT SERVER MANAGER      ║${RESET}"
        echo -e "${PURPLE}╚════════════════════════════════════╝${RESET}"
        
        echo -e "${CYAN}--- Management ---${RESET}"
        echo " 1. ▶️  Start Server"
        echo " 2. ⏹️  Stop Server"
        echo " 3. 🔄 Restart Server"
        echo " 4. 📺 Open Console"
        
        echo -e "${CYAN}--- Maintenance ---${RESET}"
        echo " 5. ⬆️  Update Single Server"
        echo " 6. 🚀 Update ALL Servers"
        echo " 7. ⚙️  Settings (Mode/Port)"
        echo " 8. 💾 Create Backup"
        
        echo -e "${CYAN}--- System ---${RESET}"
        echo " 9. 🏗️  Install New Server"
        echo "10. 📊 Status Overview"
        echo "11. 🗑️  Delete Server"
        echo "12. 🚪 Exit"
        echo
        
        read -rp "Choose an option: " OPTION

        # Actions that do NOT need a specific user
        case "$OPTION" in
            6) update_all_servers; echo; read -rp "Press Enter..."; clear; continue ;;
            9) install_new_server; continue ;;
            10) show_status_all; echo; read -rp "Press Enter..."; clear; continue ;;
            12) exit 0 ;;
        esac

        # Selection logic for options that DO need a user
        TARGET_USER=""
        if [[ "$OPTION" =~ ^[1-8]$ ]] || [[ "$OPTION" == "11" ]]; then
            if [ "${#VALID_USERS[@]}" -eq 0 ]; then
                echo -e "${RED}No servers found! Install one first.${RESET}"
                read -r _
                continue
            fi
            
            if [ "${#VALID_USERS[@]}" -eq 1 ]; then
                TARGET_USER="${VALID_USERS[0]}"
            else
                echo -e "${CYAN}Select server:${RESET}"
                select U in "${VALID_USERS[@]}"; do
                    if [[ -n "$U" ]]; then TARGET_USER="$U"; break; fi
                done
            fi
        fi

        # Execute Actions
        case "$OPTION" in
            1) 
                echo -e "${GREEN}Starting...${RESET}"; run_as_user "$TARGET_USER" "start" "true" ;;
            2) 
                echo -e "${YELLOW}Stopping...${RESET}"; run_as_user "$TARGET_USER" "stop" "true" ;;
            3) 
                echo -e "${YELLOW}Restarting...${RESET}"; run_as_user "$TARGET_USER" "restart" "true" ;;
            4) 
                echo -e "${BLUE}Opening Console...${RESET}"; run_as_user "$TARGET_USER" "console" "true" ;;
            5) 
                update_single_server "$TARGET_USER" ;;
            7) 
                configure_server "$TARGET_USER" ;;
            8) 
                echo -e "${BLUE}Creating Backup...${RESET}"; run_as_user "$TARGET_USER" "backup" "true" ;;
            11)
                echo -e "${RED}ARE YOU SURE? This will delete user $TARGET_USER and all files!${RESET}"
                read -rp "Type 'YES' to confirm: " CONFIRM
                if [[ "$CONFIRM" == "YES" ]]; then
                    run_as_user "$TARGET_USER" "stop" "false"
                    userdel -r "$TARGET_USER"
                    echo -e "${GREEN}Deleted.${RESET}"
                fi
                ;;
            *) echo -e "${RED}Invalid choice.${RESET}" ;;
        esac
        
        echo
        read -rp "Press Enter to continue..." _
        clear
    done
}

clear
main_menu
