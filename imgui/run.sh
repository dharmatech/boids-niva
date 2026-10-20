#!/bin/sh
# Native Wayland, so GNOME's 2x scale applies. (Under XWayland with
# xwayland-native-scaling, GLFW ignores Xft.dpi and the window is half size.)
#
# Title bar: libdecor's GTK plugin refuses to run off the main thread, and
# the JVM never runs main there. The cairo plugin works:
#   sudo apt install libdecor-0-plugin-1-cairo
# Without it there's no title bar; Esc or Alt+F4 quits.
cd "$(dirname "$0")" && exec niva run "$@"
