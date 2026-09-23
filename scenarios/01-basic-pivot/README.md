# Scenario 01 — Basic Pivot

## Overview

Scenario 01 introduces network pivoting through a compromised dual-homed Linux host.

The attacker begins on Kali with access to the external lab network but no route into the internal corporate network.

The objective is to enumerate the exposed environment, obtain an initial foothold, identify additional network connectivity, establish a pivot, and reach the internal target.

## Network Topology

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

Kali has no interface directly connected to `CORP-LAN`.

WEB01 is the only system connected to both networks.

## Starting Position

The learner begins from Kali.

Known information:

```text
Attacker: 10.10.10.10
Target:   10.10.10.20
```

Administrative credentials for WEB01 and TARGET01 are not part of the challenge and should not be used to complete the scenario.

## Objective

Starting from Kali:

1. Enumerate WEB01.
2. Identify and investigate exposed services.
3. Obtain command execution on WEB01.
4. Establish a low-privilege foothold.
5. Enumerate WEB01's network configuration.
6. Identify a network that Kali cannot directly reach.
7. Establish a pivot through WEB01.
8. Enumerate the internal target.
9. Compromise TARGET01.
10. Recover the final flag.

## Rules

The scenario is intended to be completed entirely inside the isolated lab environment.

Do not enable additional network adapters or add a direct Kali route/interface to `CORP-LAN`.

WEB01 should have no permanent NAT adapter or direct Internet access during the challenge.

The intended route to the internal network is through the compromised WEB01 host.

## Success Criteria

The scenario is complete when the learner can demonstrate:

* Initial enumeration of WEB01.
* Remote command execution through the exposed application.
* A low-privilege shell on WEB01.
* Discovery of the internal network.
* A working pivot into `CORP-LAN`.
* Enumeration of TARGET01 through that pivot.
* Recovery of the final TARGET01 flag.

## Current Build Status

The following portions of the scenario are implemented:

* [x] Kali attacker network
* [x] WEB01 dual-homed configuration
* [x] OpsCheck vulnerable web application
* [x] Command-injection foothold
* [x] Low-privilege `opscheck` execution context
* [x] Internal-network discovery
* [x] Ligolo-NG pivot
* [x] Kali access to TARGET01 through WEB01
* [ ] TARGET01 vulnerable service
* [ ] TARGET01 exploitation path
* [ ] Final flag

## Components

### WEB01

WEB01 hosts the intentionally vulnerable OpsCheck diagnostics application.

Provisioning instructions are located in:

```text
web01/README.md
```

### TARGET01

TARGET01 resides exclusively on `CORP-LAN` and cannot be directly reached from Kali before establishing a pivot.

Its challenge service and final objective are implemented separately under:

```text
target01/
```

### Solution

A complete walkthrough is maintained under:

```text
solution/WALKTHROUGH.md
```

The solution contains spoilers and should not be consulted when attempting the scenario as a challenge.

