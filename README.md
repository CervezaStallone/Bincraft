# ⛏️ BINCRAFT

```
 ██████╗ ██╗███╗   ██╗ ██████╗██████╗  █████╗ ███████╗████████╗
 ██╔══██╗██║████╗  ██║██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝
 ██████╔╝██║██╔██╗ ██║██║     ██████╔╝███████║█████╗     ██║   
 ██╔══██╗██║██║╚██╗██║██║     ██╔══██╗██╔══██║██╔══╝     ██║   
 ██████╔╝██║██║ ╚████║╚██████╗██║  ██║██║  ██║██║        ██║   
 ╚═════╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝ 

        🎮 LinuxGSM Minecraft Server Manager by BRDC.nl
        ⛏️  Mine • 🔨 Craft • 🛡️ Protect • 💎 Optimize
```

A powerful, user-friendly Minecraft server management tool built on top of [LinuxGSM](https://linuxgsm.com/). Manage multiple Minecraft servers with ease through an interactive, Minecraft-themed terminal interface.

## Features

### Multi-Server Management
- **Multiple Server Support**: Manage unlimited Minecraft servers, each with its own Linux user
- **Automatic Discovery**: Automatically detects all installed LinuxGSM Minecraft servers
- **Bulk Operations**: Execute commands across all servers simultaneously
- **Port Management**: View and manage server ports and query settings

### Server Operations
- **Start/Stop/Restart**: Full control over server lifecycle
- **Interactive Console**: Direct access to server console with proper signal handling
- **Real-time Monitoring**: Health checks and status monitoring
- **Log Viewing**: Easy access to server logs

### Backup & Maintenance
- **Automated Backups**: Create and manage server backups
- **Backup Management**: List, cleanup, and restore from backups
- **Full Maintenance Mode**: Comprehensive maintenance with backup, stop, update, and restart
- **Validation Support**: Optional file validation during maintenance

### Configuration Management
- **Gamemode Configuration**: Survival, Creative, Adventure, Spectator
- **World Type Selection**: Normal, Flat, Amplified, Large Biomes
- **Flat World Presets**: Multiple presets including:
  - Standard Flat
  - Tunnel-friendly (60 stone layers - perfect for underground builds!)
  - Minimal Surface
  - Void with spawn platform
  - City-builder base
  - Custom generator settings support
- **Query Settings**: Enable/disable server query for monitoring tools
- **Auto-restart Preferences**: Configure automatic restart behavior (prompt/always/never)

### Installation & Setup
- **Easy Installation**: Guided installation of new Minecraft servers
- **User Management**: Automatic Linux user creation for server isolation
- **LinuxGSM Integration**: Seamless LinuxGSM installation and setup
- **Server Removal**: Safe server deletion with confirmation

### User Interface
- **Minecraft-Themed Colors**: Emerald green, gold, redstone red, diamond cyan
- **Progress Indicators**: Visual feedback for long-running operations
- **Clear Status Display**: Running state checks for all servers
- **Interactive Menus**: Intuitive menu-driven interface

## Requirements

- **OS**: Linux (tested on Ubuntu/Debian-based systems)
- **Privileges**: Root or sudo access for user management operations
- **Dependencies**:
  - `bash` (4.0+)
  - `wget` or `curl`
  - `getent`
  - Standard Linux utilities (`awk`, `grep`, `sed`, etc.)
- **Network**: Internet connection for LinuxGSM downloads and updates

## Installation

1. **Download the script**:
   ```bash
   wget https://github.com/cervezaStallonebincraft/raw/main/bincraft.sh
   # or
   curl -O https://github.com/cervezaStallone/bincraft/raw/main/bincraft.sh
   ```

2. **Make it executable**:
   ```bash
   chmod +x bincraft.sh
   ```

3. **Run as root or with sudo**:
   ```bash
   sudo ./bincraft.sh
   ```

## Usage

### Starting Bincraft
```bash
sudo ./bincraft.sh
```

### Main Menu Options

#### Basic Operations
1. **Show server details** - Display comprehensive server information
2. **Start server** - Start selected or all servers
3. **Stop server** - Stop selected or all servers
4. **Restart server** - Restart selected or all servers
5. **Open console** - Interactive console access (use Ctrl+B then D to exit)
6. **Monitor server health** - Run health diagnostics
7. **View logs** - Display last 50 log entries
8. **Check server status** - View current server state
9. **Show server ports** - Display port configuration and query status

#### Maintenance & Updates
10. **Backup server** - Create immediate backup
11. **Backup management** - Create, list, restore, or cleanup backups
12. **Full maintenance mode** - Complete maintenance workflow:
    - Display server details
    - Create backup
    - Stop server
    - Optional validation
    - Update game files
    - Update LinuxGSM
    - Restart server
13. **Update all servers** - Bulk update game files and LinuxGSM

#### Advanced Operations
14. **Send console command** - Execute commands directly to server console
15. **Install new server** - Create new Minecraft server with dedicated user
16. **Check running states** - View run state of all servers at once
17. **Configure world** - Modify server.properties settings
18. **Remove server** - Delete server and associated user (requires confirmation)
19. **Exit** - Close Bincraft

## Configuration

### Auto-restart Preferences
Bincraft stores preferences in `.bincraft.conf` in the script directory.

**Options**:
- `prompt` (default): Ask before restarting after configuration changes
- `always`: Automatically restart without prompting
- `never`: Never restart automatically

**Set preference during configuration**:
- When prompted to restart, enter:
  - `a` or `A` to set "always"
  - `n` or `N` to set "never"

### Server Configuration

#### Gamemode Options
- **Survival** (0): Default gameplay mode
- **Creative** (1): Unlimited resources and flight
- **Adventure** (2): Limited block interaction
- **Spectator** (3): Free movement, no interaction

#### World Types
- **NORMAL**: Standard Minecraft world generation
- **FLAT**: Superflat world with customizable layers
- **AMPLIFIED**: Extreme terrain generation (requires more RAM)
- **LARGEBIOMES**: Extended biome sizes

#### Flat World Presets

**Modern (Minecraft 1.13+)**:
1. Standard Flat: `minecraft:bedrock,2*minecraft:dirt,minecraft:grass_block;minecraft:plains;decoration`
2. Tunnel-friendly: `minecraft:bedrock,60*minecraft:stone,3*minecraft:dirt,minecraft:grass_block;minecraft:plains;decoration`
3. Minimal Surface: `minecraft:bedrock,minecraft:dirt,minecraft:grass_block;minecraft:plains;decoration`
4. Void w/ spawn platform: `minecraft:air;minecraft:plains;`
5. City-builder base: `minecraft:bedrock,minecraft:dirt,minecraft:grass_block;minecraft:plains;`

**Legacy (Pre-1.13)**:
1. Classic Grass: `3;7,2x3,2:1;`
2. Tunnel-friendly: `3;7,60*1,3*3,2;`
3. Thin Surface: `3;2*minecraft:grass,minecraft:dirt,minecraft:bedrock;`
4. Void: `2;0,0,0;`
5. Classic Superflat: `3;2*minecraft:grass,minecraft:dirt,minecraft:bedrock;minecraft:plains;`

#### Query Configuration
- **Disabled** (default): Most secure, no external monitoring
- **Enabled**: Allows monitoring tools and server lists to connect
- Default query port: 25565

## Server Installation Process

1. **Create new server** (Option 15)
2. **Enter username** (e.g., `mcserver1`)
3. **Set password** for the new user
4. **Automatic setup**:
   - User creation with home directory
   - LinuxGSM download and installation
   - Server script (`mcbserver`) installation
5. **Optional automatic install**: Run `./mcbserver install` immediately
6. **Optional automatic start**: Start server after installation

## Security Considerations

- Each server runs under its own Linux user for isolation
- Query ports are disabled by default
- Backup management prevents data loss
- Confirmation required for destructive operations (server deletion)
- Signal handling prevents data corruption during stops

## File Structure

```
/home/brian/Documents/Development/Bincraft/
├── bincraft.sh          # Main script
└── .bincraft.conf       # User preferences (auto-generated)

/home/[username]/        # Each server user's home directory
├── mcbserver            # LinuxGSM server script
├── linuxgsm.sh          # LinuxGSM installer
├── serverfiles/         # Minecraft server files
├── log/                 # Server logs
├── backups/             # Server backups
└── lgsm/                # LinuxGSM configuration
```

## Technical Details

### Signal Handling
- Proper SIGINT and SIGTERM handling for graceful shutdowns
- Background process management for non-interactive operations
- Foreground execution for interactive console access

### Progress Indicators
- Visual feedback for long-running operations
- Loading animations during execution
- Status updates with color-coded output

### Error Handling
- Exit on error (`set -euo pipefail`)
- Command validation and error reporting
- Graceful fallback for failed operations

## Troubleshooting

### Server not detected
- Ensure the server script is named `mcbserver`
- Verify the script is executable: `chmod +x ~/mcbserver`
- Check user's home directory permissions

### Console won't open
- Ensure tmux/screen is installed (LinuxGSM requirement)
- Check server is running: `./ status`
- Verify console access permissions

### Updates fail
- Check internet connectivity
- Verify sufficient disk space
- Review server logs: `tail -f ~/log/console/*.log`

### Permission errors
- Run Bincraft with sudo: `sudo ./bincraft.sh`
- Verify user has proper home directory permissions
- Check server file ownership: `ls -la /home/[username]/`

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues.

## License

This project is provided as-is. Please ensure compliance with Minecraft's EULA and LinuxGSM's license.

## Links

- [LinuxGSM](https://linuxgsm.com/)
- [Minecraft](https://www.minecraft.net/)
- [Minecraft Server Properties](https://minecraft.fandom.com/wiki/Server.properties)

## Author

**BRDC.nl**

---

**Happy Mining!**
