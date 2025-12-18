#!/bin/env sh

# Folder layout
# root
# |
# | git-repo
# |   example_scripts
# |     >this_file< (script launches from here)
# |
# | colmap-portable
# |   >colmap executable<
#

../automate.sh -c -V ~/Videos/colmap-solve -F /usr/bin/ffmpeg -C ../docker-build/target/colmap -img-size 1024 -libs "$(pwd)/../docker-build/target"
