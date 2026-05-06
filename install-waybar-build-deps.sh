#!/usr/bin/env bash
# Install build dependencies for waybar from source.
set -euo pipefail

sudo apt install -y \
    meson ninja-build pkg-config scdoc gettext g++ \
    libgtkmm-3.0-dev libjsoncpp-dev libsigc++-2.0-dev \
    libfmt-dev libspdlog-dev libwayland-dev libpulse-dev \
    libdbusmenu-gtk3-dev libnl-3-dev libnl-genl-3-dev \
    libupower-glib-dev libudev-dev libevdev-dev \
    libxkbcommon-dev libxkbregistry-dev libgtk-layer-shell-dev \
    libgirepository1.0-dev gobject-introspection \
    libplayerctl-dev libmpdclient-dev catch2
