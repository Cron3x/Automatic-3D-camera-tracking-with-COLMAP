#!/bin/env sh

# Folder layout in command
# root
#  ├ example_scripts
#  │  └ >this_file< (script launches from here)
#  └ docker-build
#     └ target
#        └ >contains the elf and libraries< (can be downloaded in the release page)

../automate.sh -c -V ~/Videos/colmap-solve -F /usr/bin/ffmpeg -C ../docker-build/target/colmap -img-size 1024 -libs "$(pwd)/../docker-build/target"
