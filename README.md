## Quick Install

Copy and paste this command in your terminal:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/JonathanStrout/Config/main/install.sh)"
```

## What This Script Does

This script sets up a complete development environment with intelligent detection and user choice for all components:

### 🎯 **Smart WSL Integration** (WSL environments only)
- **WSL Default Distribution**: Offers to set current distribution as default WSL distribution
- **Windows Tool Integration**: Automatically adds Windows tools to WSL PATH including Git for Windows, VS Code, Cursor, and Docker Desktop
- **Smart WSL Restart**: When configuration changes require restart, automatically shuts down WSL and shows exact command to restart

### 🔧 **Smart Git Configuration**
- **Windows Git Detection**: Automatically detects existing Windows Git configuration
- **Configuration Copying**: Offers to copy entire Windows `.gitconfig` file to WSL
- **Smart Defaults**: Uses Windows Git name/email as defaults if copying is declined
- **Credential Management**: Detects Git for Windows and offers to use Windows credentials, or installs Linux Git Credential Manager

### 📦 **Optional Development Tools** (user choice for each)
- **Homebrew**: Linux package manager for additional tools
- **pyenv**: Python version manager with existing installation detection
- **nvm**: Node.js version manager with existing installation detection
- **GPG & pass**: Secure password manager (automatically skipped if using Windows credentials)

### 🔐 **Intelligent Credential Management**
- **Windows Integration**: Uses Windows Git Credential Manager when available
- **Linux Fallback**: Installs Linux Git Credential Manager if Windows integration is declined
- **Secure Storage**: Optional GPG/pass for general password storage (only offered when relevant)

### ✨ **User Experience Features**
- **Conflict Detection**: Detects existing pyenv/nvm installations and offers removal/reinstall options
- **Clean Output**: Minimal console clutter with verbose mode available
- **Smart Prompting**: Only asks relevant questions based on detected environment
- **Non-interactive Mode**: Support for automated installations with command-line flags

## Features by Environment

### **WSL (Windows Subsystem for Linux)**
- Full Windows integration with path setup and credential sharing
- Smart detection of Windows development tools
- WSL-specific configurations and restart handling

### **Native Linux**
- Standard Linux development environment setup
- Linux-native credential management options
- Homebrew installation for additional packages

## Installation Options

Each component is optional and the script will ask before installing:

- ✅ **Git configuration** (always included)
- ❓ **WSL default distribution** (WSL only)
- ❓ **Homebrew package manager**
- ❓ **pyenv (Python version manager)**
- ❓ **nvm (Node.js version manager)**
- ❓ **Git Credential Manager** (Windows integration or Linux version)
- ❓ **GPG & pass password manager** (for secure storage beyond Git)

## Advanced Usage

For more options, you can download the script and run it with specific flags:

```bash
curl -fsSL https://raw.githubusercontent.com/JonathanStrout/Config/main/install.sh -o install.sh
chmod +x install.sh
./install.sh --help
```

### Available Options:
- `-v, --verbose`: Enable detailed output
- `-n, --non-interactive`: Run with defaults (no prompts)
- `--git-name NAME`: Set Git name
- `--git-email EMAIL`: Set Git email
- `--skip-homebrew`: Skip Homebrew installation

## Security

Always review scripts before running them on your system. You can view the script content [here](https://github.com/JonathanStrout/Config/blob/main/install.sh).

## What Makes This Script Smart

**🔍 Environment Detection**: Automatically detects WSL vs native Linux and Windows development tools

**🤝 Windows Integration**: Seamlessly integrates with existing Windows Git configuration and credentials

**⚡ Conflict Avoidance**: Detects existing installations and offers safe upgrade paths

**🎛️ User Control**: Every component is optional - install only what you need

**🧹 Clean Experience**: Minimal output with essential information, detailed logging available in verbose mode
