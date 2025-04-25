#!/bin/bash

echo 80 | sudo tee /sys/class/hwmon/hwmon3/max_battery_charge_level
