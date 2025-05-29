#!/bin/bash

# Color codes for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BRIGHT_YELLOW='\033[38;5;226m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get Linux username and set Linux home directory
LINUX_USERNAME=$(whoami)
LINUX_HOME="/home/$LINUX_USERNAME"

# Default configuration
QUIET_MODE=true
NON_INTERACTIVE=false
INSTALL_HOMEBREW=true
INSTALL_GCM=true
INSTALL_GPG_PASS=true
INSTALL_PYENV=true
INSTALL_NVM=true
GIT_NAME=""
GIT_EMAIL=""
CHANGE_GIT_CONFIG=false
INSTALL_HOMEBREW_CHOICE=""
INSTALL_GCM_CHOICE=""
INSTALL_PYENV_CHOICE=""
INSTALL_NVM_CHOICE=""
WSL_CONF_MODIFIED=false
WINDOWS_GIT_FOUND=false
WINDOWS_GIT_CONFIG_EXISTS=false
WINDOWS_GIT_NAME=""
WINDOWS_GIT_EMAIL=""
COPY_WINDOWS_GIT_CONFIG=false
USE_WINDOWS_CREDENTIALS=false
SET_WSL_DEFAULT=false
REMOVE_EXISTING_PYENV=false
REMOVE_EXISTING_NVM=false


# Function to print status messages
print_status() {
    echo -e "${GREEN}[+] $1${NC}"
}

# Function to print verbose messages (suppressed in quiet mode)
print_verbose() {
    if [ "$QUIET_MODE" = false ]; then
        echo -e "${BLUE}[*] $1${NC}"
    fi
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

# Function to print bright warning messages (for directory conflicts)
print_bright_warning() {
    echo -e "${BRIGHT_YELLOW}[!] $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Function to check if a command succeeded
check_success() {
    if [ $? -ne 0 ]; then
        print_error "$1"
        exit 1
    fi
}

# Display help information
show_help() {
    cat << EOF
Usage: ./install.sh [OPTIONS]

Options:
  -h, --help                 Show this help message
  -v, --verbose              Enable verbose output (default is quiet mode)
  -n, --non-interactive      Run in non-interactive mode with defaults
  --git-name NAME            Set Git name
  --git-email EMAIL          Set Git email
  --skip-homebrew            Skip Homebrew installation
  
EOF
    exit 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -v|--verbose)
                QUIET_MODE=false
                shift
                ;;
            -n|--non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            --git-name)
                GIT_NAME="$2"
                shift 2
                ;;
            --git-email)
                GIT_EMAIL="$2"
                shift 2
                ;;
            --skip-homebrew)
                INSTALL_HOMEBREW=false
                shift
                ;;
            *)
                print_warning "Unknown option: $1"
                shift
                ;;
        esac
    done
}

# Detect Windows Git configuration
detect_windows_git_config() {
    if [ -d "/mnt/c" ]; then
        # Get Windows username
        WIN_USERNAME=$(/mnt/c/Windows/System32/cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')
        
        # Check for Windows Git global config
        WINDOWS_GITCONFIG_PATH="/mnt/c/Users/$WIN_USERNAME/.gitconfig"
        
        if [ -f "$WINDOWS_GITCONFIG_PATH" ]; then
            WINDOWS_GIT_CONFIG_EXISTS=true
            
            # Extract name and email from Windows Git config
            if command -v git >/dev/null 2>&1; then
                # Use git to read the Windows config file
                WINDOWS_GIT_NAME=$(git config -f "$WINDOWS_GITCONFIG_PATH" user.name 2>/dev/null || echo "")
                WINDOWS_GIT_EMAIL=$(git config -f "$WINDOWS_GITCONFIG_PATH" user.email 2>/dev/null || echo "")
            else
                # Fallback: parse the file manually
                WINDOWS_GIT_NAME=$(grep -E "^\s*name\s*=" "$WINDOWS_GITCONFIG_PATH" 2>/dev/null | sed 's/.*=\s*//' | tr -d '\r' || echo "")
                WINDOWS_GIT_EMAIL=$(grep -E "^\s*email\s*=" "$WINDOWS_GITCONFIG_PATH" 2>/dev/null | sed 's/.*=\s*//' | tr -d '\r' || echo "")
            fi
            
            if [ -n "$WINDOWS_GIT_NAME" ] || [ -n "$WINDOWS_GIT_EMAIL" ]; then
                print_verbose "Found Windows Git config: Name='$WINDOWS_GIT_NAME', Email='$WINDOWS_GIT_EMAIL'"
            fi
        fi
        
        # Check if Git for Windows exists (for credential manager detection)
        if [ -d "/mnt/c/Program Files/Git/mingw64/bin" ]; then
            WINDOWS_GIT_FOUND=true
        fi
    fi
}

# Handle WSL default distribution setting
handle_wsl_default() {
    # Only ask WSL-related questions if we're actually in WSL
    if [ -d "/mnt/c" ] && [ "$NON_INTERACTIVE" = false ]; then
        # Get current distribution name
        CURRENT_DISTRO=$(cat /proc/version | grep -oE 'Ubuntu|Debian|Alpine|openSUSE|SUSE|Fedora|CentOS|RedHat' | head -n 1)
        if [ -z "$CURRENT_DISTRO" ]; then
            CURRENT_DISTRO="this distribution"
        fi
        
        echo ""
        print_status "WSL environment detected!"
        echo -e -n "${GREEN}Do you want to set $CURRENT_DISTRO as your default WSL distribution? (Y/n): ${NC}"
        read wsl_default_choice
        if [[ "$wsl_default_choice" != "n" && "$wsl_default_choice" != "N" ]]; then
            SET_WSL_DEFAULT=true
            print_status "Will set $CURRENT_DISTRO as default WSL distribution after installation."
        fi
    fi
}

# Gather all user input at the beginning
gather_user_input() {
    if [ "$NON_INTERACTIVE" = true ]; then
        print_status "Running in non-interactive mode with provided arguments."
        return
    fi

    # Windows Git Configuration Handling
    if [ "$WINDOWS_GIT_CONFIG_EXISTS" = true ]; then
        print_status "Windows Git configuration detected!"
        if [ -n "$WINDOWS_GIT_NAME" ]; then
            echo "  Name: $WINDOWS_GIT_NAME"
        fi
        if [ -n "$WINDOWS_GIT_EMAIL" ]; then
            echo "  Email: $WINDOWS_GIT_EMAIL"
        fi
        
        echo -e -n "${GREEN}Do you want to copy your Windows Git configuration to WSL? (Y/n): ${NC}"
        read copy_choice
        if [[ "$copy_choice" != "n" && "$copy_choice" != "N" ]]; then
            COPY_WINDOWS_GIT_CONFIG=true
            GIT_NAME="$WINDOWS_GIT_NAME"
            GIT_EMAIL="$WINDOWS_GIT_EMAIL"
            print_status "Will copy Windows Git configuration to WSL."
        else
            print_status "Windows Git config will not be copied."
        fi
    fi

    # Git name configuration
    if [ "$COPY_WINDOWS_GIT_CONFIG" = false ]; then
        if ! git config --global user.name >/dev/null 2>&1; then
            if [ -z "$GIT_NAME" ]; then
                # Use Windows Git name as default if available
                if [ -n "$WINDOWS_GIT_NAME" ]; then
                    echo -e -n "${GREEN}Enter your git name [$WINDOWS_GIT_NAME]: ${NC}"
                    read GIT_NAME
                    if [ -z "$GIT_NAME" ]; then
                        GIT_NAME="$WINDOWS_GIT_NAME"
                    fi
                else
                    echo -e -n "${GREEN}Enter your git name: ${NC}"
                    read GIT_NAME
                fi
                
                if [ -z "$GIT_NAME" ]; then
                    print_warning "Git name not provided, skipping..."
                fi
            fi
        else
            current_name=$(git config --global user.name)
            echo "Git name already configured as: $current_name"
            echo -e -n "${GREEN}Do you want to change it? (y/n): ${NC}"
            read change_name
            if [[ "$change_name" == "y" ]]; then
                CHANGE_GIT_CONFIG=true
                if [ -n "$WINDOWS_GIT_NAME" ]; then
                    echo -e -n "${GREEN}Enter your git name [$WINDOWS_GIT_NAME]: ${NC}"
                    read GIT_NAME
                    if [ -z "$GIT_NAME" ]; then
                        GIT_NAME="$WINDOWS_GIT_NAME"
                    fi
                else
                    echo -e -n "${GREEN}Enter your git name: ${NC}"
                    read GIT_NAME
                fi
            fi
        fi

        # Git email configuration
        if ! git config --global user.email >/dev/null 2>&1; then
            if [ -z "$GIT_EMAIL" ]; then
                # Use Windows Git email as default if available
                if [ -n "$WINDOWS_GIT_EMAIL" ]; then
                    echo -e -n "${GREEN}Enter your Git email [$WINDOWS_GIT_EMAIL]: ${NC}"
                    read GIT_EMAIL
                    if [ -z "$GIT_EMAIL" ]; then
                        GIT_EMAIL="$WINDOWS_GIT_EMAIL"
                    fi
                else
                    echo -e -n "${GREEN}Enter your Git email: ${NC}"
                    read GIT_EMAIL
                fi
                
                if [ -z "$GIT_EMAIL" ]; then
                    print_warning "Git email not provided, skipping..."
                fi
            fi
        else
            current_email=$(git config --global user.email)
            echo "Git email already configured as: $current_email"
            echo -e -n "${GREEN}Do you want to change it? (y/n): ${NC}"
            read change_email
            if [[ "$change_email" == "y" ]]; then
                CHANGE_GIT_CONFIG=true
                if [ -n "$WINDOWS_GIT_EMAIL" ]; then
                    echo -e -n "${GREEN}Enter your Git email [$WINDOWS_GIT_EMAIL]: ${NC}"
                    read GIT_EMAIL
                    if [ -z "$GIT_EMAIL" ]; then
                        GIT_EMAIL="$WINDOWS_GIT_EMAIL"
                    fi
                else
                    echo -e -n "${GREEN}Enter your Git email: ${NC}"
                    read GIT_EMAIL
                fi
            fi
        fi
    fi
    
    # Git Credential Manager handling
    if [ "$WINDOWS_GIT_FOUND" = true ]; then
        print_status "Git for Windows detected with credential manager support!"
        echo -e -n "${GREEN}Do you want to use Windows Git credentials in WSL? (Y/n): ${NC}"
        read use_windows_creds
        if [[ "$use_windows_creds" != "n" && "$use_windows_creds" != "N" ]]; then
            USE_WINDOWS_CREDENTIALS=true
            INSTALL_GCM=false  # Don't install Linux version
            print_status "Will configure WSL to use Windows Git Credential Manager."
        else
            echo -e -n "${GREEN}Do you want to install Git Credential Manager for Linux instead? (Y/n): ${NC}"
            read INSTALL_GCM_CHOICE
            if [[ "$INSTALL_GCM_CHOICE" == "n" || "$INSTALL_GCM_CHOICE" == "N" ]]; then
                INSTALL_GCM=false
            fi
        fi
    else
        # Original GCM question for when Windows Git is not found
        if [ "$INSTALL_GCM" = true ]; then
            echo -e -n "${GREEN}Do you want to install Git Credential Manager? (Y/n): ${NC}"
            read INSTALL_GCM_CHOICE
            if [[ "$INSTALL_GCM_CHOICE" == "n" || "$INSTALL_GCM_CHOICE" == "N" ]]; then
                INSTALL_GCM=false
            fi
        fi
    fi
    
    # Homebrew installation
    if [ "$INSTALL_HOMEBREW" = true ]; then
        echo -e -n "${GREEN}Do you want to install Homebrew? (Y/n): ${NC}"
        read INSTALL_HOMEBREW_CHOICE
        if [[ "$INSTALL_HOMEBREW_CHOICE" == "n" || "$INSTALL_HOMEBREW_CHOICE" == "N" ]]; then
            INSTALL_HOMEBREW=false
        fi
    fi
    
    # pyenv installation
    echo -e -n "${GREEN}Do you want to install pyenv (Python version manager)? (Y/n): ${NC}"
    read INSTALL_PYENV_CHOICE
    if [[ "$INSTALL_PYENV_CHOICE" == "n" || "$INSTALL_PYENV_CHOICE" == "N" ]]; then
        INSTALL_PYENV=false
    else
        # Check if pyenv directory already exists
        if [ -d "$LINUX_HOME/.pyenv" ]; then
            echo -e "${BRIGHT_YELLOW}[!] pyenv directory already exists at $LINUX_HOME/.pyenv${NC}"
            echo -e -n "${BRIGHT_YELLOW}Do you want to remove the existing pyenv installation and reinstall? (Y/n): ${NC}"
            read remove_pyenv
            if [[ "$remove_pyenv" == "n" || "$remove_pyenv" == "N" ]]; then
                print_status "Will keep existing pyenv installation."
                INSTALL_PYENV=false
            else
                print_status "Will remove and reinstall pyenv."
                REMOVE_EXISTING_PYENV=true
            fi
        fi
    fi
    
    # nvm installation
    echo -e -n "${GREEN}Do you want to install nvm (Node.js version manager)? (Y/n): ${NC}"
    read INSTALL_NVM_CHOICE
    if [[ "$INSTALL_NVM_CHOICE" == "n" || "$INSTALL_NVM_CHOICE" == "N" ]]; then
        INSTALL_NVM=false
    else
        # Check if nvm directory already exists
        if [ -d "$LINUX_HOME/.nvm" ]; then
            echo -e "${BRIGHT_YELLOW}[!] nvm directory already exists at $LINUX_HOME/.nvm${NC}"
            echo -e -n "${BRIGHT_YELLOW}Do you want to remove the existing nvm installation and reinstall? (Y/n): ${NC}"
            read remove_nvm
            if [[ "$remove_nvm" == "n" || "$remove_nvm" == "N" ]]; then
                print_status "Will keep existing nvm installation."
                INSTALL_NVM=false
            else
                print_status "Will remove and reinstall nvm."
                REMOVE_EXISTING_NVM=true
            fi
        fi
    fi

    # GPG and pass password manager installation (only if not using Windows credentials)
    if [ "$USE_WINDOWS_CREDENTIALS" = false ]; then
        echo -e -n "${GREEN}Do you want to install GPG and pass password manager? (for secure password storage beyond Git) (Y/n): ${NC}"
        read INSTALL_GPG_PASS_CHOICE
        if [[ "$INSTALL_GPG_PASS_CHOICE" == "n" || "$INSTALL_GPG_PASS_CHOICE" == "N" ]]; then
            INSTALL_GPG_PASS=false
        fi
    else
        # Skip GPG/pass if using Windows credentials
        INSTALL_GPG_PASS=false
        print_verbose "Skipping GPG/pass installation since using Windows Git Credential Manager."
    fi

    print_status "Thank you! Installation will now begin..."
}

# Request sudo privileges
setup_sudo() {
    print_status "Requesting sudo privileges..."
    
    # Try to get sudo without password first
    if sudo -n true 2>/dev/null; then
        print_status "Sudo session already established."
    else
        # Need to prompt for password with green styling
        echo -e "${GREEN}[+] Please enter your sudo password to continue:${NC}"
        
        # Set the sudo prompt to be green (this affects the actual sudo password prompt)
        export SUDO_PROMPT=$'\033[0;32m[sudo] password for %u: \033[0m'
        
        if sudo -v; then
            print_status "Sudo session established."
        else
            print_error "Sudo required but authentication failed. Exiting..."
            exit 1
        fi
        
        # Reset sudo prompt to default (optional, but good practice)
        unset SUDO_PROMPT
    fi

    # Keep sudo alive for the necessary commands
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    SUDO_KEEPALIVE_PID=$!
}

# Install system packages
install_system_packages() {
    print_status "Updating package lists and installing system dependencies..."
    
    if [ "$QUIET_MODE" = true ]; then
        sudo apt-get update -qq > /dev/null
        check_success "Failed to update package lists"
        sudo apt-get upgrade -y -qq > /dev/null
        check_success "Failed to upgrade packages"
        sudo apt-get install -y -qq build-essential curl git > /dev/null
        check_success "Failed to install build dependencies"
    else
        sudo apt-get update
        check_success "Failed to update package lists"
        sudo apt-get upgrade -y
        check_success "Failed to upgrade packages"
        sudo apt-get install -y build-essential curl git
        check_success "Failed to install build dependencies"
    fi
    
    print_status "System packages installed successfully."
}

# Configure Git
configure_git() {
    print_status "Setting up Git configuration..."
    
    # If copying Windows Git config, copy the entire .gitconfig file
    if [ "$COPY_WINDOWS_GIT_CONFIG" = true ] && [ "$WINDOWS_GIT_CONFIG_EXISTS" = true ]; then
        WIN_USERNAME=$(/mnt/c/Windows/System32/cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')
        WINDOWS_GITCONFIG_PATH="/mnt/c/Users/$WIN_USERNAME/.gitconfig"
        
        if [ -f "$WINDOWS_GITCONFIG_PATH" ]; then
            print_status "Copying Windows Git configuration to WSL..."
            cp "$WINDOWS_GITCONFIG_PATH" "$HOME/.gitconfig"
            check_success "Failed to copy Windows Git configuration"
            
            # Convert Windows line endings to Unix
            if command -v dos2unix >/dev/null 2>&1; then
                dos2unix "$HOME/.gitconfig" >/dev/null 2>&1
            else
                # Fallback: manual conversion
                sed -i 's/\r$//' "$HOME/.gitconfig" 2>/dev/null || true
            fi
            
            print_status "Windows Git configuration copied successfully"
            
            # Verify the copied configuration
            COPIED_NAME=$(git config --global user.name 2>/dev/null || echo "")
            COPIED_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
            
            if [ -n "$COPIED_NAME" ]; then
                print_status "Git name: $COPIED_NAME"
            fi
            if [ -n "$COPIED_EMAIL" ]; then
                print_status "Git email: $COPIED_EMAIL"
            fi
        else
            print_warning "Windows Git config file not found, falling back to manual configuration"
            COPY_WINDOWS_GIT_CONFIG=false
        fi
    fi
    
    # Manual Git configuration (if not copying from Windows or if copy failed)
    if [ "$COPY_WINDOWS_GIT_CONFIG" = false ]; then
        # Handle Git name
        if ! git config --global user.name >/dev/null 2>&1; then
            if [ -n "$GIT_NAME" ]; then
                git config --global user.name "$GIT_NAME"
                check_success "Failed to set Git name"
                print_status "Git name set to: $GIT_NAME"
            else
                print_warning "Git name not provided, skipping..."
            fi
        elif [ "$CHANGE_GIT_CONFIG" = true ] && [ -n "$GIT_NAME" ]; then
            git config --global user.name "$GIT_NAME"
            check_success "Failed to set Git name"
            print_status "Git name updated to: $GIT_NAME"
        else
            current_name=$(git config --global user.name)
            print_verbose "Git name already configured as: $current_name"
        fi

        # Handle Git email
        if ! git config --global user.email >/dev/null 2>&1; then
            if [ -n "$GIT_EMAIL" ]; then
                git config --global user.email "$GIT_EMAIL"
                check_success "Failed to set Git email"
                print_status "Git email set to: $GIT_EMAIL"
            else
                print_warning "Git email not provided, skipping..."
            fi
        elif [ "$CHANGE_GIT_CONFIG" = true ] && [ -n "$GIT_EMAIL" ]; then
            git config --global user.email "$GIT_EMAIL"
            check_success "Failed to set Git email"
            print_status "Git email updated to: $GIT_EMAIL"
        else
            current_email=$(git config --global user.email)
            print_verbose "Git email already configured as: $current_email"
        fi
    fi

    # Configure default Git branch name (always set this)
    if ! git config --global init.defaultBranch >/dev/null 2>&1; then
        print_status "Setting default Git branch to 'main'..."
        git config --global init.defaultBranch main
        check_success "Failed to set default Git branch"
    fi
}

# Install GPG and pass password manager
install_gpg_and_pass() {
    if [ "$INSTALL_GPG_PASS" = false ]; then
        print_status "Skipping GPG and pass password manager installation."
        return
    fi
    
    print_status "Installing GPG and pass password manager..."
    
    if [ "$QUIET_MODE" = true ]; then
        # Redirect all output to /dev/null to suppress it completely
        {
            sudo apt-get install -y -qq gnupg2 pass > /dev/null
        
            # Check if user already has a GPG key
            if ! gpg --list-secret-keys | grep -q "sec"; then
                print_status "No GPG key found. Generating a new GPG key for password storage..."
                print_status "When prompted, use your Git email: $GIT_EMAIL"
                
                # Create batch file for non-interactive key generation
                if [ -n "$GIT_EMAIL" ] && [ -n "$GIT_NAME" ]; then
                    cat > /tmp/gpg-gen-key << EOF
%echo Generating a GPG key
Key-Type: RSA
Key-Length: 4096
Name-Real: $GIT_NAME
Name-Email: $GIT_EMAIL
Expire-Date: 0
%no-protection
%commit
%echo Key generation completed
EOF
                    # Enhanced redirection for gpg command
                    gpg --batch --gen-key /tmp/gpg-gen-key
                    rm -f /tmp/gpg-gen-key
                else
                    # Interactive key generation if git name/email not provided
                    gpg --full-generate-key
                fi
            else
                print_status "Existing GPG key found. Using it for password store."
            fi
            
            # Initialize pass with the GPG key
            GPG_ID=$(gpg --list-secret-keys --keyid-format LONG | grep sec | head -n 1 | sed 's/.*\/\([A-F0-9]\+\) .*/\1/')
            if [ -n "$GPG_ID" ]; then
                # Check if pass is already initialized
                if [ ! -d "$HOME/.password-store" ]; then
                    print_status "Initializing pass password manager with GPG key: $GPG_ID"
                    pass init "$GPG_ID"
                else
                    print_status "Pass password manager already initialized."
                fi
            else
                print_error "Could not find GPG key ID. Password store initialization failed."
                return 1
            fi
        } > /dev/null 2>&1
    else
        sudo apt-get install -y gnupg2 pass
        check_success "Failed to install GPG and pass"
        
        # Check if user already has a GPG key
        if ! gpg --list-secret-keys | grep -q "sec"; then
            print_status "No GPG key found. Generating a new GPG key for password storage..."
            print_status "When prompted, use your Git email: $GIT_EMAIL"
            
            # Create batch file for non-interactive key generation
            if [ -n "$GIT_EMAIL" ] && [ -n "$GIT_NAME" ]; then
                cat > /tmp/gpg-gen-key << EOF
%echo Generating a GPG key
Key-Type: RSA
Key-Length: 4096
Name-Real: $GIT_NAME
Name-Email: $GIT_EMAIL
Expire-Date: 0
%no-protection
%commit
%echo Key generation completed
EOF
                gpg --batch --gen-key /tmp/gpg-gen-key
                rm -f /tmp/gpg-gen-key
            else
                # Interactive key generation if git name/email not provided
                gpg --full-generate-key
            fi
            check_success "Failed to generate GPG key"
        else
            print_status "Existing GPG key found. Using it for password store."
        fi
        
        # Initialize pass with the GPG key
        GPG_ID=$(gpg --list-secret-keys --keyid-format LONG | grep sec | head -n 1 | sed 's/.*\/\([A-F0-9]\+\) .*/\1/')
        if [ -n "$GPG_ID" ]; then
            # Check if pass is already initialized
            if [ ! -d "$HOME/.password-store" ]; then
                print_status "Initializing pass password manager with GPG key: $GPG_ID"
                pass init "$GPG_ID"
                check_success "Failed to initialize pass password manager"
            else
                print_status "Pass password manager already initialized."
            fi
        else
            print_error "Could not find GPG key ID. Password store initialization failed."
            return 1
        fi
    fi
    
    print_status "GPG and pass password manager installed and configured successfully."
}

# Configure WSL-specific settings
configure_wsl() {
    if [ -d "/mnt/c" ]; then
        print_status "WSL environment detected. Configuring WSL-specific settings..."
        cd /mnt/c && WIN_USERNAME=$(/mnt/c/Windows/System32/cmd.exe /c 'echo %USERNAME%' | tr -d '\r') && cd ~

        # Only add WSL configuration if not already present
        if ! grep -q "WSL-specific configuration" "$LINUX_HOME/.bashrc"; then
            echo >> "$LINUX_HOME/.bashrc"
            echo "# WSL-specific configuration" >> "$LINUX_HOME/.bashrc"
            echo "export WIN_USERNAME=\"$WIN_USERNAME\" # Windows username" >> "$LINUX_HOME/.bashrc"
            echo 'export PATH="$PATH:/mnt/c/Windows" # Adds Windows folder to path' >> "$LINUX_HOME/.bashrc"

            # Check for Git for Windows and add to PATH if present
            if [ -d "/mnt/c/Program Files/Git/mingw64/bin" ]; then
                echo 'export PATH="$PATH:/mnt/c/Program Files/Git/mingw64/bin" # Adds Git for Windows to path' >> "$LINUX_HOME/.bashrc"
            fi

            if [ -d "/mnt/c/Users/$WIN_USERNAME/AppData/Local/Programs/Microsoft VS Code" ]; then
                echo "export PATH=\"\$PATH:/mnt/c/Users/$WIN_USERNAME/AppData/Local/Programs/Microsoft VS Code/bin\" # Adds vscode folder to path" >> "$LINUX_HOME/.bashrc"
            fi    

            if [ -d "/mnt/c/Users/$WIN_USERNAME/AppData/Local/Programs/cursor" ]; then
                echo "export PATH=\"\$PATH:/mnt/c/Users/$WIN_USERNAME/AppData/Local/Programs/cursor/resources/app/bin\" # Adds cursor folder to path" >> "$LINUX_HOME/.bashrc"
            fi    

            # Add Docker Desktop for Windows CLI to PATH if present
            if [ -d "/mnt/c/Program Files/Docker/Docker/resources/bin" ]; then
                echo 'export PATH="$PATH:/mnt/c/Program Files/Docker/Docker/resources/bin" # Adds Docker Desktop CLI to path' >> "$LINUX_HOME/.bashrc"
            fi    
        fi

        print_status "Configuring /etc/wsl.conf..."
        if ! grep -q "appendWindowsPath = false" /etc/wsl.conf; then
            sudo bash -c 'echo -e "\n[interop]\nappendWindowsPath=false" >> /etc/wsl.conf'
            check_success "Failed to update /etc/wsl.conf"
            WSL_CONF_MODIFIED=true
        fi
        
        # Fix path conflicts between Windows and WSL tools (only if not already present)
        if ! grep -q "command_not_found_handle" "$LINUX_HOME/.bashrc"; then
            print_verbose "Adding protection against Windows/WSL path conflicts..."
            cat << 'EOF' >> "$LINUX_HOME/.bashrc"
# Safeguard against Windows PATH conflicts
function command_not_found_handle() {
  if [ -x /usr/lib/command-not-found ]; then
    /usr/lib/command-not-found -- "$1"
    return $?
  else
    return 127
  fi
}
EOF
        fi
        print_verbose "WSL-specific configurations completed."
    else
        print_verbose "Not running in WSL, skipping WSL-specific configurations."
    fi
}

# Install Git Credential Manager
install_git_credential_manager() {
    if [ "$INSTALL_GCM" = false ] && [ "$USE_WINDOWS_CREDENTIALS" = false ]; then
        print_status "Skipping Git Credential Manager installation."
        return
    fi
    
    # If user chose to use Windows credentials
    if [ "$USE_WINDOWS_CREDENTIALS" = true ]; then
        print_status "Configuring WSL to use Windows Git Credential Manager..."
        
        # Configure Git to use the credential manager from Windows
        if [ -f "/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe" ]; then
            # Create a wrapper script to handle spaces in the path properly
            print_verbose "Creating Git Credential Manager wrapper script..."
            mkdir -p "$HOME/bin"
            
            cat << 'EOF' > "$HOME/bin/git-credential-manager"
#!/bin/bash
exec "/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe" "$@"
EOF
            
            chmod +x "$HOME/bin/git-credential-manager"
            
            # Add ~/bin to PATH if not already there
            if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc"; then
                echo 'export PATH="$HOME/bin:$PATH" # Git credential manager wrapper' >> "$HOME/.bashrc"
            fi
            
            # Configure credential helper to use the wrapper
            git config --global credential.helper "$HOME/bin/git-credential-manager"
            print_verbose "Git configured to use Windows Git Credential Manager via wrapper script"
        else
            print_warning "Git for Windows found but git-credential-manager.exe not found"
            print_warning "You may need to update Git for Windows to get credential manager support"
        fi
        return
    fi
    
    print_status "Installing Git Credential Manager for Linux..."
    
    # Create a temporary directory for GCM installation
    GCM_TEMP_DIR=$(mktemp -d)
    
    # Get the latest release URL from the correct organization: git-ecosystem
    if [ "$QUIET_MODE" = true ]; then
        LATEST_RELEASE=$(curl -s https://api.github.com/repos/git-ecosystem/git-credential-manager/releases/latest)
        DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | grep -o "https://github.com/git-ecosystem/git-credential-manager/releases/download/.*/gcm-linux_amd64.[0-9]*.[0-9]*.[0-9]*.[0-9]*.deb" | head -n 1)
    else
        print_verbose "Fetching latest Git Credential Manager release..."
        LATEST_RELEASE=$(curl -s https://api.github.com/repos/git-ecosystem/git-credential-manager/releases/latest)
        DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | grep -o "https://github.com/git-ecosystem/git-credential-manager/releases/download/.*/gcm-linux_amd64.[0-9]*.[0-9]*.[0-9]*.[0-9]*.deb" | head -n 1)
        print_verbose "Found download URL: $DOWNLOAD_URL"
    fi
    
    # If the specific pattern didn't match, try more general patterns
    if [ -z "$DOWNLOAD_URL" ]; then
        DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | grep -o "https://github.com/git-ecosystem/git-credential-manager/releases/download/.*linux.*amd64.*\.deb" | head -n 1)
    fi
    
    # If still no URL, try parsing the browser_download_url field
    if [ -z "$DOWNLOAD_URL" ]; then
        DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | grep -o '"browser_download_url": ".*linux.*amd64.*\.deb"' | grep -o 'https://.*\.deb' | head -n 1)
    fi
    
    if [ -z "$DOWNLOAD_URL" ]; then
        print_error "Failed to find Git Credential Manager download URL"
        return 1
    fi
    
    print_verbose "Download URL: $DOWNLOAD_URL"
    
    # Download and install GCM
    if [ "$QUIET_MODE" = true ]; then
        curl -sL "$DOWNLOAD_URL" -o "$GCM_TEMP_DIR/gcm.deb" > /dev/null
        check_success "Failed to download Git Credential Manager"
        
        # Install dependencies first
        sudo apt-get install -y -qq libicu-dev > /dev/null
        
        sudo dpkg -i "$GCM_TEMP_DIR/gcm.deb" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            print_status "Fixing dependencies..."
            sudo apt-get install -f -y -qq > /dev/null
            sudo dpkg -i "$GCM_TEMP_DIR/gcm.deb" > /dev/null 2>&1
            check_success "Failed to install Git Credential Manager"
        fi
    else
        print_verbose "Downloading Git Credential Manager..."
        curl -L "$DOWNLOAD_URL" -o "$GCM_TEMP_DIR/gcm.deb"
        check_success "Failed to download Git Credential Manager"
        
        print_verbose "Installing dependencies..."
        sudo apt-get install -y libicu-dev
        
        print_verbose "Installing Git Credential Manager..."
        sudo dpkg -i "$GCM_TEMP_DIR/gcm.deb"
        if [ $? -ne 0 ]; then
            print_status "Fixing dependencies..."
            sudo apt-get install -f -y
            sudo dpkg -i "$GCM_TEMP_DIR/gcm.deb"
            check_success "Failed to install Git Credential Manager"
        fi
    fi
    
    # Configure GCM
    print_status "Configuring Git Credential Manager..."
    if command -v git-credential-manager >/dev/null 2>&1; then
        if [ "$QUIET_MODE" = true ]; then
            git-credential-manager configure > /dev/null 2>&1
        else
            git-credential-manager configure
        fi
        
        # Set credential store based on environment
        print_status "Setting up credential store..."
        if [ -n "$DISPLAY" ] && command -v gnome-keyring-daemon >/dev/null 2>&1; then
            # Use secretservice if we have a graphical environment with GNOME keyring
            git config --global credential.credentialStore secretservice
            print_status "Using secretservice credential store (GNOME Keyring)"
        elif command -v pass >/dev/null 2>&1; then
            # Use GPG/pass if available
            git config --global credential.credentialStore gpg
            print_status "Using GPG credential store"
        else
            # Fall back to plaintext store
            git config --global credential.credentialStore plaintext
            print_warning "Using plaintext credential store (credentials will be stored unencrypted)"
            print_warning "To use a more secure store, install GNOME Keyring or GPG"
        fi
        
        # Check if GCM was properly configured
        if ! git config --global credential.credentialStore >/dev/null 2>&1; then
            print_warning "Failed to set credential store. You may need to set it manually."
            print_warning "Run: git config --global credential.credentialStore [secretservice|gpg|cache|plaintext]"
        fi
    else
        print_warning "git-credential-manager command not found after installation."
        print_warning "You may need to restart your shell and run 'git-credential-manager configure' manually."
    fi
    
    # Clean up temporary files
    rm -rf "$GCM_TEMP_DIR"
    
    print_status "Git Credential Manager installed successfully."
}

# Install Homebrew
install_homebrew() {
    if [ "$INSTALL_HOMEBREW" = false ]; then
        print_status "Skipping Homebrew installation."
        return
    fi
    
    print_status "Installing Homebrew..."
    
    # Set NONINTERACTIVE for Homebrew installation
    export NONINTERACTIVE=1
    
    if [ "$QUIET_MODE" = true ]; then
        # Redirect output to suppress most of it
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /dev/null 2>&1
    else
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    check_success "Failed to install Homebrew"

    # Add Homebrew to PATH (only if not already present)
    if ! grep -q "/home/linuxbrew/.linuxbrew/bin/brew shellenv" ~/.bashrc; then
        print_status "Adding Homebrew to PATH..."
        echo >> ~/.bashrc
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
    fi
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

    # Install GCC via Homebrew
    print_status "Installing GCC..."
    if [ "$QUIET_MODE" = true ]; then
        brew install gcc -q > /dev/null 2>&1
    else
        brew install gcc
    fi
    check_success "Failed to install GCC via Homebrew"
}

# Install pyenv
install_pyenv() {
    if [ "$INSTALL_PYENV" = false ]; then
        print_status "Skipping pyenv installation."
        return
    fi
    
    # Remove existing pyenv if user chose to do so
    if [ "$REMOVE_EXISTING_PYENV" = true ] && [ -d "$LINUX_HOME/.pyenv" ]; then
        print_status "Removing existing pyenv directory..."
        rm -rf "$LINUX_HOME/.pyenv"
    fi
    
    print_status "Installing pyenv and pyenv-virtualenv..."

    # Install pyenv
    if [ "$QUIET_MODE" = true ]; then
        git clone -q https://github.com/pyenv/pyenv.git "$LINUX_HOME/.pyenv" > /dev/null
    else
        git clone https://github.com/pyenv/pyenv.git "$LINUX_HOME/.pyenv"
    fi
    check_success "Failed to clone pyenv repository"

    # Add pyenv to PATH and initialize (only if not already present)
    if ! grep -q "PYENV_ROOT" "$LINUX_HOME/.bashrc"; then
        print_verbose "Setting up pyenv in ~/.bashrc..."
        cat << 'EOF' >> "$LINUX_HOME/.bashrc"

# pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
EOF
    fi

    # For the current shell session
    export PYENV_ROOT="$LINUX_HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"

    # Install pyenv-virtualenv plugin
    if [ "$QUIET_MODE" = true ]; then
        git clone -q https://github.com/pyenv/pyenv-virtualenv.git $(pyenv root)/plugins/pyenv-virtualenv > /dev/null
    else
        git clone https://github.com/pyenv/pyenv-virtualenv.git $(pyenv root)/plugins/pyenv-virtualenv
    fi
    check_success "Failed to install pyenv-virtualenv plugin"

    # Add pyenv-virtualenv initialization to ~/.bashrc (only if not already present)
    if ! grep -q "pyenv virtualenv-init" "$LINUX_HOME/.bashrc"; then
        cat << 'EOF' >> "$LINUX_HOME/.bashrc"
eval "$(pyenv virtualenv-init -)"
EOF
    fi
    
    print_status "pyenv and pyenv-virtualenv installed successfully."
}


# Install nvm
install_nvm() {
    if [ "$INSTALL_NVM" = false ]; then
        print_status "Skipping nvm installation."
        return
    fi
    
    # Remove existing nvm if user chose to do so
    if [ "$REMOVE_EXISTING_NVM" = true ] && [ -d "$LINUX_HOME/.nvm" ]; then
        print_status "Removing existing nvm directory..."
        rm -rf "$LINUX_HOME/.nvm"
    fi
    
    print_status "Installing nvm..."

    # Get latest nvm version
    NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep 'tag_name' | cut -d'"' -f4)
    
    # Set NVM_DIR explicitly before installation
    export NVM_DIR="$LINUX_HOME/.nvm"
    mkdir -p "$NVM_DIR"
    
    # Clone nvm directly instead of using the install script
    if [ "$QUIET_MODE" = true ]; then
        git clone -q https://github.com/nvm-sh/nvm.git "$NVM_DIR" > /dev/null 2>&1
        (cd "$NVM_DIR" && git checkout -q "$NVM_VERSION" > /dev/null 2>&1)
    else
        git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"
        (cd "$NVM_DIR" && git checkout "$NVM_VERSION")
    fi
    check_success "Failed to install nvm"

    # Add nvm configuration to bashrc (only if not already present)
    if ! grep -q "NVM_DIR" "$LINUX_HOME/.bashrc"; then
        cat << EOF >> "$LINUX_HOME/.bashrc"

# nvm configuration
export NVM_DIR="$LINUX_HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOF
    fi

    # Add nvm initialization to current session
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    print_status "nvm installed successfully."
}

# Verify installations
verify_installations() {
    print_status "Verifying installations..."
    
    # Verify pyenv
    if [ "$INSTALL_PYENV" = true ]; then
        if command -v pyenv >/dev/null; then
            print_status "pyenv installation verified."
            if [ "$QUIET_MODE" = false ]; then
                pyenv --version
            fi
        else
            print_warning "pyenv not found in PATH for current session."
        fi
    fi

    # Verify nvm
    if [ "$INSTALL_NVM" = true ]; then
        if [ -f "$NVM_DIR/nvm.sh" ]; then
            print_status "nvm installation verified."
            if [ "$QUIET_MODE" = false ]; then
                nvm --version
            fi
        else
            print_warning "nvm not found in PATH for current session."
        fi
    fi
}

# Set WSL default distribution
set_wsl_default() {
    if [ "$SET_WSL_DEFAULT" = true ] && [ -d "/mnt/c" ]; then
        # Get the current WSL distribution name
        DISTRO_NAME=$(cat /etc/os-release | grep "^ID=" | cut -d'=' -f2 | tr -d '"')
        
        # Convert to proper WSL distribution name
        case "$DISTRO_NAME" in
            ubuntu) WSL_DISTRO_NAME="Ubuntu" ;;
            debian) WSL_DISTRO_NAME="Debian" ;;
            opensuse*) WSL_DISTRO_NAME="openSUSE-Leap-15.4" ;; # This may vary
            *) WSL_DISTRO_NAME="Ubuntu" ;; # Default fallback
        esac
        
        print_status "Setting $WSL_DISTRO_NAME as default WSL distribution..."
        
        # Use Windows PowerShell to set the default
        if /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command "wsl --set-default $WSL_DISTRO_NAME" >/dev/null 2>&1; then
            print_verbose "$WSL_DISTRO_NAME set as default WSL distribution."
        else
            print_warning "Failed to set default WSL distribution. You can manually set it with: wsl --set-default $WSL_DISTRO_NAME"
        fi
    fi
}

# Ask user about WSL restart if needed
prompt_wsl_restart() {
    if [ "$WSL_CONF_MODIFIED" = true ] && [ -d "/mnt/c" ]; then
        echo ""
        print_status "WSL configuration modified - restart required to apply changes."
        echo ""
        
        # Determine the correct WSL command to show
        WSL_COMMAND="wsl"
        
        # If user didn't choose to set this as default, check if we need to specify the distribution
        if [ "$SET_WSL_DEFAULT" = false ]; then
            # Get current distribution name from WSL
            CURRENT_WSL_DISTRO=$(cat /proc/version | grep -oE 'Ubuntu|Debian|Alpine|openSUSE|SUSE|Fedora|CentOS|RedHat' | head -n 1)
            if [ -z "$CURRENT_WSL_DISTRO" ]; then
                CURRENT_WSL_DISTRO="Ubuntu"  # Default fallback
            fi
            
            # Check if this distribution is currently the default
            DEFAULT_DISTRO=$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command "(wsl -l | Where-Object { $_ -match '\(Default\)' }) -replace '.*?([A-Za-z0-9-]+).*', '$1'" 2>/dev/null | tr -d '\r' | head -n 1)
            
            # If this distribution is not the default, specify it in the command
            if [ "$DEFAULT_DISTRO" != "$CURRENT_WSL_DISTRO" ]; then
                WSL_COMMAND="wsl -d $CURRENT_WSL_DISTRO"
            fi
        fi
        
        echo -e "${YELLOW}To apply the changes, please restart WSL by running:${NC}"
        echo -e "${BLUE}  wsl --shutdown${NC}"
        echo -e "${BLUE}  $WSL_COMMAND${NC}"
        echo ""
        echo -e "${YELLOW}Or simply close this terminal and open a new WSL session.${NC}"
        echo ""
        echo -e -n "${GREEN}Press Enter to continue...${NC}"
        read
    fi
}

# Print final summary
print_summary() {
    # End of sudo requirements, kill sudo keep-alive
    if [ -n "$SUDO_KEEPALIVE_PID" ]; then
        kill $SUDO_KEEPALIVE_PID 2>/dev/null || true
    fi

    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}      Installation Complete!           ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo

    echo -e "${GREEN}Installed components:${NC}"
    echo -e "- Build essentials & Git"
    
    if [ "$INSTALL_GPG_PASS" = true ]; then
        echo -e "- GPG and pass password manager"
    fi
    
    if [ "$INSTALL_PYENV" = true ]; then
        echo -e "- pyenv (Python version manager)"
    fi
    
    if [ "$INSTALL_NVM" = true ]; then
        echo -e "- nvm (Node.js version manager)"
    fi

    if [ "$INSTALL_HOMEBREW" = true ]; then
        echo -e "- Homebrew package manager"
    fi

    if [ "$USE_WINDOWS_CREDENTIALS" = true ]; then
        echo -e "- Git Credential Manager (Windows integration)"
    elif [ "$INSTALL_GCM" = true ]; then
        echo -e "- Git Credential Manager (Linux)"
    fi

    if [ -d "/mnt/c" ]; then
        echo -e "- WSL-specific configurations"
    fi

    echo
    if [ "$WSL_CONF_MODIFIED" != true ]; then
        echo -e "${YELLOW}Run 'source ~/.bashrc' or restart your terminal to apply changes.${NC}"
    fi
    
    if [ "$INSTALL_PYENV" = true ] || [ "$INSTALL_NVM" = true ]; then
        echo -e "${BLUE}Next steps:${NC}"
        if [ "$INSTALL_PYENV" = true ]; then
            echo -e "  pyenv install <version>  # Install Python"
        fi
        if [ "$INSTALL_NVM" = true ]; then
            echo -e "  nvm install <version>    # Install Node.js"
        fi
    fi
}

# Main function to orchestrate the installation
main() {
    parse_args "$@"
    detect_windows_git_config
    handle_wsl_default
    gather_user_input
    setup_sudo
    install_system_packages
    configure_git
    install_gpg_and_pass
    configure_wsl
    install_git_credential_manager
    install_homebrew
    install_pyenv
    install_nvm
    verify_installations
    set_wsl_default
    prompt_wsl_restart
    print_summary
}

# Run the main function
main "$@"
