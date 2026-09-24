# VirtualBox Lab Setup

This document describes the VirtualBox configuration used by the Enterprise Pivot Lab.

The lab is intentionally segmented so that the attacker cannot directly communicate with every target. Compromised systems must be used as pivots to reach otherwise inaccessible network segments.

## Design Goals

The VirtualBox environment is designed to provide:

* an attacker system with Internet access;
* an externally reachable lab network;
* an isolated internal corporate network;
* dual-homed systems capable of acting as pivot points;
* internal targets that cannot communicate directly with the attacker;
* temporary Internet access for provisioning without permanently weakening network isolation.

The current Scenario 01 topology contains three virtual machines:

```text
KALI
WEB01
TARGET01
```

## VirtualBox Networks

Scenario 01 uses two VirtualBox Internal Networks and one VirtualBox NAT connection.

### NAT

VirtualBox NAT provides Internet access to Kali.

Kali uses NAT for:

* package installation;
* updates;
* downloading tools;
* normal Internet connectivity.

Example Kali NAT addressing:

```text
eth0
10.0.2.15/24
gateway 10.0.2.2
```

The exact NAT address may vary depending on VirtualBox configuration.

TARGET01 and WEB01 may temporarily use NAT while being provisioned, but provisioning adapters should be removed or disabled before the lab is considered complete.

### LAB-EXT

`LAB-EXT` is the attacker-facing lab network.

Type:

```text
VirtualBox Internal Network
```

Network:

```text
10.10.10.0/24
```

Current hosts:

```text
KALI      10.10.10.10
WEB01     10.10.10.20
```

Kali can communicate directly with WEB01 through this network.

TARGET01 is not attached to LAB-EXT.

### CORP-LAN

`CORP-LAN` represents an internal corporate network.

Type:

```text
VirtualBox Internal Network
```

Network:

```text
172.16.10.0/24
```

Current hosts:

```text
WEB01       172.16.10.10
TARGET01    172.16.10.20
```

Kali is not attached directly to CORP-LAN.

WEB01 is attached to both LAB-EXT and CORP-LAN, making it the pivot point between the two networks.

## Scenario 01 Adapter Layout

The intended final configuration is:

| VM       | Adapter   | VirtualBox Mode  | Network        | Address         |
| -------- | --------- | ---------------- | -------------- | --------------- |
| Kali     | Adapter 1 | NAT              | VirtualBox NAT | DHCP            |
| Kali     | Adapter 2 | Internal Network | LAB-EXT        | 10.10.10.10/24  |
| WEB01    | Adapter 1 | Internal Network | LAB-EXT        | 10.10.10.20/24  |
| WEB01    | Adapter 2 | Internal Network | CORP-LAN       | 172.16.10.10/24 |
| TARGET01 | Adapter 1 | Internal Network | CORP-LAN       | 172.16.10.20/24 |

The important security boundary is:

```text
Kali does NOT have a VirtualBox adapter on CORP-LAN.
```

Without a pivot, Kali should therefore have no direct path to TARGET01.

## Creating LAB-EXT

VirtualBox Internal Networks are created implicitly when an adapter is configured to use them.

For the Kali LAB-EXT adapter:

1. Shut down the Kali VM.
2. Open the VM's VirtualBox settings.
3. Select **Network**.
4. Enable the second adapter.
5. Set **Attached to** to `Internal Network`.
6. Set the network name to:

```text
LAB-EXT
```

7. Ensure **Cable Connected** is enabled.

Configure WEB01 with an adapter attached to the same exact network name.

Internal Network names are case-sensitive for practical lab configuration purposes. Use consistent naming across every VM.

## Creating CORP-LAN

Configure another VirtualBox Internal Network named:

```text
CORP-LAN
```

WEB01 and TARGET01 should both have adapters attached to this network.

Kali should not.

The resulting relationship is:

```text
KALI
  |
  | LAB-EXT
  |
WEB01
  |
  | CORP-LAN
  |
TARGET01
```

## Configuring Adapters with VBoxManage

VirtualBox networking can also be configured from the host CLI.

For example, configuring TARGET01's first adapter for CORP-LAN:

```bash
VBoxManage modifyvm "TARGET01" \
  --nic1 intnet \
  --intnet1 "CORP-LAN" \
  --cable-connected1 on
```

A temporary NAT adapter can be added during provisioning:

```bash
VBoxManage modifyvm "TARGET01" \
  --nic2 nat \
  --cable-connected2 on
```

The VM must normally be powered off before modifying its adapter configuration.

After provisioning, remove the temporary NAT adapter:

```bash
VBoxManage modifyvm "TARGET01" \
  --nic2 none
```

## Verifying VirtualBox Configuration

From the host, inspect a VM with:

```bash
VBoxManage showvminfo "TARGET01"
```

To focus on network configuration:

```bash
VBoxManage showvminfo "TARGET01" |
grep -iE 'NIC|Attachment|Cable'
```

TARGET01's final configuration should show an adapter attached to:

```text
Internal Network 'CORP-LAN'
```

and no active NAT adapter.

Similar checks can be performed for Kali and WEB01:

```bash
VBoxManage showvminfo "Kali"
VBoxManage showvminfo "WEB01"
```

Use the actual VirtualBox VM names if they differ.

## Temporary Provisioning Adapters

Internal targets may require Internet access during initial installation.

For example, TARGET01's installer requires Debian packages for Apache and PHP.

Rather than permanently connecting the internal server to NAT, a temporary NAT adapter can be enabled.

The provisioning workflow is:

```text
Power off VM
     |
     v
Enable temporary NAT
     |
     v
Boot VM
     |
     v
Install packages/application
     |
     v
Verify installation
     |
     v
Power off VM
     |
     v
Disable temporary NAT
     |
     v
Boot isolated VM
     |
     v
Verify application still works
```

This keeps the final topology consistent with the intended attack path.

## Host Isolation

VirtualBox **Internal Network** mode differs from **Host-Only Adapter** mode.

An Internal Network connects participating virtual machines to one another but does not automatically connect the host operating system to that network.

As a result, the Garuda host should not be expected to directly reach:

```text
10.10.10.20
172.16.10.20
```

simply because those addresses exist inside the VirtualBox lab.

Kali serves as the attack platform and primary interface into the lab.

## Verifying the Final Topology

From Kali, WEB01 should be directly reachable:

```bash
ping -c 2 10.10.10.20
```

TARGET01 should not initially be reachable through CORP-LAN.

Before establishing the pivot, inspect Kali's routing table:

```bash
ip route
```

There should not be a legitimate lab route similar to:

```text
172.16.10.0/24 dev <interface>
```

After the Ligolo pivot is established, Kali should gain:

```text
172.16.10.0/24 dev ligolo-web01
```

This difference demonstrates that access to CORP-LAN is being provided by the pivot rather than by the underlying VirtualBox configuration.

## Final Scenario 01 Topology

```text
                     Internet
                        |
                 VirtualBox NAT
                        |
                      KALI
                 NAT: DHCP
               LAB-EXT: 10.10.10.10
                        |
                        |
                     LAB-EXT
                  10.10.10.0/24
                        |
                        |
                      WEB01
               LAB-EXT: 10.10.10.20
               CORP-LAN: 172.16.10.10
                        |
                        |
                    CORP-LAN
                 172.16.10.0/24
                        |
                        |
                    TARGET01
                 172.16.10.20
```

This topology forms the networking foundation for Scenario 01 and provides the first pivot point for later scenarios.
