#!/bin/bash
set -euo pipefail

# =========================================================
#   ⛏️ BINCRAFT 2.0 - ROBUST MINECRAFT SERVER MANAGER
#   Fixed: Updates, Permissions, Input handling, Configs
# =========================================================

# Instellingen
SERVER_SCRIPT="mcbserver"
LGSM_URL="https://linuxgsm.sh"
LGSM_INSTALLER="linuxgsm.sh"

# Controleer of we root zijn
if [[ $EUID -ne 0 ]]; then
   echo -e "\e[31m❌  FOUT: Dit script moet als ROOT (sudo) draaien.\e[0m"
   echo -e "    Gebruik: sudo $0"
   exit 1
fi

# Controleer dependencies
for tool in wget curl awk sed grep useradd su tail; do
    if ! command -v "$tool" &> /dev/null; then
        echo -e "\e[31m❌  Missende tool: '$tool'. Installeer dit eerst (apt install $tool).\e[0m"
        exit 1
    fi
done

# Kleuren
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
CYAN="\e[36m"
PURPLE="\e[35m"
BLUE="\e[34m"
RESET="\e[0m"
BOLD="\e[1m"

# Globale variabele voor gebruikerslijst
VALID_USERS=()

# =========================================================
#   HULP FUNCTIES
# =========================================================

# Herlaad de lijst met gebruikers die een Minecraft server hebben
refresh_users() {
  VALID_USERS=()
  # Zoek gebruikers met ID >= 1000 en check of ze het script hebben
  mapfile -t FOUND_USERS < <(getent passwd | awk -F: '$3 >= 1000 {print $1 ":" $6}')
  
  for ENTRY in "${FOUND_USERS[@]}"; do
    USERNAME="${ENTRY%%:*}"
    HOMEDIR="${ENTRY##*:}"
    
    # Check of de map en het script bestaan
    if [[ -d "$HOMEDIR" ]] && [[ -f "$HOMEDIR/$SERVER_SCRIPT" ]]; then
      VALID_USERS+=("$USERNAME")
    fi
  done
}

# Functie om commando's als de specifieke gebruiker te draaien
# Gebruik: run_as_user "username" "command" "interactive_boolean"
run_as_user() {
    local USERNAME="$1"
    local CMD="$2"
    local INTERACTIVE="${3:-false}"

    if [[ "$INTERACTIVE" == "true" ]]; then
        # Draai in voorgrond (voor updates, console, install)
        su - "$USERNAME" -c "./$SERVER_SCRIPT $CMD"
    else
        # Draai stil (voor start/stop/status checks)
        su - "$USERNAME" -c "./$SERVER_SCRIPT $CMD" > /dev/null 2>&1
    fi
    return $?
}

# Laadbalkje (Alleen voor puur visuele dingen, niet voor updates!)
loader() {
    local PID=$1
    local MSG=$2
    local BLOCKS="▓▓▓▓▓▓▓▓▓▓"
    while kill -0 "$PID" 2>/dev/null; do
        for i in {0..10}; do
            echo -ne "\r${CYAN}[${BLOCKS:0:i}          ] ${MSG}${RESET}"
            sleep 0.1
        done
    done
    echo -ne "\r\033[K" # Wis regel
}

# =========================================================
#   CORE FUNCTIES
# =========================================================

install_new_server() {
    echo -e "\n${PURPLE}${BOLD}🏗️  NIEUWE SERVER INSTALLEREN${RESET}"
    
    # 1. Gebruikersnaam vragen en valideren
    while true; do
        read -rp "   Kies naam (kleine letters, geen spaties): " NEW_USER
        if [[ "$NEW_USER" =~ ^[a-z0-9_-]+$ ]]; then
            if id "$NEW_USER" &>/dev/null; then
                echo -e "${RED}   ⚠️  Gebruiker bestaat al!${RESET}"
            else
                break
            fi
        else
            echo -e "${RED}   ⚠️  Ongeldige karakters.${RESET}"
        fi
    done

    # 2. Gebruiker aanmaken
    echo -e "${BLUE}   Creating user system...${RESET}"
    useradd -m -s /bin/bash "$NEW_USER"
    echo -e "${YELLOW}   🔐 Stel wachtwoord in voor $NEW_USER:${RESET}"
    passwd "$NEW_USER"

    # 3. LinuxGSM downloaden (als de gebruiker!)
    echo -e "${BLUE}   Downloading LinuxGSM...${RESET}"
    su - "$NEW_USER" -c "wget -q -O $LGSM_INSTALLER $LGSM_URL && chmod +x $LGSM_INSTALLER && ./$LGSM_INSTALLER $SERVER_SCRIPT"

    # 4. dependencies checken (Java)
    if ! su - "$NEW_USER" -c "java -version" &>/dev/null; then
        echo -e "${YELLOW}   ⚠️  WAARSCHUWING: Java lijkt niet geïnstalleerd.${RESET}"
        echo -e "       Installeer dit later met: apt install openjdk-21-jre-headless"
        read -rp "       Druk op Enter om door te gaan..."
    fi

    # 5. De Installatie (Interactief!)
    echo -e "\n${GREEN}🚀 Start installatie... (Volg de instructies op het scherm!)${RESET}"
    echo -e "${YELLOW}   Antwoord 'Y' als er om dependencies of updates gevraagd wordt.${RESET}\n"
    
    # We draaien dit in de voorgrond zodat inputs werken
    su - "$NEW_USER" -c "./$SERVER_SCRIPT install"

    echo -e "\n${GREEN}✅ Installatie voltooid!${RESET}"
    refresh_users
}

update_server() {
    local USERNAME="$1"
    echo -e "\n${PURPLE}⬆️  UPDATING: ${CYAN}$USERNAME${RESET}"
    
    echo -e "${BLUE}1. Script bijwerken (LinuxGSM)...${RESET}"
    su - "$USERNAME" -c "./$SERVER_SCRIPT update-lgsm"
    
    echo -e "${BLUE}2. Minecraft Server bijwerken...${RESET}"
    # BELANGRIJK: Dit draait interactief, zodat je eventuele errors ziet
    su - "$USERNAME" -c "./$SERVER_SCRIPT update"
    
    echo -e "${GREEN}✅ Update proces klaar voor $USERNAME.${RESET}"
    echo -e "${YELLOW}   (Als er een update was, is de server herstart)${RESET}"
}

configure_server() {
    local USERNAME="$1"
    echo -e "\n${PURPLE}⚙️  CONFIGURATIE: ${CYAN}$USERNAME${RESET}"
    
    # Vind properties bestand
    PROP_FILE=$(find "/home/$USERNAME" -name "server.properties" | head -n 1)
    
    if [[ -z "$PROP_FILE" ]]; then
        echo -e "${RED}❌ Kan server.properties niet vinden. Is de server geïnstalleerd?${RESET}"
        return
    fi

    # Huidige waardes lezen
    CUR_PORT=$(grep "^server-port" "$PROP_FILE" | cut -d'=' -f2 | tr -d '[:space:]')
    CUR_MODE=$(grep "^gamemode" "$PROP_FILE" | cut -d'=' -f2 | tr -d '[:space:]')
    
    echo -e "   Huidige Port: ${BLUE}$CUR_PORT${RESET}"
    echo -e "   Huidige Mode: ${BLUE}$CUR_MODE${RESET}"
    
    echo -e "\n   Wat wil je wijzigen?"
    echo "   1) Gamemode (survival/creative)"
    echo "   2) Server Port"
    echo "   3) Annuleren"
    read -rp "   Keuze: " CONF_OPT

    case "$CONF_OPT" in
        1)
            echo "   kies: 1=survival, 2=creative"
            read -r GM_INPUT
            if [[ "$GM_INPUT" == "2" ]]; then VAL="creative"; else VAL="survival"; fi
            # Veilige sed die witruimte negeert
            sed -i "s/^[[:space:]]*gamemode[[:space:]]*=.*/gamemode=$VAL/" "$PROP_FILE"
            echo -e "${GREEN}   ✓ Gamemode gezet op $VAL${RESET}"
            ;;
        2)
            read -rp "   Nieuwe poort (bv 25565): " NEW_PORT
            if [[ "$NEW_PORT" =~ ^[0-9]+$ ]]; then
                sed -i "s/^[[:space:]]*server-port[[:space:]]*=.*/server-port=$NEW_PORT/" "$PROP_FILE"
                # Query port ook aanpassen voor netheid
                sed -i "s/^[[:space:]]*query\.port[[:space:]]*=.*/query.port=$NEW_PORT/" "$PROP_FILE"
                echo -e "${GREEN}   ✓ Poort gezet op $NEW_PORT${RESET}"
            else
                echo -e "${RED}   Ongeldig nummer.${RESET}"
            fi
            ;;
        *) return ;;
    esac

    read -rp "   Server herstarten om wijzigingen toe te passen? (y/N): " RSTRT
    if [[ "$RSTRT" =~ ^[Yy]$ ]]; then
        su - "$USERNAME" -c "./$SERVER_SCRIPT restart"
    fi
}

show_status_all() {
    refresh_users
    if [ "${#VALID_USERS[@]}" -eq 0 ]; then
        echo -e "${YELLOW}Geen servers gevonden.${RESET}"
        return
    fi
    
    echo -e "\n${PURPLE}📊 SERVER STATUS OVERZICHT${RESET}"
    printf "%-15s %-10s %-10s\n" "GEBRUIKER" "STATUS" "POORT"
    echo "-------------------------------------"
    
    for U in "${VALID_USERS[@]}"; do
        # Status check
        if su - "$U" -c "./$SERVER_SCRIPT status" | grep -q "STARTED"; then
            STAT="${GREEN}ONLINE${RESET}"
        else
            STAT="${RED}OFFLINE${RESET}"
        fi
        
        # Port check
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
#   HOOFDMENU
# =========================================================

main_menu() {
    while true; do
        refresh_users
        
        echo -e "${PURPLE}╔════════════════════════════════════╗${RESET}"
        echo -e "${PURPLE}║       BINCRAFT SERVER MANAGER      ║${RESET}"
        echo -e "${PURPLE}╚════════════════════════════════════╝${RESET}"
        
        echo -e "${CYAN}--- Beheer ---${RESET}"
        echo " 1. ▶️  Start Server"
        echo " 2. ⏹️  Stop Server"
        echo " 3. 🔄 Restart Server"
        echo " 4. 📺 Console openen (Type CTRL+b, d om te sluiten!)"
        
        echo -e "${CYAN}--- Onderhoud ---${RESET}"
        echo " 5. ⬆️  Update Server (Game & Script)"
        echo " 6. ⚙️  Instellingen (Mode/Port)"
        echo " 7. 💾 Backup maken"
        
        echo -e "${CYAN}--- Systeem ---${RESET}"
        echo " 8. 🏗️  Nieuwe Server Installeren"
        echo " 9. 📊 Status Overzicht (Alle servers)"
        echo "10. 🗑️  Server Verwijderen"
        echo "11. 🚪 Afsluiten"
        echo
        
        read -rp "Kies een optie: " OPTION

        # Selectie logica voor opties die een gebruiker nodig hebben
        TARGET_USER=""
        if [[ "$OPTION" =~ ^[1-7]$ ]] || [[ "$OPTION" == "10" ]]; then
            if [ "${#VALID_USERS[@]}" -eq 0 ]; then
                echo -e "${RED}Geen servers gevonden! Installeer er eerst een.${RESET}"
                read -r _
                continue
            fi
            
            # Als er maar 1 user is, kies die automatisch
            if [ "${#VALID_USERS[@]}" -eq 1 ]; then
                TARGET_USER="${VALID_USERS[0]}"
            else
                echo -e "${CYAN}Selecteer server:${RESET}"
                select U in "${VALID_USERS[@]}"; do
                    if [[ -n "$U" ]]; then TARGET_USER="$U"; break; fi
                done
            fi
        fi

        # Acties uitvoeren
        case "$OPTION" in
            1) 
                echo -e "${GREEN}Starten...${RESET}"
                run_as_user "$TARGET_USER" "start" "true" 
                ;;
            2) 
                echo -e "${YELLOW}Stoppen...${RESET}"
                run_as_user "$TARGET_USER" "stop" "true" 
                ;;
            3) 
                echo -e "${YELLOW}Herstarten...${RESET}"
                run_as_user "$TARGET_USER" "restart" "true" 
                ;;
            4) 
                echo -e "${BLUE}Console openen...${RESET}"
                run_as_user "$TARGET_USER" "console" "true" 
                ;;
            5) 
                # Update functie die NIET stilletjes faalt
                update_server "$TARGET_USER" 
                ;;
            6) 
                configure_server "$TARGET_USER" 
                ;;
            7) 
                echo -e "${BLUE}Backup maken...${RESET}"
                run_as_user "$TARGET_USER" "backup" "true" 
                ;;
            8) 
                install_new_server 
                ;;
            9) 
                show_status_all 
                ;;
            10)
                echo -e "${RED}WEET JE HET ZEKER? Dit verwijdert gebruiker $TARGET_USER en alle bestanden!${RESET}"
                read -rp "Type 'JA' om te bevestigen: " CONFIRM
                if [[ "$CONFIRM" == "JA" ]]; then
                    run_as_user "$TARGET_USER" "stop" "false"
                    userdel -r "$TARGET_USER"
                    echo -e "${GREEN}Verwijderd.${RESET}"
                fi
                ;;
            11) exit 0 ;;
            *) echo -e "${RED}Ongeldige keuze.${RESET}" ;;
        esac
        
        echo
        read -rp "Druk op Enter om door te gaan..." _
        clear
    done
}

# Start het menu
clear
main_menu
