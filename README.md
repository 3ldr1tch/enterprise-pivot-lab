# Enterprise Pivot Lab

A reproducible VirtualBox lab for learning network segmentation, tunneling, pivoting, and enterprise penetration-testing concepts using Kali Linux, Debian, and Ligolo-NG.

The project builds an isolated multi-network environment in which the attacker cannot directly communicate with internal systems. Access to those systems must instead be established through compromised, multi-homed hosts.

The lab is intended for hands-on practice with concepts such as:

* Network enumeration
* Network segmentation
* Routing
* TUN interfaces
* Ligolo-NG
* Pivoting
* Internal service enumeration
* Multi-hop pivoting
* Active Directory enumeration and attacks

> **Scope:** This project is an intentionally isolated training environment. The techniques demonstrated here should only be used against systems you own or are explicitly authorized to test.

## Lab Architecture

Scenario 01 begins with three virtual machines and two isolated VirtualBox networks.

```text
                       Internet
                          │
                    VirtualBox NAT
                          │
                  ┌───────┴───────┐
                  │     KALI      │
                  │               │
                  │  10.0.2.15    │
                  │  10.10.10.10  │
                  └───────┬───────┘
                          │
                       LAB-EXT
                    10.10.10.0/24
                          │
                  ┌───────┴───────┐
                  │     WEB01     │
                  │               │
                  │  10.10.10.20  │
                  │ 172.16.10.10  │
                  └───────┬───────┘
                          │
                       CORP-LAN
                    172.16.10.0/24
                          │
                  ┌───────┴───────┐
                  │   TARGET01    │
                  │               │
                  │ 172.16.10.20  │
                  └───────────────┘
```

### Expected connectivity

Before establishing a pivot:

| Source | Destination | Expected        |
| ------ | ----------- | --------------- |
| Kali   | WEB01       | Reachable       |
| WEB01  | TARGET01    | Reachable       |
| Kali   | TARGET01    | **Unreachable** |

Kali deliberately has no VirtualBox interface connected to `CORP-LAN`.

Its initial routing table therefore contains a route for:

```text
10.10.10.0/24
```

but no route for:

```text
172.16.10.0/24
```

Attempting to reach TARGET01 consequently sends the traffic toward Kali's default NAT gateway instead:

```console
$ ip route get 172.16.10.20

172.16.10.20 via 10.0.2.2 dev eth0 src 10.0.2.15
```

This provides the network boundary that the learner must overcome.

## Scenario 01 — Basic Pivot

The first scenario assumes access has already been obtained to WEB01.

WEB01 is dual-homed:

```text
enp0s3    10.10.10.20/24
enp0s8    172.16.10.10/24
```

Enumeration of the compromised host reveals the previously inaccessible `172.16.10.0/24` network.

A Ligolo-NG agent is then executed on WEB01 and connected to the Ligolo proxy running on Kali.

```text
KALI
  │
  │ Ligolo-NG
  ▼
WEB01
  │
  │ CORP-LAN
  ▼
TARGET01
```

Ligolo creates a TUN interface on Kali and routes traffic for the internal network through WEB01.

This allows ordinary tools on Kali to interact with internal systems without requiring SOCKS-aware applications or `proxychains`.

Examples include:

```console
nmap 172.16.10.20
curl http://172.16.10.20
ssh user@172.16.10.20
```

## Project Roadmap

### Scenario 01 — Basic Pivot

```text
Kali → WEB01 → TARGET01
```

Learn the fundamentals of routing traffic through a dual-homed Linux host.

### Scenario 02 — Double Pivot

```text
Kali
  │
WEB01
  │
CORP-LAN
  │
APP01
  │
SECURE-LAN
  │
MGMT01
```

Introduce a second inaccessible subnet requiring another pivot.

### Scenario 03 — Active Directory

Expand the internal environment with Windows infrastructure such as:

```text
DC01
WS01
MGMT01
```

Potential topics include:

* Active Directory
* DNS
* SMB
* LDAP
* Kerberos
* Service accounts
* Credential discovery
* Lateral movement
* Network segmentation

## Documentation

Detailed build instructions are maintained under [`docs/`](docs/).

The goal is not simply to provide commands to copy and paste. Each section explains why the network is configured the way it is and how to verify that the intended segmentation is actually working.

## Snapshots

VirtualBox snapshots are strongly recommended before each major stage.

Example:

```console
VBoxManage snapshot "WEB01" take "00-network-ready"
VBoxManage snapshot "TARGET01" take "00-network-ready"
```

List snapshots:

```console
VBoxManage snapshot "WEB01" list
```

Restore a snapshot:

```console
VBoxManage snapshot "WEB01" restore "00-network-ready"
```

## Status

Current implementation:

* [x] Kali attacker VM
* [x] LAB-EXT network
* [x] WEB01 dual-homed pivot
* [x] CORP-LAN network
* [x] TARGET01
* [x] Verified network segmentation
* [x] Ligolo-NG agent connection
* [ ] Complete first routed Ligolo tunnel
* [ ] Automated environment validation
* [ ] Double-pivot scenario
* [ ] Active Directory environment
* [ ] Automated lab provisioning

## Inspiration

This project is inspired by enterprise penetration-testing and pivoting exercises such as those taught by Hack The Box Academy.

It is an independently constructed training environment intended to provide a reproducible platform for practicing the underlying networking and tunneling concepts.
