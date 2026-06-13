# WireGuard Setup

Manual steps required after deploying the NixOS configs.

## 1. Generate keys

On **each host** (remote and server):

```bash
sudo mkdir -p /etc/wireguard
wg genkey | sudo tee /etc/wireguard/private.key | wg pubkey | sudo tee /etc/wireguard/public.key
sudo chmod 600 /etc/wireguard/private.key
```

## 2. Exchange public keys

Copy the public key from each host and paste it into the other's NixOS config:

- `cat /etc/wireguard/public.key` on **server** → paste into `hosts/remote.nix` (`<server-public-key>`)
- `cat /etc/wireguard/public.key` on **remote** → paste into `hosts/server.nix` (`<remote-public-key>`)

## 3. Deploy

```bash
# From desktop
sudo nixos-rebuild switch --flake .#remote --target-host bat@203.0.113.10 --sudo --ask-sudo-password
sudo nixos-rebuild switch --flake .#server --target-host bat@192.168.1.62 --sudo --ask-sudo-password
```

## 4. Verify tunnel

From **remote**:

```bash
sudo wg show        # should list the peer with a handshake
ping 10.10.0.2      # reaches server through tunnel
```

From **server**:

```bash
sudo wg show
ping 10.10.0.1      # reaches remote through tunnel
```

## 5. Verify Caddy

From **remote** (or any machine):

```bash
curl http://203.0.113.10
```

Should return the Home Assistant login page (proxied through the tunnel to `10.10.0.2:8123`).

## Tunnel topology

```
remote (203.0.113.10)          server (192.168.1.62)
  wg0: 10.10.0.1       <---->     wg0: 10.10.0.2
  Caddy :80/:443  --tunnel-->      Home Assistant :8123
```

Server initiates the connection (behind NAT, keepalive 25s). Remote listens on UDP 51820.
