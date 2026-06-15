#!/bin/sh
# NetworkManager dispatcher script — auto-toggle WireGuard
# Active WG quand on quitte le LAN, le désactive quand on revient
# Détection basée sur la gateway par défaut (192.168.1.1 = maison)
if [ "$2" = "up" ] || [ "$2" = "down" ]; then
  if ip route | grep -q "default via 192.168.1.1"; then
    wg-quick down wg0 2>/dev/null || true
  else
    wg-quick up wg0 2>/dev/null || true
  fi
fi
