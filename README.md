# ⛏️ Bincraft
### **The Ultimate Multi-User Minecraft Server Manager**

**Bincraft** is a robust Bash-based wrapper for [LinuxGSM](https://linuxgsm.com/), designed to manage multiple isolated Minecraft server instances on a single Linux machine.

By leveraging a **One User = One Server** architecture, Bincraft ensures maximum security, resource isolation, and ease of management for server networks.

---

## ✨ Features
* **Multi-Instance Deployment:** Easily create new servers, each isolated in its own system user account.
* **Bulk Updates:** Update every server instance (both the LGSM engine and Minecraft binaries) with a single command.
* **Interactive Configuration:** Change gamemodes, server ports, and query settings without manually editing `.properties` files.
* **Live Console Access:** Integrated attachment to jump into the live server console.
* **Health Monitoring:** Quick status overviews to see which servers are online/offline and which ports they are using.
* **Safety First:** Automatic root-privilege checks and dependency verification.

---

## 🏗️ Architecture
Bincraft operates on a per-user isolation model. Each time you "Craft a New Server," the script creates a new Linux system user.



* **Isolation:** If one server crashes or is compromised, others remain unaffected.
* **Resource Tracking:** Use tools like `top` or `htop` to see exactly which server (user) is consuming CPU/RAM.
* **Permissions:** All files are owned by the specific server user, preventing accidental cross-server file access.

---

## 🚀 Getting Started

### Prerequisites
* **OS:** Ubuntu, Debian, or CentOS.
* **Privileges:** You **must** run this script with `sudo` or as `root` to manage users.
* **Dependencies:** Java (OpenJDK 17 or 21), `wget`, `curl`, `screen`.

### Installation
1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/CervezaStallone/Bincraft.git](https://github.com/CervezaStallone/Bincraft.git)
    cd Bincraft
    ```
2.  **Set permissions:**
    ```bash
    chmod +x bincraft.sh
    ```
3.  **Launch the Manager:**
    ```bash
    sudo ./bincraft.sh
    ```

---

## 🛠️ Usage Guide

### 1. Creating your first server
Select **Option 9 (Install New Server)**. Provide a simple, lowercase name (e.g., `lobby`). The script will create the user and download the LinuxGSM core. Follow the on-screen prompts from LinuxGSM to finish the Minecraft installation.

### 2. Management Commands
* **Start/Stop/Restart:** Standard controls for your instances.
* **Console (Option 4):** Enter the live Minecraft terminal. 
    > **Note:** To exit the console without stopping the server, press `CTRL+B` then `D`.
* **Bulk Update (Option 6):** Iterates through every user created by Bincraft and runs the update sequence for both the engine and the game.

### 3. Networking
Use **Option 10 (Status Overview)** to see a table of all active servers and their assigned ports. Ensure these ports are open in your firewall:
```bash
sudo ufw allow 25565/tcp

## 🛡️ Security Note
​Because Bincraft runs servers under separate users, it effectively prevents:

- ​File Access Escalation: One server owner cannot  delete files from another.
​- Memory Leak Isolation: If one server runs out of memory, Linux's OOM killer can target that specific user's process without killing the others.

## ​🤝 Credits
​Engine: LinuxGSM
​Developer: BRDC.nl
​<!-- end list -->