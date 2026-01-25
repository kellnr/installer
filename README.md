# Installer for Kellnr

Installer scripts for [Kellnr](https://kellnr.io), the private Cargo crate registry for Rust.

For full documentation see: [kellnr.io - docs](https://kellnr.io/documentation)

## Quick Install

```bash
curl -sSL https://github.com/kellnr-org/installer/releases/latest/download/install.sh | bash
```

### With systemd service

```bash
curl -sSL https://github.com/kellnr-org/installer/releases/latest/download/install.sh | bash -s -- -s
```

### Install specific version

```bash
curl -sSL https://github.com/kellnr-org/installer/releases/download/v1.0.0/install.sh | bash -s -- -s
```

## CLI Options

| Flag | Description |
|------|-------------|
| `-s` | Create systemd service |
| `-i <path>` | Install directory (default: `/usr/local/bin`) |
| `-d <path>` | Data directory (default: `/var/lib/kellnr`) |
| `-v <version>` | Install specific Kellnr version |
| `-p <password>` | Set admin password |
| `-t <token>` | Set Cargo access token |
| `-m` | Use musl (static) binary |
| `-h` | Show help |

### Example with custom paths

```bash
curl -sSL https://github.com/kellnr-org/installer/releases/latest/download/install.sh | bash -s -- -s -d /data/kellnr -i /opt/bin
```

## Uninstall

```bash
curl -sSL https://github.com/kellnr-org/installer/releases/latest/download/uninstall.sh | bash
```

## Requirements

- Linux (x86_64, aarch64, or armv7)
- `curl`, `unzip`, `sed`, `lscpu`
- Root privileges (for default paths)

## Default Paths

| Path | Description |
|------|-------------|
| `/usr/local/bin/kellnr` | Binary location |
| `/etc/kellnr/kellnr.toml` | Configuration file |
| `/var/lib/kellnr` | Data directory |
| `/etc/systemd/system/kellnr.service` | Systemd service |
