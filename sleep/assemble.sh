#!/bin/bash
ASMFILE="$1"
HEXFILE="${ASMFILE%.asm}.hex"
avra -fI -I /usr/share/avra -o $HEXFILE $ASMFILE
