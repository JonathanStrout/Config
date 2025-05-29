## Quick Install

Copy and paste this command in your terminal:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/JonathanStrout/Config/main/install.sh)"
```

## What This Script Does

This script sets up a complete development environment by:

- **Smart Git Setup**: Automatically detects existing Windows Git configuration and offers to copy it to WSL, or uses Windows values as defaults
- Setting up Git with your name and email (with intelligent defaults from Windows)
- Installing and configuring GPG for secure credential storage
- **Smart Credential Management**: Detects Git for Windows and offers to use Windows credentials in WSL, or installs Linux Git Credential Manager as fallback
- Setting up Homebrew
- Installing pyenv for Python version management
- Installing nvm for Node.js version management
- Automatically adding windows tools to your WSL path, including:
  - C:\Windows Folder
  - Git for Windows (if installed)
  - Microsoft VS Code
  - Cursor editor
  - Docker Desktop

The script will intelligently detect your existing Windows setup and ask relevant questions based on what it finds.

**Smart Git Configuration Detection**: 
- If you have Git configured in Windows, the script offers to copy your entire `.gitconfig` file to WSL
- If you decline copying but have Windows Git config, it uses your Windows name/email as defaults for manual entry
- Eliminates the need to re-enter information you've already configured

**Smart Git Credential Manager Detection**: 
- If Git for Windows is installed, the script asks if you want to use Windows Git credentials in WSL
- If you prefer, it can install the Linux version of Git Credential Manager instead
- Provides seamless integration with Windows authentication systems when desired

This approach provides the best of both worlds: convenience through automation while maintaining user control over the configuration.

## Advanced Usage

For more options, you can download the script and run it with specific flags:

```bash
curl -fsSL https://raw.githubusercontent.com/JonathanStrout/Config/main/install.sh -o install.sh
chmod +x install.sh
./install.sh --help
```

## Security

Always review scripts before running them on your system. You can view the script content [here](https://github.com/JonathanStrout/Config/blob/main/install.sh).
