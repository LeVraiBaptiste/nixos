# Homelab Architecture

## Overview

Two-host infrastructure managed declaratively with NixOS and Arion (Nix-native Docker Compose).
Deployed from desktop via `nixos-rebuild --target-host`.

## Hosts

### Server (Dell T330, 192.168.1.62)

Primary home server. Runs all local services.

| Service | Image | Purpose |
|---------|-------|---------|
| Home Assistant | `ghcr.io/home-assistant/home-assistant:stable` | Home automation |
| Jellyfin | `jellyfin/jellyfin:latest` | Media server |
| WireGuard | `linuxserver/wireguard` | VPN peer (client, connects to remote) |

### Remote (dedicated server, fixed IP)

Public-facing gateway. Provides external access.

| Service | Image | Purpose |
|---------|-------|---------|
| WireGuard | `linuxserver/wireguard` | VPN peer (server, fixed IP endpoint) |
| Caddy | `caddy:latest` | Reverse proxy, automatic HTTPS |
| Authelia | `authelia/authelia:latest` | SSO / 2FA authentication |

## Network Topology

```
Internet
  |
  v
your.domain.com --> Caddy (remote, :443)
                      |
                    Authelia (2FA check)
                      |
                    WireGuard tunnel
                      |
                      v
                Home Assistant (server, :8123)

Desktop --SSH--> server (nixos-rebuild)
Desktop --SSH--> remote  (nixos-rebuild)
```

### Roles

- **Server** is the HA server (runs Home Assistant) and VPN client (initiates tunnel from behind NAT)
- **Remote** is the VPN server (fixed public IP, accepts connections) and HA client (proxies requests to HA)

### WireGuard Tunnel

The tunnel is **bidirectional**. The client/server distinction only determines who initiates the connection:

- Server (home, behind NAT) **initiates** the connection outward
- Remote (fixed IP) **listens** and accepts it

Once established, traffic flows freely both ways on the tunnel subnet (`10.10.0.0/24`):

| Host | Tunnel IP | Role |
|------|-----------|------|
| Remote | `10.10.0.1` | VPN server, HA client (Caddy proxies to HA) |
| Server | `10.10.0.2` | VPN client, HA server (runs Home Assistant) |

Caddy on remote reverse-proxies to `10.10.0.2:8123` — this routes over the WireGuard tunnel transparently.

## Implementation Plan

### Phase 1: Arion Integration

Add Arion as a flake input and create a reusable module pattern.

1. Add `arion` to `flake.nix` inputs
2. Create `modules/arion.nix` — base Arion setup, replaces current `modules/docker.nix`
3. Define per-host service modules under `modules/services/`

File structure after this phase:

```
flake.nix
hosts/
  server.nix
  server-hardware-configuration.nix
  remote.nix
  remote-hardware-configuration.nix
modules/
  common.nix
  arion.nix              # replaces docker.nix
  shell.nix
  services/
    home-assistant.nix   # HA container definition
    jellyfin.nix         # Jellyfin container definition
    wireguard.nix        # WireGuard client/server
    caddy.nix            # reverse proxy
    authelia.nix         # authentication
```

### Phase 2: Server Services

Deploy Home Assistant and Jellyfin on the server.

1. **Home Assistant**
   - Bind-mount config to `/srv/hass/config`
   - Host network mode (required for mDNS device discovery)
   - Persist config directory across rebuilds

2. **Jellyfin**
   - Bind-mount media library (e.g. `/srv/media`)
   - Bind-mount config to `/srv/jellyfin/config`
   - Expose port 8096

3. **Firewall** — open ports for services that need LAN access (8123, 8096)

### Phase 3: Home Assistant Config Management

Track HA configuration in a **separate private GitHub repo**, independent from this homelab repo.
The homelab repo manages infrastructure (NixOS + Arion); the HA config repo tracks Home Assistant's
generated and manually edited configuration files. They have different lifecycles and commit patterns.

1. **Separate repo**: `ha-config` on GitHub (private)
   - Lives at `/srv/hass/config` on the server
   - Not linked to the homelab repo (no submodule)

2. **Manual bootstrap** (one-time, after first HA deploy):
   ```bash
   cd /srv/hass/config
   git init
   # create .gitignore (see below)
   ssh-keygen -t ed25519 -f /root/.ssh/ha-deploy-key -N ""
   # add the public key to GitHub repo as a deploy key (write access)
   git add -A && git commit -m "initial"
   git remote add origin git@github.com:<user>/ha-config.git
   git push -u origin main
   ```

3. **SSH config** for the deploy key (NixOS-managed):
   ```
   # Configured via programs.ssh or environment.etc
   Host github.com
     IdentityFile /root/.ssh/ha-deploy-key
     IdentitiesOnly yes
   ```

4. **`.gitignore`** excludes:
   - `home-assistant_v2.db` (database, large and volatile)
   - `.storage/` (internal state, regenerated)
   - `secrets.yaml` (credentials — must not be pushed)
   - `tts/`, `deps/`, `__pycache__/`

5. **Systemd timer** (NixOS-managed, not a container)
   - Runs daily: `git add -A && git commit -m "auto: $(date)" && git push`
   - Pushes to the private `ha-config` GitHub repo
   - Uses the deploy key for auth (no user credentials on server)

### Phase 4: Remote Services

Deploy VPN, reverse proxy, and auth on remote.

1. **WireGuard**
   - Site-to-site tunnel between remote and server
   - Remote is the WireGuard "server" (has fixed public IP)
   - Server is the WireGuard "client" (initiates connection from behind NAT)
   - Tunnel subnet (e.g. `10.10.0.0/24`)

2. **Caddy**
   - Terminates HTTPS for `your.domain.com`
   - Automatic certificate management via Let's Encrypt
   - Forwards authenticated requests through WireGuard to HA (`10.10.0.2:8123`)

3. **Authelia**
   - Caddy checks every request against Authelia (forward auth)
   - Supports TOTP 2FA
   - User database in a local YAML file (sufficient for single-user)
   - Session and storage config in Authelia's own volume

### Phase 5: Cameras (future)

Not in current scope. Will add Frigate + Mosquitto on server when ready.

## Data Layout

### Server

```
/srv/
  hass/
    config/          # HA configuration (git-tracked, auto-pushed to GitHub)
  jellyfin/
    config/          # Jellyfin configuration
  media/             # Media library for Jellyfin
```

### Remote

```
/srv/
  caddy/
    data/            # certificates, state
    Caddyfile        # proxy config
  authelia/
    config/          # Authelia configuration
```

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Arion over plain compose files | Single deployment path via nixos-rebuild; no manual file copying |
| HA Container over HA OS/Supervised | HA Supervised conflicts with NixOS; add-ons are just containers we manage ourselves |
| Caddy over Nginx/Traefik | Auto HTTPS, minimal config, good Authelia integration |
| WireGuard over OpenVPN | Faster, simpler, lower overhead, built into Linux kernel |
| Separate repo for HA config | Different lifecycle than infra repo; avoids auto-commit noise in homelab repo |
| Manual bootstrap over declarative secrets | One-time 2-minute setup; avoids agenix/sops-nix dependency for a single key |
