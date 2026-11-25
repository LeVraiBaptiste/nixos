#!/usr/bin/env bash
# Nebula CA and host certificates (see docs/nebula-setup.md).
#
#   scripts/nebula-cert.sh init               create the CA (once), copy ca.crt into nebula/
#   scripts/nebula-cert.sh sign <host> <pub>  sign a host's public key into nebula/<host>.crt
#
# The CA key stays on this workstation, encrypted with a passphrase, outside the repo
# ($NEBULA_CA_DIR, default ~/.config/nebula). Never copy it to a host: whoever holds it
# can join the mesh as anyone. IPs and groups come from vars.nebula in vars.nix.
set -euo pipefail

repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
ca_dir=${NEBULA_CA_DIR:-$HOME/.config/nebula}
out=$repo/nebula

nebula_cert() {
  if command -v nebula-cert >/dev/null; then
    nebula-cert "$@"
  else
    nix shell nixpkgs#nebula -c nebula-cert "$@"
  fi
}

case ${1:-} in
  init)
    if [ -e "$ca_dir/ca.key" ]; then
      echo "CA already exists in $ca_dir" >&2
      exit 1
    fi
    mkdir -p "$ca_dir" "$out"
    chmod 700 "$ca_dir"
    # v1 certificates: IPv4 only, but understood by every client (Mobile Nebula included).
    # 10 years: host certificates cannot outlive the CA.
    nebula_cert ca -name homelab -version 1 -duration 87600h -encrypt \
      -out-key "$ca_dir/ca.key" -out-crt "$ca_dir/ca.crt"
    cp "$ca_dir/ca.crt" "$out/ca.crt"
    git -C "$repo" add nebula/ca.crt
    echo "CA created. Back up $ca_dir/ca.key (and its passphrase) somewhere offline."
    ;;

  sign)
    host=${2:?usage: $0 sign <host> <public key file>}
    pub=${3:?usage: $0 sign <host> <public key file>}
    entry=$(nix eval --json --file "$repo/vars.nix" "nebula.hosts.$host") || {
      echo "no vars.nebula.hosts.$host in vars.nix" >&2
      exit 1
    }
    ip=$(jq -r .ip <<<"$entry")
    groups=$(jq -r '.groups | join(",")' <<<"$entry")

    rm -f "$out/$host.crt" "$out/$host.png"
    nebula_cert sign -ca-crt "$ca_dir/ca.crt" -ca-key "$ca_dir/ca.key" \
      -name "$host" -networks "$ip/24" -groups "$groups" \
      -in-pub "$pub" -out-crt "$out/$host.crt" -out-qr "$out/$host.png"
    # Flakes only see tracked files
    git -C "$repo" add "nebula/$host.crt"
    echo "Signed nebula/$host.crt ($ip, groups: $groups). QR code for the phone app: nebula/$host.png (not committed)"
    ;;

  *)
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
