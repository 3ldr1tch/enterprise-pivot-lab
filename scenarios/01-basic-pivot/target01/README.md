# TARGET01 — Northstar CMS

TARGET01 is the internal application server used as the second-stage target in Scenario 01.

It is intentionally reachable only from the `CORP-LAN` network. Kali does not have a direct interface on this network and must reach TARGET01 through the compromised WEB01 pivot.

## Network Role

```text
KALI
10.10.10.10
     |
     | LAB-EXT
     |
WEB01
10.10.10.20
172.16.10.10
     |
     | CORP-LAN
     |
TARGET01
172.16.10.20
```

Final TARGET01 configuration:

```text
CORP-LAN    172.16.10.20/24
NAT         Disabled
```

A temporary VirtualBox NAT adapter may be enabled while provisioning the VM. It must be disabled after installation.

## Northstar CMS

TARGET01 hosts **Northstar CMS**, a fictional internal communications platform running on Apache and PHP.

Installed application:

```text
/var/www/northstar
```

Apache virtual host:

```text
/etc/apache2/sites-available/northstar.conf
```

Primary service:

```text
TCP/80    Apache HTTP Server
```

Northstar identifies itself as:

```text
Northstar CMS 2.4.1
```

The site also contains the legacy:

```text
MediaTools 1.3
```

component.

## Installation

During initial provisioning, temporarily enable a VirtualBox NAT adapter so Debian can install the required packages.

Copy this directory to TARGET01 and run:

```bash
chmod +x install.sh
sudo ./install.sh
```

The installer:

* installs Apache and PHP;
* deploys Northstar to `/var/www/northstar`;
* installs and enables the Apache virtual host;
* configures the media upload directory;
* creates the Scenario 01 flag;
* enables Apache at boot.

Verify:

```bash
systemctl is-enabled apache2
systemctl is-active apache2

curl -I http://127.0.0.1/
```

Both systemd checks should report:

```text
enabled
active
```

## Final Network Configuration

After provisioning:

1. Shut down TARGET01.
2. Disable the temporary VirtualBox NAT adapter.
3. Boot TARGET01.
4. Verify the `CORP-LAN` address remains `172.16.10.20/24`.
5. Verify Apache starts automatically.
6. Verify Northstar remains reachable through the WEB01 pivot.

TARGET01 should not require direct Internet access during normal lab operation.

## Intended Vulnerability

MediaTools 1.3 contains an intentionally vulnerable filename-validation routine.

The upload feature claims to accept:

```text
.jpg
.jpeg
.png
.gif
.pdf
```

Instead of validating the final filename extension, the legacy routine checks whether an allowed extension appears anywhere in the filename.

For example:

```text
photo.jpg       accepted
shell.php       rejected
shell.jpg.php   accepted
```

Because uploaded files are stored beneath the Apache document root and PHP execution remains enabled in that location, a filename such as `shell.jpg.php` can result in server-side PHP execution.

This vulnerability exists intentionally for the isolated Enterprise Pivot Lab.

## Scenario Objective

The intended learner path is:

```text
Pivot into CORP-LAN
        |
        v
Discover TARGET01
        |
        v
Enumerate Northstar
        |
        v
Identify MediaTools
        |
        v
Investigate upload validation
        |
        v
Bypass filename validation
        |
        v
PHP code execution
        |
        v
www-data foothold
        |
        v
Recover scenario flag
```

The flag is installed outside the web root and is readable by the Apache service account after TARGET01 has been compromised.

## Important Pivot Behavior

Routing Kali into `172.16.10.0/24` with Ligolo allows Kali to initiate connections to TARGET01.

It does **not** automatically give TARGET01 a route back to Kali's `10.10.10.10` LAB-EXT address.

For reverse connections, a Ligolo listener can be created on the WEB01 agent and redirected to a listener on Kali.

This distinction is intentional and demonstrates the difference between gaining routed access to an internal network and providing a return path from an internal target.

## Final-State Checklist

Before considering TARGET01 complete:

```text
[ ] TARGET01 has 172.16.10.20/24 on CORP-LAN
[ ] Temporary NAT adapter is disabled
[ ] Apache is enabled
[ ] Apache starts after reboot
[ ] Northstar loads on TCP/80
[ ] MediaTools upload vulnerability works
[ ] PHP executes from the uploads directory
[ ] TARGET01 is reachable from Kali only through the pivot
[ ] Ligolo listener can relay a reverse connection
[ ] Scenario flag is readable after compromise
```
