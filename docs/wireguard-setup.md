# WireGuard Setup

Manual steps required after deploying the NixOS configs.

## Topology

```
            Remote (203.0.113.10)
            Hub WireGuard (10.10.0.1:51820)
            ip_forward=1
              │         │
           Desktop    Server
           10.10.0.2   10.10.0.3
```

- **Remote**: WireGuard hub with public IP, routes traffic between peers
- **Desktop**: WG client, direct peer (`persistentKeepalive=25`, behind NAT)
- **Server**: WG client, direct peer (`persistentKeepalive=25`, behind NAT)
- **Laptop/Phone**: no WireGuard — access services via SSH ProxyJump or HTTPS (Caddy on Remote)

## 1. Generate keys

On **each host** (remote, server, desktop):

```bash
sudo mkdir -p /etc/wireguard
wg genkey | sudo tee /etc/wireguard/private.key | wg pubkey | sudo tee /etc/wireguard/public.key
sudo chmod 600 /etc/wireguard/private.key
```

## 2. Exchange public keys

Insert each host's public key into the NixOS configs:

| Key from | Insert into | Placeholder |
|----------|-------------|-------------|
| `desktop` | `hosts/remote/default.nix` | `REPLACE_WITH_DESKTOP_PUBLIC_KEY` |
| `server` | `hosts/remote/default.nix` | `REPLACE_WITH_SERVER_PUBLIC_KEY` |
| `remote` | `hosts/desktop/default.nix` | `REPLACE_WITH_REMOTE_PUBLIC_KEY` |
| `remote` | `hosts/server/default.nix` | `REPLACE_WITH_REMOTE_PUBLIC_KEY` |

## 3. Deploy

Order matters to minimize downtime:

```bash
# 1. Desktop first (adds WG, harmless — Remote doesn't know it yet)
sudo nixos-rebuild switch --flake /etc/nixos#desktop

# 2. Remote second (updates peer list — Server tunnel breaks momentarily)
sudo nixos-rebuild switch --flake /etc/nixos#remote --target-host bat@203.0.113.10 --sudo --ask-sudo-password

# 3. Server third (from LAN — Server moves to .3, tunnel re-establishes)
sudo nixos-rebuild switch --flake /etc/nixos#server --target-host bat@192.168.1.62 --sudo --ask-sudo-password

# 4. Laptop last (removes WG config, purely subtractive)
sudo nixos-rebuild switch --flake /etc/nixos#laptop
```

## 4. Verify tunnel

From **remote**:

```bash
sudo wg show        # should list 2 peers (Desktop, Server)
ping 10.10.0.2      # reaches desktop
ping 10.10.0.3      # reaches server
```

From **desktop**:

```bash
sudo wg show
ping 10.10.0.1      # reaches remote
ping 10.10.0.3      # reaches server via remote
```

From **server**:

```bash
sudo wg show
ping 10.10.0.1      # reaches remote
ping 10.10.0.2      # reaches desktop via remote
```

## 5. Verify Caddy

```bash
curl http://203.0.113.10    # should return HA login page (proxied to 10.10.0.3:8123)
```

## 6. SSH access from Laptop/Phone

No WireGuard needed — use SSH ProxyJump through Remote:

```bash
# Direct jump
ssh -J bat@203.0.113.10 bat@10.10.0.2    # → Desktop
ssh -J bat@203.0.113.10 bat@10.10.0.3    # → Server
```

Or add to `~/.ssh/config`:

```
Host remote
  HostName 203.0.113.10
  User bat

Host desktop
  HostName 10.10.0.2
  User bat
  ProxyJump remote

Host server
  HostName 10.10.0.3
  User bat
  ProxyJump remote
```

## 7. Wake-on-LAN

Desktop can be woken via Server (always on, same LAN):

```bash
ssh server "wol <desktop-mac-address>"
```

## 8. Split DNS (manual, outside NixOS)

For services to resolve correctly everywhere:

1. **DNS public** (registrar/Cloudflare): `ha.yourdomain.com A 203.0.113.10`
2. **DNS local** (router host override): `ha.yourdomain.com → 192.168.1.62`

On LAN, traffic goes directly to Server. Externally, it goes through Remote's Caddy → WG tunnel → Server.
