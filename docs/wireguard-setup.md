# WireGuard Setup

Manual steps required after deploying the NixOS configs.

## Topology

```
         Remote (203.0.113.10)
         WG hub (10.10.0.1:51820)
         ip_forward=1
        ╱       │        ╲
  Laptop      Server      Phone
  10.10.0.3   10.10.0.2   10.10.0.4
              │
              │ LAN masquerade
              │
           Desktop (192.168.1.10)
           Sunshine
```

- **Remote**: WireGuard hub, routes traffic between peers
- **Server**: always-on WG client, relays traffic to home LAN via masquerade
- **Laptop**: WG client, auto-toggles based on network (LAN = off, external = on)
- **Phone**: WG client via Android app, manual toggle
- **Desktop**: no WireGuard — accessed directly on LAN or via Server masquerade

## 1. Generate keys

On **each host** (remote, server, laptop):

```bash
sudo mkdir -p /etc/wireguard
wg genkey | sudo tee /etc/wireguard/private.key | wg pubkey | sudo tee /etc/wireguard/public.key
sudo chmod 600 /etc/wireguard/private.key
```

For the **phone**, generate keys on any machine:

```bash
wg genkey | tee phone-private.key | wg pubkey > phone-public.key
```

## 2. Exchange public keys

Insert each host's public key into the NixOS configs:

| Key from | Insert into | Placeholder |
|----------|-------------|-------------|
| `server` | `hosts/remote/default.nix` | `<server-public-key>` |
| `laptop` | `hosts/remote/default.nix` | `<laptop-public-key>` |
| `phone` | `hosts/remote/default.nix` | `<phone-public-key>` |
| `remote` | `hosts/server/default.nix` | `<remote-public-key>` |
| `remote` | `config/laptop/wg0.conf` | `<remote-public-key>` |

Also insert the laptop's private key into `config/laptop/wg0.conf` (replace `<contenu de /etc/wireguard/private.key>`).

## 3. Verify server LAN interface name

On the **server**, check the network interface name:

```bash
ip link
```

Update `networking.nat.externalInterface` in `hosts/server/default.nix` if it differs from `eno1`.

## 4. Deploy

```bash
# From desktop
sudo nixos-rebuild switch --flake /etc/nixos#remote --target-host bat@203.0.113.10 --sudo --ask-sudo-password
sudo nixos-rebuild switch --flake /etc/nixos#server --target-host bat@192.168.1.62 --sudo --ask-sudo-password
sudo nixos-rebuild switch --flake /etc/nixos#laptop
```

## 5. Verify tunnel

From **remote**:

```bash
sudo wg show        # should list all 3 peers
ping 10.10.0.2      # reaches server through tunnel
```

From **server**:

```bash
sudo wg show
ping 10.10.0.1      # reaches remote through tunnel
```

From **laptop** (on external network):

```bash
sudo wg show         # should show active tunnel (auto-enabled by dispatcher)
ping 10.10.0.1       # reaches remote
ping 192.168.1.10    # reaches desktop via server masquerade
```

## 6. Phone setup (Android)

Create the WireGuard config file for the phone:

```ini
[Interface]
Address = 10.10.0.4/24
PrivateKey = <phone-private-key>
DNS = 1.1.1.1

[Peer]
PublicKey = <remote-public-key>
Endpoint = 203.0.113.10:51820
AllowedIPs = 10.10.0.0/24, 192.168.1.0/24
PersistentKeepalive = 25
```

Export as QR code (requires `qrencode`):

```bash
qrencode -t ansiutf8 < phone-wg.conf
```

Scan the QR code in the WireGuard Android app.

## 7. Verify Caddy

From **remote** (or any machine):

```bash
curl http://203.0.113.10
```

Should return the Home Assistant login page (proxied through the tunnel to `10.10.0.2:8123`).

## 8. Split DNS (manual, outside NixOS)

For `desktop.url.com` to resolve correctly everywhere:

1. **DNS public** (registrar/Cloudflare): `desktop.url.com A 203.0.113.10`
2. **DNS local** (router host override): `desktop.url.com → 192.168.1.10`

In LAN, the router resolves to the desktop directly. Externally, it resolves to the remote (requires WireGuard active to reach the desktop through the tunnel).
