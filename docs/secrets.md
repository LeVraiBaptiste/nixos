# Secrets (sops-nix)

Secrets are encrypted with [sops](https://github.com/getsops/sops) + age in `secrets/*.yaml`
and committed. Non-secret shared values (LAN/WireGuard IPs, ports, public keys) live in `vars.nix`.

At activation, sops-nix decrypts them on the target host with its SSH host key into
`/run/secrets/` (tmpfs). They never land in the Nix store. Templates rendered from them
(env files, Authelia users file) are in `/run/secrets/rendered/`.

## Recipients (`.sops.yaml`)

Any one of these keys can decrypt:

| Key     | Location                                         |
|---------|--------------------------------------------------|
| desktop | `~/.config/sops/age/keys.txt` on the desktop     |
| backup  | offline (password manager)                       |
| laptop  | `~/.config/sops/age/keys.txt` on the laptop (`private/` only) |
| server  | `/etc/ssh/ssh_host_ed25519_key` on the server    |

## Common tasks

```sh
# Edit secrets (decrypts in $EDITOR, re-encrypts on save)
sops secrets/server.yaml

# Add a recipient (new laptop, reinstalled server): add its age key to .sops.yaml, then
sops updatekeys secrets/server.yaml

# Age key of a host from its SSH key
ssh-keyscan -t ed25519 <host> | ssh-to-age

# Personal age key for a new machine
age-keygen -o ~/.config/sops/age/keys.txt
```

After editing, add the new key in `hosts/server/default.nix` (`sops.secrets`) if it is
new, then rebuild the server. Changed secrets restart `docker-compose.service`.

## Personal values (`private/`)

The domain, public IP, git identities and emails are not secrets, but they stay out of
the public repo. Nix needs them at **evaluation** time (Caddy vhosts, networkd, git
config), before sops-nix runs, so they can't go through `/run/secrets`.

- `private/vars.yaml`: sops-encrypted (desktop, laptop, backup keys), merged over `vars.nix`
- `private/example/vars.json`: placeholders, the default `private` flake input
- `scripts/rebuild.sh` decrypts the first into `$XDG_RUNTIME_DIR` and runs
  `nixos-rebuild --override-input private path:<dir>`. Built with the placeholders,
  every host fails an assertion.

```sh
sops private/vars.yaml   # edit
```

A new key must exist in both files (`example/vars.json` too, with a fake value).

## Recovery

- **Desktop lost**: use the backup key (`SOPS_AGE_KEY_FILE=backup.txt sops ...`) from any
  machine, or decrypt on the server as root. Add a new personal key and `sops updatekeys`.
- **Server reinstalled**: its host key changed. Replace its age key in `.sops.yaml`,
  `sops updatekeys`, redeploy.
