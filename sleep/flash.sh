#!/bin/bash
HEXFILE="$1"
avrdude -c pizero -p t45 -P /dev/spidev0.0 -U flash:w:${HEXFILE}
