# WEB01 — OpsCheck

WEB01 is the initial foothold and first pivot host for Scenario 01 of the Enterprise Pivot Lab.

It is a dual-homed Debian system running **OpsCheck**, an intentionally vulnerable internal network-diagnostics application.

> **Warning:** OpsCheck intentionally contains a command-injection vulnerability. Deploy it only inside an isolated lab environment.

## Network Role

WEB01 connects the attacker-accessible `LAB-EXT` network to the otherwise unreachable `CORP-LAN` network.

```text
KALI
10.10.10.10
     |
     | LAB-EXT
     | 10.10.10.0/24
     |
WEB01
10.10.10.20
172.16.10.10
     |
     | CORP-LAN
     | 172.16.10.0/24
     |
TARGET01
172.16.10.20
```

The intended attack path is:

```text
Kali
  |
  | enumerate
  v
WEB01 :8080
  |
  | exploit OpsCheck command injection
  v
opscheck@WEB01
  |
  | enumerate network interfaces
  v
discover 172.16.10.0/24
  |
  | establish Ligolo-NG pivot
  v
CORP-LAN
  |
  | enumerate
  v
TARGET01
```

## VirtualBox Network Configuration

WEB01 uses two permanent VirtualBox network adapters.

| Adapter   | Mode             | Network    | WEB01 Address     |
| --------- | ---------------- | ---------- | ----------------- |
| Adapter 1 | Internal Network | `LAB-EXT`  | `10.10.10.20/24`  |
| Adapter 2 | Internal Network | `CORP-LAN` | `172.16.10.10/24` |

During initial provisioning only, enable a third adapter:

| Adapter   | Mode | Purpose                   |
| --------- | ---- | ------------------------- |
| Adapter 3 | NAT  | Temporary Internet access |

Adapter 3 is used to download Debian packages and Python dependencies.

**Disable Adapter 3 after provisioning. It is not part of the final challenge topology.**

## Application

OpsCheck is a small Flask application exposed on:

```text
TCP/8080
```

The application is installed under:

```text
/opt/opscheck
```

and runs through Gunicorn as the dedicated unprivileged account:

```text
opscheck
```

The service is managed by:

```text
opscheck.service
```

## Installation

Before installation, make sure WEB01 has temporary Internet access through VirtualBox Adapter 3 configured as NAT.

Verify connectivity as appropriate before continuing.

From the `web01` directory:

```bash
chmod +x install.sh
sudo ./install.sh
```

The installer:

1. Installs the required Debian packages.
2. Creates the `opscheck` system account.
3. Creates `/opt/opscheck`.
4. Copies the application and templates.
5. Creates a Python virtual environment.
6. Installs Flask and Gunicorn.
7. Installs `opscheck.service`.
8. Enables and starts the service.

## Verify the Installation

Check that the service is enabled:

```bash
systemctl is-enabled opscheck
```

Expected:

```text
enabled
```

Check that it is running:

```bash
systemctl is-active opscheck
```

Expected:

```text
active
```

Test the local health endpoint:

```bash
curl http://127.0.0.1:8080/health
```

Expected:

```json
{"service":"opscheck","status":"ok","version":"1.0.3"}
```

From Kali:

```bash
curl http://10.10.10.20:8080/health
```

The same health response should be returned.

## Remove Provisioning Access

After installation and verification:

1. Shut down WEB01.
2. Open its VirtualBox network settings.
3. Disable **Adapter 3 (NAT)**.
4. Boot WEB01 again.

The final challenge machine should have only:

```text
LAB-EXT
10.10.10.20/24

CORP-LAN
172.16.10.10/24
```

WEB01 should not have direct Internet access.

Verify the final network configuration:

```bash
ip -br addr
ip route
```

Then confirm OpsCheck survived the change:

```bash
systemctl is-active opscheck
curl http://127.0.0.1:8080/health
```

From Kali:

```bash
curl http://10.10.10.20:8080/health
```

## Intended Vulnerability

The diagnostics functionality intentionally passes user-controlled input to a shell command.

For lab validation, submitting:

```text
127.0.0.1; id
```

should execute the additional command.

The returned identity should be the restricted service account rather than the administrative user:

```text
uid=...(opscheck) gid=...(opscheck)
```

This vulnerability provides the initial foothold for Scenario 01.

The learner is expected to use the foothold to enumerate WEB01, discover its second network interface, identify the hidden `172.16.10.0/24` network, and establish a pivot into `CORP-LAN`.

## Final Sta
