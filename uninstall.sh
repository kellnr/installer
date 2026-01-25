#!/bin/bash

# Uninstall Kellnr

set -e

CONFIG_FILE="/etc/kellnr/kellnr.toml"
CONFIG_DIR="/etc/kellnr"
SERVICE_FILE="/etc/systemd/system/kellnr.service"

# Find kellnr binary
KELLNR_BIN=$(command -v kellnr 2>/dev/null || true)

if [ -z "$KELLNR_BIN" ]; then
    echo "ERROR: Cannot find kellnr binary. Is kellnr installed?"
    exit 1
fi

echo "Found kellnr binary: $KELLNR_BIN"

# Get data directory from config
if [ -f "$CONFIG_FILE" ]; then
    DATA_DIR=$("$KELLNR_BIN" -c "$CONFIG_FILE" config show 2>/dev/null | grep "^data_dir" | cut -d'"' -f2)
else
    # Try without config file (uses defaults/env vars)
    DATA_DIR=$("$KELLNR_BIN" config show 2>/dev/null | grep "^data_dir" | cut -d'"' -f2)
fi

if [ -z "$DATA_DIR" ]; then
    echo "WARNING: Could not determine data directory"
fi

echo ""
echo "The following will be removed:"
echo "==============================="
echo ""

echo "Binary:        $KELLNR_BIN"

if [ -f "$CONFIG_FILE" ]; then
    echo "Config file:   $CONFIG_FILE"
fi

if [ -d "$CONFIG_DIR" ]; then
    echo "Config dir:    $CONFIG_DIR"
fi

if [ -n "$DATA_DIR" ] && [ -d "$DATA_DIR" ]; then
    echo "Data dir:      $DATA_DIR"
fi

if [ -f "$SERVICE_FILE" ]; then
    echo "Systemd:       $SERVICE_FILE"
fi

echo ""
echo "==============================="
echo ""

read -p "Do you want to proceed with uninstallation? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo ""

# Stop and disable systemd service
if [ -f "$SERVICE_FILE" ]; then
    echo "Stopping and disabling kellnr service..."
    sudo systemctl stop kellnr 2>/dev/null || true
    sudo systemctl disable kellnr 2>/dev/null || true
    sudo rm -f "$SERVICE_FILE"
    sudo systemctl daemon-reload
    echo "Removed kellnr service"
fi

# Remove data directory
if [ -n "$DATA_DIR" ] && [ -d "$DATA_DIR" ]; then
    echo "Removing data directory: $DATA_DIR"
    sudo rm -rf "$DATA_DIR"
fi

# Remove config directory
if [ -d "$CONFIG_DIR" ]; then
    echo "Removing config directory: $CONFIG_DIR"
    sudo rm -rf "$CONFIG_DIR"
fi

# Remove kellnr binary
echo "Removing kellnr binary: $KELLNR_BIN"
sudo rm -f "$KELLNR_BIN"

echo ""
echo "Kellnr has been uninstalled."
