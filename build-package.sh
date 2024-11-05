#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

set -e

# Function to log messages
log() {
    local level=$1
    shift
    echo -e "${level}$*${NC}"
}

# Function to check required commands
check_requirements() {
    local required_commands=("gpg" "debuild" "dh_make" "rsync")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log "${RED}" "Error: Required command '$cmd' not found."
            log "${YELLOW}" "Installing required packages..."
            sudo apt-get update && sudo apt-get install -y \
                devscripts \
                debhelper \
                dh-make \
                gnupg \
                rsync
            break
        fi
    done
}

# Function to check GPG key
check_gpg_key() {
    local email="$1"
    if ! gpg --list-secret-keys "$email" > /dev/null 2>&1; then
        log "${YELLOW}" "No GPG key found for $email"
        log "${YELLOW}" "Generating new GPG key..."
        
        # Generate GPG key with better security parameters
        gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $DEBFULLNAME
Name-Email: $DEBEMAIL
Expire-Date: 0
%no-protection
%commit
EOF
        
        log "${GREEN}" "GPG key generated successfully"
        
        # Export public key
        log "${YELLOW}" "Exporting public key..."
        gpg --armor --export "$email" > ~/public_key.asc
        log "${GREEN}" "Public key exported to ~/public_key.asc"
        log "${YELLOW}" "Please upload this key to your Launchpad account:"
        echo "1. Go to: https://launchpad.net/~/+editpgpkeys"
        echo "2. Copy content of ~/public_key.asc"
        echo "3. Click 'Import Public Key'"
    fi
}

# Function to validate package version
validate_version() {
    local version="$1"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "${RED}" "Invalid version format. Please use semantic versioning (e.g., 1.0.0)"
        exit 1
    fi
}

# Main script starts here
log "${YELLOW}" "Starting build process..."

# Check requirements first
check_requirements

# Set maintainer details
log "${YELLOW}" "Setting up maintainer details..."
read -p "Enter your full name: " DEBFULLNAME
read -p "Enter your email: " DEBEMAIL
read -p "Enter package version (e.g., 1.0.0): " VERSION

validate_version "$VERSION"

export DEBFULLNAME
export DEBEMAIL

# Check/Create GPG key
check_gpg_key "$DEBEMAIL"

# Create build directory
BUILD_DIR=~/stackops-build
log "${YELLOW}" "Creating build directory at ${BUILD_DIR}"

# Clean old build directory if it exists
if [ -d "$BUILD_DIR" ]; then
    log "${YELLOW}" "Cleaning old build directory..."
    rm -rf "$BUILD_DIR"
fi

# Create fresh build directory and set permissions
log "${YELLOW}" "Setting up build directory..."
mkdir -p "$BUILD_DIR"
sudo chown -R $USER:$USER "$BUILD_DIR"
chmod -R 755 "$BUILD_DIR"

# Copy files (excluding .git and other unnecessary files)
log "${YELLOW}" "Copying files to build directory..."
rsync -av --exclude={'.git','.gitignore','*.pyc','__pycache__','*.deb','*.changes','*.build','*.buildinfo'} . "$BUILD_DIR/"

# Change to build directory
cd "$BUILD_DIR"

# Create debian files
log "${YELLOW}" "Creating debian files..."

# Create necessary directories
mkdir -p debian/source debian/stackops

# Create control file
cat > debian/control << EOL
Source: stackops
Section: admin
Priority: optional
Maintainer: $DEBFULLNAME <$DEBEMAIL>
Build-Depends: debhelper-compat (= 13),
               dh-python,
               python3-all,
               python3-setuptools
Standards-Version: 4.6.2
Homepage: https://github.com/anksji/stackops
Rules-Requires-Root: no

Package: stackops
Architecture: all
Depends: \${python3:Depends},
         \${misc:Depends},
         python3-click (>= 7.0),
         nginx (>= 1.18.0),
         certbot,
         python3-certbot-nginx
Description: Server Operations Automation Tool
 A comprehensive tool for automating server setup and configuration tasks.
 .
 Features:
  * Initial server setup with security configurations
  * Nginx installation and configuration
  * SSL certificate setup with Let's Encrypt
  * Docker installation and configuration
  * GitHub Actions Runner setup
EOL

# Create rules file with improved error handling
cat > debian/rules << 'EOL'
#!/usr/bin/make -f

export PYBUILD_NAME=stackops
export PYBUILD_SYSTEM=distutils
export DH_VERBOSE=1

%:
	dh $@ --with python3 --buildsystem=pybuild

# Skip tests
override_dh_auto_test:

override_dh_auto_install:
	dh_auto_install

override_dh_install:
	dh_install
	# Ensure scripts from src/stackops/scripts are properly installed
	if [ -d src/stackops/scripts ] && [ -n "$(ls -A src/stackops/scripts 2>/dev/null)" ]; then \
		chmod 755 debian/stackops/usr/lib/python3/dist-packages/stackops/scripts/*.sh || true; \
	fi

override_dh_installdocs:
	dh_installdocs README.md || true

override_dh_fixperms:
	dh_fixperms

override_dh_clean:
	dh_clean
	rm -rf build/ *.egg-info/
EOL

chmod 755 debian/rules

cat > debian/install << 'EOL'
src/stackops usr/lib/python3/dist-packages/
EOL

# Create changelog with proper version
cat > debian/changelog << EOL
stackops ($VERSION) noble; urgency=medium

  * Release version $VERSION
  * Features included:
    - Server initialization
    - Nginx configuration
    - SSL certificate setup
    - Docker installation
    - GitHub Actions Runner setup

 -- $DEBFULLNAME <$DEBEMAIL>  $(date -R)
EOL

# Create source format
echo "3.0 (native)" > debian/source/format

# Create copyright file
cat > debian/copyright << EOL
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: stackops
Source: https://github.com/anksji/stackops

Files: *
Copyright: $(date +%Y) $DEBFULLNAME <$DEBEMAIL>
License: MIT
 Permission is hereby granted, free of charge, to any person obtaining a
 copy of this software and associated documentation files (the "Software"),
 to deal in the Software without restriction, including without limitation
 the rights to use, copy, modify, merge, publish, distribute, sublicense,
 and/or sell copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following conditions:
 .
 The above copyright notice and this permission notice shall be included
 in all copies or substantial portions of the Software.
 .
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
EOL

# Set proper permissions
log "${YELLOW}" "Setting proper permissions..."
chmod -R 755 debian
find debian -type f -exec chmod 644 {} \;
chmod 755 debian/rules


# Build source package
log "${YELLOW}" "Building source package..."
dpkg-buildpackage -S -sa --no-sign

if [ $? -eq 0 ]; then
    log "${GREEN}" "Build successful!"
    log "${YELLOW}" "Generated files:"
    ls -l ../stackops_*
    
    # Copy files to original location
    log "${YELLOW}" "Copying files back to original directory..."
    ORIG_DIR=$(pwd | sed 's|/stackops-build.*||')
    cp ../stackops_* "$ORIG_DIR/"
    
    # Sign the package
    log "${YELLOW}" "Signing the package..."
    cd ..
    if debsign -k "$DEBEMAIL" stackops_1.0.2_source.changes; then
        log "${GREEN}" "Package signed successfully!"
    else
        log "${RED}" "Package signing failed. Try signing manually with:"
        echo "cd $ORIG_DIR"
        echo "debsign -k $DEBEMAIL stackops_1.0.2_source.changes"
    fi
    
    log "${GREEN}" "Build complete! Files are in: $ORIG_DIR"
    echo -e "\nNext steps:"
    echo "1. If signing failed, sign manually with: debsign -k $DEBEMAIL $ORIG_DIR/stackops_1.0.2_source.changes"
    echo "2. Upload to PPA with: dput ppa:your-launchpad-username/ppa $ORIG_DIR/stackops_1.0.2_source.changes"
else
    log "${RED}" "Build failed!"
    exit 1
fi