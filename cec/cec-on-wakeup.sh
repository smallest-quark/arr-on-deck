#!/bin/bash

# clear the connection
/usr/bin/cec-ctl -C

# establish the connection
/usr/bin/cec-ctl --playback
/usr/bin/cec-ctl --to 0 --image-view-on
sleep 5

# set to HDMI2 (TODO: adapative)
/usr/bin/cec-ctl --to 0 --active-source phys-addr=2.0.0.0
/usr/bin/cec-ctl -C
