# Kali Attack Host

Kali is the attacker workstation for the Enterprise Pivot Lab.

It provides Internet access for tooling while maintaining a dedicated interface on the attacker-facing `LAB-EXT` network.

Kali is deliberately **not** connected directly to internal networks such as `CORP-LAN`.

## Role

Kali provides:

* network reconnaissance;
* web enumeration;
* exploit development and testing;
* reverse-shell listeners;
* Ligolo-NG proxy functionality;
* routed access to internal networks after a pivot is established.

Scenario 01 uses the following topology:

```text
                    Internet
                       |
                VirtualBox NAT
                       |
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

## VirtualBox Configuration

Kali requires two VirtualBox network adapters.

### Adapter 1 — NAT

Purpose:

```text
Internet access
```

VirtualBox mode:

```text
NAT
```

The address is normally assigned by VirtualBox DHCP.

An example configuration is:

```text
10.0.2.15/24
```

with a default gateway such as:

```text
10.0.2.2
```

### Adapter 2 — LAB-EXT

Purpose:

```text
Enterprise Pivot Lab attacker network
```

VirtualBox mode:

```text
Internal Network
```

Network name:

```text
LAB-EXT
```

Static address:

```text
10.10.10.10/24
```

No default gateway should be configured on this interface.

## Configuring LAB-EXT
