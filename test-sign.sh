#!/bin/bash
PASSPHRASE='$jaishriram2hanumansang@'  # Replace with your actual passphrase
echo -n "$PASSPHRASE" > ~/.passphrase
chmod 600 ~/.passphrase

# Create test file
echo "test" > test.txt

# Sign test file
passphrase=$(cat ~/.passphrase)
gpg --batch \
    --pinentry-mode loopback \
    --passphrase-fd 3 \
    --default-key "73568F87EABEBCABAD83052F1458F88B1ACD3597" \
    --detach-sign \
    --armor \
    test.txt \
    3< <(echo -n "$passphrase")

# Check result
if [ -f "test.txt.asc" ]; then
    echo "Signing successful!"
else
    echo "Signing failed!"
fi

# Clean up
rm -f ~/.passphrase
EOF