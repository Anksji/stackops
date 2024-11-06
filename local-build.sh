#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf build/ *.egg-info/ .pybuild/ debian/.debhelper/ debian/stackops/ debian/files
find . -name "*.pyc" -delete
find . -name "__pycache__" -delete

echo -e "${YELLOW}Installing build dependencies...${NC}"
sudo apt-get update
sudo apt-get install -y \
    python3-all \
    python3-setuptools \
    python3-pip \
    dh-python \
    debhelper \
    build-essential \
    python3-dev

echo -e "${YELLOW}Setting up debian directory...${NC}"
# Fix debian directory permissions
sudo chown -R $(whoami):$(whoami) debian/
sudo chmod -R 755 debian/
sudo find debian/ -type f -exec chmod 644 {} \;
sudo chmod 755 debian/rules

# Ensure debian/install has correct content and permissions
echo "src/stackops usr/lib/python3/dist-packages/" > debian/install
sudo chmod 644 debian/install

echo -e "${YELLOW}Verifying debian files...${NC}"
ls -la debian/
cat debian/install

echo -e "${YELLOW}Building package...${NC}"
DH_VERBOSE=1 PYBUILD_VERBOSE=1 dpkg-buildpackage -us -uc -b --no-sign

if [ -f "../stackops_"*".deb" ]; then
    echo -e "${GREEN}Build successful! Generated packages:${NC}"
    ls -l ../*.deb
    read -p "Do you want to install the package locally? (y/n) " answer
    if [ "$answer" = "y" ]; then
        sudo dpkg -i ../stackops_*.deb
        sudo apt-get install -f
    fi
else
    echo -e "${RED}No .deb package was created. Check the build output for errors.${NC}"
fi