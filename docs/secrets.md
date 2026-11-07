# Secrets (sops-nix)

Secrets are encrypted with [sops](https://github.com/getsops/sops) + age in `secrets/*.yaml`
and committed. Non-secret shared values (domain, IPs, ports, public keys) live in `vars.nix`.

At activation, sops-nix decrypts them on the target host with its SSH host key into
`/run/secrets/` (tmpfs). They never land in the Nix store. Templates rendered from them
(env files, Authelia users file) are in `/run/secrets/rendered/`.

## Recipients (`.sops.yaml`)

Any one of these keys can decrypt:

| Key     | Location                                         |
|---------|--------------------------------------------------|
| desktop | `~/.config/sops/age/keys.txt` on the desktop     |
| backup  | offline (password manager)                       |
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

## Recovery

- **Desktop lost**: use the backup key (`SOPS_AGE_KEY_FILE=backup.txt sops ...`) from any
  machine, or decrypt on the server as root. Add a new personal key and `sops updatekeys`.
- **Server reinstalled**: its host key changed. Replace its age key in `.sops.yaml`,
  `sops updatekeys`, redeploy.
