#!/bin/bash
# Dynamic IPMI fan control for Dell T330
# Adjusts fan speed based on CPU temperature, restores auto control on exit/high temps

set -euo pipefail

IPMITOOL="${IPMITOOL:-ipmitool}"

cleanup() {
  echo "Restoring Dell automatic fan control"
  "$IPMITOOL" raw 0x30 0x30 0x01 0x01
  exit 0
}
trap cleanup SIGTERM SIGINT EXIT

# Thresholds (°C) and corresponding fan speeds (%)
# Must be sorted ascending; temps above the last threshold restore auto control
TEMPS=(25 30 35 40)
SPEEDS=(1  5  10 15)

INTERVAL=30

while true; do
  TEMP=$("$IPMITOOL" sdr type temperature | grep '3\.1' | head -n1 | awk -F'|' '{print $5}' | awk '{print $1}' | cut -d'.' -f1 || true)

  if [ -z "$TEMP" ]; then
    echo "Warning: could not read CPU temperature — restoring auto control"
    "$IPMITOOL" raw 0x30 0x30 0x01 0x01
    sleep "$INTERVAL"
    continue
  fi

  PWM=""
  for i in "${!TEMPS[@]}"; do
    if [ "$TEMP" -lt "${TEMPS[$i]}" ]; then
      PWM="${SPEEDS[$i]}"
      echo "CPU ${TEMP}°C (<${TEMPS[$i]}) — fans at ${PWM}%"
      break
    fi
  done

  if [ -z "$PWM" ]; then
    echo "CPU ${TEMP}°C (>=${TEMPS[-1]}) — restoring auto control"
    "$IPMITOOL" raw 0x30 0x30 0x01 0x01
    sleep "$INTERVAL"
    continue
  fi

  # Enable manual mode and set fan speed
  "$IPMITOOL" raw 0x30 0x30 0x01 0x00
  HEX=$(printf '0x%02x' "$PWM")
  "$IPMITOOL" raw 0x30 0x30 0x02 0xff "$HEX"

  sleep "$INTERVAL"
done
