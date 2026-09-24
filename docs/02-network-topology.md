# Enterprise Pivot Lab — Network Topology

The Enterprise Pivot Lab models a segmented network in which compromising one system reveals access to networks that were not reachable from the attacker's starting position.

The network is deliberately designed around routing and trust boundaries rather than placing every VM on a single flat subnet.

## Scenario 01 Topology

```text
                         Internet
                            |
                            |
                     VirtualBox NAT
                            |
                            |
                          KALI
                  ┌───────────────────┐
                  │ NAT: DHCP         │
                  │ LAB-EXT           │
                  │ 10.10.10.10       │
                  └─────────┬─────────┘
                            |
                            |
                       LAB-EXT
                    10.10.10.0/24
                            |
                            |
                          WEB01
                  ┌───────────────────┐
                  │ 10.10.10.20       │
                  │                   │
                  │ 172.16.10.10      │
                  └─────────┬─────────┘
                            |
                            |
                       CORP-LAN
                   172.16.10.0/24
                            |
                            |
                        TARGET01
                  ┌───────────────────┐
                  │ 172.16.10.20      │
                  └───────────────────┘
```

## Addressing Plan

| System   | Interface Role     | Address         | Network        |
| -------- | ------------------ | --------------- | -------------- |
| Kali     | Internet/NAT       | DHCP            | VirtualBox NAT |
| Kali     | Attacker lab       | 10.10.10.10/24  | LAB-EXT        |
| WEB01    | External lab       | 10.10.10.20/24  | LAB-EXT        |
| WEB01    | Internal corporate | 172.16.10.10/24 | CORP-LAN       |
| TARGET01 | Internal corporate | 172.16.10.20/24 | CORP-LAN       |

## LAB-EXT

Network:

```text
10.10.10.0/24
```

Purpose:

```text
Attacker-facing network
```

Members:

```text
KALI      10.10.10.10
WEB01     10.10.10.20
```

This represents the network visible from the attacker's initial position.

Kali can directly enumerate and attack WEB01.

TARGET01 does not have an interface on LAB-EXT.

## CORP-LAN

Network:

```text
172.16.10.0/24
```

Purpose:

```text
Internal corporate network
```

Members:

```text
WEB01       172.16.10.10
TARGET01    172.16.10.20
```

Kali does not have a physical or virtual interface attached to this network.

The attacker must first compromise WEB01 and then use it as a pivot to reach CORP-LAN.

## WEB01

WEB01 is the first pivot host.

Addresses:

```text
10.10.10.20/24
172.16.10.10/24
```

Its dual-homed configuration is central to the scenario.

From the attacker's perspective:

```text
Before WEB01 compromise:

Kali ──────────────> WEB01

Kali ───── X ─────> TARGET01
```

After compromising WEB01, local network enumeration reveals its second interface and the previously unknown `172.16.10.0/24` network.

WEB01 therefore changes the attacker's understanding of the environment.

## TARGET01

TARGET01 is an internal-only server.

Address:

```text
172.16.10.20/24
```

It hosts the fictional:

```text
Northstar CMS 2.4.1
```

web application.

TARGET01 is not connected to LAB-EXT.

Its final configuration also does not include a VirtualBox NAT adapter.

As a result, the intended attack path requires WEB01.

## Initial Attacker Visibility

At the beginning of Scenario 01, Kali knows about:

```text
10.10.10.0/24
```

and can reach:

```text
10.10.10.20
```

Kali does not initially have a lab route to:

```text
172.16.10.0/24
```

The attacker's initial view is therefore approximately:

```text
KALI
 |
 +---- 10.10.10.20 WEB01
```

The existence of CORP-LAN is discovered only after compromising and enumerating WEB01.

## Network Discovery After WEB01 Compromise

Running:

```bash
ip -br addr
```

on WEB01 reveals both network interfaces.

Running:

```bash
ip route
```

reveals the directly connected:

```text
172.16.10.0/24
```

network.

The attacker's updated view becomes:

```text
KALI
 |
 +---- WEB01
          |
          +---- 172.16.10.0/24
```

Enumeration through WEB01 then reveals TARGET01.

## Pivoting with Ligolo-NG

Ligolo-NG is used to provide Kali with routed access to CORP-LAN.

The Ligolo proxy runs on Kali.

The Ligolo agent runs on the compromised WEB01 host.

Conceptually:

```text
KALI
Ligolo Proxy
     |
     | LAB-EXT
     |
WEB01
Ligolo Agent
     |
     | CORP-LAN
     |
172.16.10.0/24
```

After creating the Ligolo TUN interface, Kali receives a route similar to:

```text
172.16.10.0/24 dev ligolo-web01
```

This allows tools on Kali to address internal systems normally:

```bash
ping 172.16.10.20
curl http://172.16.10.20/
nmap -Pn 172.16.10.20
```

The applications themselves do not need to be configured to use a SOCKS proxy.

## Routing Versus Reverse Connectivity

An important property of this topology is that routed access through Ligolo is not the same as providing TARGET01 with a route back to every Kali network.

After the pivot:

```text
Kali → TARGET01
```

works.

However:

```text
TARGET01 → 10.10.10.10
```

does not automatically work.

TARGET01 only has direct access to CORP-LAN.

WEB01's address on that network is:

```text
172.16.10.10
```

A reverse connection can therefore be handled with a Ligolo listener.

Conceptually:

```text
TARGET01
172.16.10.20
     |
     | callback
     v
WEB01
172.16.10.10:4445
     |
     | Ligolo listener
     v
Ligolo Proxy
     |
     v
Kali
127.0.0.1:4445
```

This distinction is intentionally preserved in the lab because it demonstrates a common pivoting concept:

```text
Being able to reach a network does not imply that systems
on that network can initiate connections directly back to
every interface on the attacker's machine.
```

## Scenario 01 Attack Path

The complete Scenario 01 network progression is:

```text
KALI
 |
 | Direct LAB-EXT access
 v
WEB01
 |
 | Command injection
 v
opscheck shell
 |
 | Interface and route enumeration
 v
Discover CORP-LAN
 |
 | Ligolo-NG
 v
172.16.10.0/24
 |
 | Internal enumeration
 v
TARGET01
 |
 | Northstar MediaTools vulnerability
 v
PHP execution
 |
 | Callback to WEB01
 v
Ligolo listener
 |
 v
www-data shell
```

## Trust Boundaries

Scenario 01 contains two primary network boundaries.

### Boundary 1 — LAB-EXT

Kali has direct access to LAB-EXT.

WEB01 is exposed to this network.

This represents the initial attack surface.

### Boundary 2 — CORP-LAN

Kali has no direct VirtualBox attachment to CORP-LAN.

WEB01 and TARGET01 share this network.

Compromising WEB01 crosses this boundary by providing the attacker with a system that has legitimate network access to both sides.

## Why WEB01 Is Not a Router

WEB01 is dual-homed, but the scenario does not rely on configuring it as a conventional Linux IP router.

Instead, Ligolo creates the attacker-controlled path.

This is an important distinction.

The attack is not:

```text
Enable IP forwarding on WEB01
Add static gateway routes
Route Kali through WEB01 normally
```

Instead:

```text
Compromise WEB01
        |
        v
Run Ligolo agent
        |
        v
Create TUN route on Kali
        |
        v
Ligolo transports traffic through the agent
```

This better represents the use of a post-compromise tunneling tool.

## Isolation Requirements

The topology is considered correctly configured when:

```text
Kali can directly reach WEB01.

WEB01 can directly reach TARGET01.

Kali cannot reach TARGET01 through a normal VirtualBox
interface.

Kali can reach TARGET01 after establishing the Ligolo pivot.

TARGET01 does not require direct Internet access.
```

If Kali can reach `172.16.10.20` before establishing the pivot, the network configuration should be investigated.

## Future Expansion

The addressing scheme leaves room for additional internal networks.

For example:

```text
                         KALI
                           |
                        LAB-EXT
                           |
                         WEB01
                           |
                       CORP-LAN
                      /        \
               TARGET01       APP01
                                |
                              MGMT-LAN
                                |
                               DB01
```

A future scenario could introduce another subnet such as:

```text
MGMT-LAN
172.16.20.0/24
```

with a second dual-homed target:

```text
APP01
172.16.10.x
172.16.20.x
```

The attacker would then need to compromise APP01 and establish another pivot to reach the management network.

This allows the lab to expand progressively without changing the basic Scenario 01 architecture.
