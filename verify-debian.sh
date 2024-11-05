#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Creating and verifying debian files...${NC}"

# Create debian directory if it doesn't exist
mkdir -p debian

# Remove compat file if it exists
rm -f debian/compat

# Create rules file
cat > debian/rules << 'EOL'
#!/usr/bin/make -f

export PYBUILD_NAME=stackops
export PYBUILD_SYSTEM=distutils

%:
	dh $@ --with python3 --buildsystem=pybuild

override_dh_auto_install:
	dh_auto_install
	mkdir -p debian/stackops/usr/share/stackops/scripts
	cp -r scripts/* debian/stackops/usr/share/stackops/scripts/ || true

override_dh_installdocs:
	dh_installdocs README.md

override_dh_fixperms:
	dh_fixperms
	chmod 755 debian/stackops/usr/share/stackops/scripts/*.sh || true
EOL

# Make rules executable
chmod +x debian/rules

# Create control file
cat > debian/control << 'EOL'
Source: stackops
Section: admin
Priority: optional
Maintainer: Ankitraj Dwivedi <ankitrajatwork@gmail.com.com>
Build-Depends: debhelper-compat (= 13),
               dh-python,
               python3-all,
               python3-setuptools
Standards-Version: 4.5.1
Homepage: https://github.com/anksji/stackops
Rules-Requires-Root: no

Package: stackops
Architecture: all
Depends: ${python3:Depends},
         ${misc:Depends},
         python3-click,
         nginx,
         certbot,
         python3-certbot-nginx
Description: Server Operations Automation Tool
 A tool for automating server setup and configuration tasks.
 .
 Features:
  * Initial server setup with security configurations
  * Nginx installation and configuration
  * SSL certificate setup with Let's Encrypt
  * Docker installation and configuration
  * GitHub Actions Runner setup
EOL

# Create changelog
cat > debian/changelog << 'EOL'
stackops (1.0.0) unstable; urgency=medium

  * Initial release
  * Features included:
    - Server initialization
    - Nginx configuration
    - SSL certificate setup
    - Docker installation
    - GitHub Actions Runner setup

 -- Ankitraj Dwivedi <ankitrajatwork@gmail.com.com>  Mon, 04 Nov 2024 12:00:00 +0000
EOL

# Create copyright file
cat > debian/copyright << 'EOL'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: stackops
Source: https://github.com/anksji/stackops

Files: *
Copyright: 2024 Ankitraj Dwivedi <ankitrajatwork@gmail.com.com>
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

# Create source format file
mkdir -p debian/source
echo "3.0 (native)" > debian/source/format

# Clean previous builds
rm -f ../stackops_*

# Verify all files
echo -e "\n${YELLOW}Verifying created files:${NC}"
for file in rules control changelog copyright source/format; do
    if [ -f "debian/$file" ]; then
        echo -e "${GREEN}✓ debian/$file exists${NC}"
    else
        echo -e "${RED}✗ debian/$file is missing${NC}"
    fi
done

# Check rules file permissions
if [ -x "debian/rules" ]; then
    echo -e "${GREEN}✓ debian/rules is executable${NC}"
else
    echo -e "${RED}✗ debian/rules is not executable${NC}"
fi

echo -e "\n${YELLOW}Files in debian directory:${NC}"
ls -la debian/

echo -e "\n${GREEN}Verification complete!${NC}"
echo "You can now run: dpkg-buildpackage -S -sa"