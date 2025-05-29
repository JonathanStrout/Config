## Quick Install

Copy and paste this command in your terminal:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/JonathanStrout/Config/main/install.sh)"
```

## What This Script Does

This script sets up a complete development environment by:

- Setting up Git with your name and email
- Installing and configuring GPG for secure credential storage
- Installing Git Credential Manager for easier authentication
- Setting up Homebrew
- Installing pyenv for Python version management
- Installing nvm for Node.js version management
- Automatically adding windows tools to your WSL path, including:
  - C:\Windows Folder
  - Microsoft VS Code
  - Cursor editor
  - Docker Desktop

The script will ask for your Git name, email, and which components you want to install before proceeding.

## Advanced Usage

For more options, you can download the script and run it with specific flags:

```bash
curl -fsSL https://raw.githubusercontent.com/JonathanStrout/Config/main/install.sh -o install.sh
chmod +x install.sh
./install.sh --help
```

## Security

Always review scripts before running them on your system. You can view the script content [here](https://github.com/JonathanStrout/Config/blob/main/install.sh).
