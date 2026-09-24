# TARGET01 Internal Application Server

TARGET01 is the internal application server used as the final target in Scenario 01.

It exists only on `CORP-LAN` in the completed lab and cannot be accessed directly from Kali without first establishing a pivot through WEB01.

## Role

TARGET01 provides:

* an internal-only target;
* the Northstar CMS application;
* application enumeration after pivoting;
* the intentionally vulnerable MediaTools component;
* server-side PHP execution;
* a second low-privilege foothold;
* the Scenario 01 completion flag.

## Network Configuration

TARGET01 has one permanent VirtualBox network adapter.

VirtualBox mode:

```text
Internal Network
```

Network:

```text
CORP-LAN
```

Address:

```text
172.16.10.20/24
```

WEB01 is reachable on the same network at:

```text
172.16.10.10
```

## Network Position

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

TARGET01 should not have a permanent interface on:

```text
LAB-EXT
```

or a permanent VirtualBox NAT interface.

## Provisioning

TARGET01 may temporarily require Internet access while installing packages.

A second VirtualBox adapter can temporarily be configured as NAT.

From the VirtualBox host:

```bash
VBoxManage modifyvm "TARGET01" \
  --nic2 nat \
  --cable-connected2 on
```

Boot TARGET01 and verify Internet connectivity before provisioning.

The temporary adapter is not part of the final lab topology.

## Northstar CMS Deployment

The Scenario 01 TARGET01 deployment files are stored under:

```text
scenarios/01-basic-pivot/target01/
```

The deployment includes:

```text
apache/
install.sh
README.md
www/
```

Copy the directory to TARGET01 and run:

```bash
chmod +x install.sh
sudo ./install.sh
```

The installer deploys the application and required services.

## Installed Components

The installer installs:

```text
Apache
PHP
libapache2-mod-php
```

The Northstar application is deployed to:

```text
/var/www/northstar
```

The Apache site configuration is installed as:

```text
/etc/apache2/sites-available/northstar.conf
```

The default Apache site is disabled and the Northstar site is enabled.

## Apache Service

Northstar does not require a separate `northstar.service`.

Apache is the service responsible for hosting the application.

The installer runs:

```bash
systemctl enable apache2
systemctl restart apache2
```

Verify:

```bash
systemctl is-enabled apache2
systemctl is-active apache2
```

Expected:

```text
enabled
active
```

Verify the site configuration:

```bash
ls -l /etc/apache2/sites-enabled/
```

The enabled Northstar configuration should reference:

```text
../sites-available/northstar.conf
```

## Verifying Northstar

On TARGET01:

```bash
curl http://127.0.0.1/
```

The page should identify:

```text
Northstar CMS 2.4.1
```

From WEB01:

```bash
curl http://172.16.10.20/
```

should return the same application.

After the Ligolo pivot is established, Kali should also be able to request:

```bash
curl http://172.16.10.20/
```

## Northstar Components

The application includes several fictional components.

The important Scenario 01 component is:

```text
MediaTools 1.3
```

Deployment documentation is intentionally exposed at:

```text
/README.txt
```

This provides a breadcrumb indicating that MediaTools is an older component retained for compatibility.

## Media Upload Function

MediaTools provides an upload interface at:

```text
/media/
```

Uploaded files are written beneath:

```text
/var/www/northstar/uploads/
```

The upload directory is writable by:

```text
www-data
```

The remainder of the application remains owned by root.

## Intended Vulnerability

MediaTools performs intentionally unsafe filename validation.

The application allows extensions such as:

```text
.jpg
.jpeg
.png
.gif
.pdf
```

but checks whether one of those strings appears anywhere within the filename.

It does not safely verify the final extension.

Consequently:

```text
image.jpg
```

is accepted as expected, but a filename such as:

```text
probe.jpg.php
```

is also accepted.

Because the uploads directory is served by Apache with PHP execution available, the final `.php` extension results in server-side PHP execution.

This vulnerability exists intentionally for the isolated lab.

## Harmless Validation Test

Create a PHP probe:

```bash
cat > probe.jpg.php <<'EOF'
<?php
echo "NORTHSTAR_PHP_EXECUTION_OK";
?>
EOF
```

Upload it through MediaTools.

Then request:

```text
/uploads/probe.jpg.php
```

Successful exploitation returns:

```text
NORTHSTAR_PHP_EXECUTION_OK
```

This confirms arbitrary PHP execution without requiring an interactive shell.

## Web Service Account

PHP executed through Apache runs as:

```text
www-data
```

The intended TARGET01 foothold is therefore an unprivileged `www-data` shell.

Scenario 01 does not require privilege escalation to root.

The objective is to demonstrate:

```text
pivot
    ->
internal enumeration
    ->
application compromise
    ->
internal foothold
```

## Scenario Flag

The installer creates the scenario flag beneath:

```text
/opt/northstar/flag.txt
```

The directory and file permissions allow the Apache service account to read the flag after compromise.

The flag is intentionally outside the web root.

This requires the learner to obtain code execution rather than simply request the flag over HTTP.

## Reverse Connections

TARGET01 has direct connectivity to WEB01's CORP-LAN address:

```text
172.16.10.10
```

It should not be assumed to have direct connectivity to Kali's LAB-EXT address:

```text
10.10.10.10
```

Therefore, reverse connections from TARGET01 should use the Ligolo listener running through WEB01.

The callback path is:

```text
TARGET01
172.16.10.20
     |
     | 172.16.10.10:4445
     v
WEB01
Ligolo Agent
     |
     v
Kali
127.0.0.1:4445
```

This is an intentional part of Scenario 01's networking lesson.

## Removing the Temporary NAT Adapter

After installation and testing, shut down TARGET01:

```bash
sudo poweroff
```

On the VirtualBox host:

```bash
VBoxManage modifyvm "TARGET01" \
  --nic2 none
```

Verify:

```bash
VBoxManage showvminfo "TARGET01" |
grep -iE 'NIC|Attachment|Cable'
```

The final configuration should contain CORP-LAN but no active NAT adapter.

## Post-Reboot Verification

Boot TARGET01 again.

Verify its address:

```bash
ip -br addr
```

Verify Apache:

```bash
systemctl is-enabled apache2
systemctl is-active apache2
```

Verify Northstar:

```bash
curl http://127.0.0.1/
```

From WEB01:

```bash
curl http://172.16.10.20/
```

Then establish the Ligolo pivot from Kali and verify:

```bash
nmap -Pn -sV -p 22,80 172.16.10.20
curl http://172.16.10.20/
```

This proves the application survived reboot while TARGET01 remained isolated from direct Internet access.

## Cleaning Uploaded Test Files

Development and validation may leave test payloads under:

```text
/var/www/northstar/uploads/
```

Before taking a clean scenario snapshot, remove files created during testing while preserving the upload directory itself.

For example, inspect it first:

```bash
ls -la /var/www/northstar/uploads/
```

Then remove only the known testing artifacts.

Do not remove the uploads directory.

Verify afterward:

```bash
ls -la /var/www/northstar/uploads/
```

The directory should remain writable by `www-data`.

## Useful Verification Commands

Network:

```bash
ip -br addr
ip route
```

Apache:

```bash
systemctl status apache2 --no-pager
```

Listening services:

```bash
ss -lntp
```

Northstar:

```bash
curl http://127.0.0.1/
```

Application files:

```bash
ls -la /var/www/northstar
```

Upload directory:

```bash
ls -ld /var/www/northstar/uploads
```

Flag permissions:

```bash
ls -ld /opt/northstar
ls -l /opt/northstar/flag.txt
```

## Known-Good Scenario 01 State

TARGET01 is correctly configured when:

```text
[ ] CORP-LAN address is 172.16.10.20/24
[ ] Network configuration survives reboot
[ ] Temporary NAT adapter is disabled
[ ] TARGET01 has no LAB-EXT interface
[ ] Apache is enabled at boot
[ ] Apache is active after reboot
[ ] TCP/80 exposes Northstar
[ ] Northstar CMS 2.4.1 loads correctly
[ ] MediaTools 1.3 is present
[ ] Upload validation behaves as intended
[ ] PHP executes from the uploads directory
[ ] PHP executes as www-data
[ ] Scenario flag exists outside the web root
[ ] WEB01 can directly reach TARGET01
[ ] Kali requires the Ligolo pivot to reach TARGET01
```

This represents the completed Scenario 01 TARGET01 baseline.
