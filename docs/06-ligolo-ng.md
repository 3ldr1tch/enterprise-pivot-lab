# Pivoting with Ligolo-NG

At this stage, the lab contains two network segments:

```text
                       LAB-EXT
                    10.10.10.0/24

     KALI                               WEB01
  10.10.10.10 ───────────────────── 10.10.10.20
                                           │
                                      172.16.10.10
                                           │
                                           │
                                      CORP-LAN
                                   172.16.10.0/24
                                           │
                                           │
                                      172.16.10.20
                                        TARGET01
```

Kali can communicate directly with WEB01 over `LAB-EXT`, but it has no interface attached to `CORP-LAN`.

WEB01 is dual-homed and can communicate with both networks.

The objective is to use WEB01 as a pivot so that tools running on Kali can communicate with systems on `172.16.10.0/24`.

This exercise uses **Ligolo-NG**.

---

## 1. Verify the Network Boundary

Before creating the tunnel, verify that Kali does not already have access to the internal network.

On Kali:

```console
$ ip route

default via 10.0.2.2 dev eth0
10.0.2.0/24 dev eth0
10.10.10.0/24 dev eth1
```

There should be no route for:

```text
172.16.10.0/24
```

Check how Kali would currently attempt to reach TARGET01:

```console
$ ip route get 172.16.10.20
172.16.10.20 via 10.0.2.2 dev eth0 src 10.0.2.15
```

Because Kali does not know about `CORP-LAN`, the destination falls through to the default route.

Attempts to communicate directly with TARGET01 should fail.

This verifies that the network segmentation is functioning as intended.

---

## 2. Install Ligolo-NG

On Kali:

```bash
sudo apt update
sudo apt install ligolo-ng
```

The Kali package provides two important binaries:

```text
/usr/bin/ligolo-proxy
/usr/bin/ligolo-agent
```

Verify:

```bash
which ligolo-proxy
which ligolo-agent
```

The roles are:

```text
Kali       → ligolo-proxy
WEB01      → ligolo-agent
```

The proxy remains on the attack system while the agent executes on the pivot host.

---

## 3. Start the Ligolo Proxy

Ligolo needs permission to create TUN interfaces and modify routing on Kali.

Start the proxy with elevated privileges:

```bash
sudo ligolo-proxy -selfcert
```

A successful launch should include:

```text
Listening on 0.0.0.0:11601
```

The default Ligolo agent listener therefore uses:

```text
TCP/11601
```

> **Lab note:** `-selfcert` is convenient for an isolated training environment because it generates a self-signed certificate. A production penetration test should use certificate and infrastructure choices appropriate to the engagement.

Leave the proxy running.

---

## 4. Transfer the Agent to WEB01

From another Kali terminal:

```bash
scp /usr/bin/ligolo-agent debian@10.10.10.20:/tmp/agent
```

Connect to WEB01:

```bash
ssh debian@10.10.10.20
```

Make the agent executable:

```bash
chmod +x /tmp/agent
```

Because `/tmp` may be cleared during a reboot, the agent may need to be copied again after restarting WEB01.

---

## 5. Connect WEB01 to Kali

From WEB01:

```bash
/tmp/agent -connect 10.10.10.10:11601 -ignore-cert
```

`10.10.10.10` is Kali's address on `LAB-EXT`.

Because this lab uses the proxy's self-signed certificate, the agent is instructed to ignore certificate validation.

The Ligolo console on Kali should report an incoming agent:

```text
Agent joined.
```

---

## 6. Select the Agent

At the Ligolo console:

```text
ligolo-ng » session
```

Select the WEB01 session.

The prompt should change to something similar to:

```text
[Agent : debian@Web01] »
```

We can now query the interfaces visible from WEB01:

```text
[Agent : debian@Web01] » ifconfig
```

In this lab, WEB01 reports:

```text
enp0s3    10.10.10.20/24
enp0s8    172.16.10.10/24
```

This is an important enumeration result.
