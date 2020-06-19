# DuckDns update script

Dynamic DNS updater for [duckdns.org](https://www.duckdns.org) on linux. Automatically send your ipaddress to [duckdns.org](https://www.duckdns.org).

## Script to update [DuckDns.org](https://www.duckdns.org) Ip Address

This script can update one or more ip addresses with the free service [duckdns.org](https://www.duckdns.org)

Script will only update [duckdns.org](https://www.duckdns.org) when the local public ip address changes.

## Setup

### Files

#### Token file

This script requires that you set up a token file in your home directory `~/.duckdns/token` that contains the value of your token from your [duckdns.org](https://www.duckdns.org) account.

You can see your token value when you log into the home page of your [duckdns.org](https://www.duckdns.org) account as show in *figure 1.*

**Figure 1:** Get select your token from [duckdns.org](https://www.duckdns.org)
![Get token value from duckdns.org](https://i.postimg.cc/VN0V8Zxj/token-outlined.png)

Once your have your token you can create your token by running the following in a terminal window. Be sure and replace `77507db2-4f07-42d0-8554-bd90aec3ab83` with your actual token value.

```bash
mkdir -p ~/.duckdns && touch ~/.duckdns/token && echo '77507db2-4f07-42d0-8554-bd90aec3ab83' > ~/.duckdns/token && chmod 0600 ~/.duckdns/token
```

**Note** that the last command run in the command above is `chmod 0600 ~/.duckdns/token`. It is important to secure the *token* file to prevent other users from viewing its contents from other user accounts.

#### Domains File

On your [duckdns.org](https://www.duckdns.org) account you will have one or more subdomains set up. This script can update one or more subdomains with the current public ip address.

To create a the file and populate it with `mydomain` you could use the following command in a terminal window.

```bash
mkdir -p ~/.duckdns && touch ~/.duckdns/domains.txt && echo 'mydomain' > ~/.duckdns/domains.txt && chmod 0600 ~/.duckdns/domains.txt
```

After you create the `domains.txt` file you may edit it to add other subdomains. Each subdomain will need to be on a seperate line.

Example **domains.txt** entries.
In the following example all three subdomains would be pointed to the current public ip address.

```txt
mydomain
myotherdomain
mysecretdomain
```

`mydomain.duckdns.org`, `myotherdomain.duckdns.org`, and `mysecretdomain.duckdns.org` would all point to the current public ip address after running this script.

### Bash file

### Installing `duckdns_update.sh`

In a terminal window the following command may be run to install the script into the `~/scripts/duckdns/` directory for the current user.

```bash
mkdir -p ~/scripts/duckdns && cd ~/scripts/duckdns && wget https://raw.githubusercontent.com/Amourspirit/duckdns_script/master/duckdns_update.sh && chmod 700 duckdns_update.sh && ls
```

### Updating IP Address

Once the `token` and `domains.txt` files are set up you can update [duckdns.org](https://www.duckdns.org) by running the following command.

```bash
/bin/bash ~/scripts/duckdns/duckdns_update.sh
```

### Force update

By running the following command in a terminal window it will clear this scripts log files and then this script will send updates to [duckdns.org](https://www.duckdns.org) when the script is run again.

```bash
truncate -s 0 ~/.duckdns/log/ip.log && truncate -s 0 ~/.duckdns/log/duckdns.log
```

### Automation

#### Crontab automation

This script only sends information to duckdns when there is an ipaddress change. This script can be automated by adding it to a *cron job.*
The example below when added to a cron job will run the script every 5 minutes.

```bash
*/5 * * * * /bin/bash $HOME/scripts/duckdns/duckdns_update.sh >/dev/null 2>&1
```

#### Advanced Automation

Starting and running this script only when system reboots is sometimes all that is needed. This is the case in cloud computing such as with *AWS* when the server only gets a new IP Address when the server reboots ( if not assigned static IP Address such as *Elastic IPs* ). The issue is that the network is not ready when the system is booting up.

A solution is to run the script as a service for the system.

The following set up running this script as a system service.
**Warning** KNOW what you are doing before you attempt this.

Create a new system service named `duckdns_update` by running the following command:

```bash
sudo systemctl edit --force --full duckdns_update.service
```

The above command will open the default text editor ( such as nano ). The first time you run the above command the editor will not contain any text.

**FOR root user add the following**. See below for non-root user

```ini
[Unit]
Description=Duckdns update Service
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/root/scripts/duckdns/duckdns_update.sh

[Install]
WantedBy=multi-user.target
```

**FOR non root user**. In this case the user is named **ubuntu**

```ini
[Unit]
Description=Duckdns update Service
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu
ExecStart=/home/ubuntu/scripts/duckdns/duckdns_update.sh

[Install]
WantedBy=multi-user.target
```

For non root user change the **ubuntu** user name for the *username* required by your setup.

Save your changes and exit your editor.

Check the newly created service

```txt
$ systemctl status duckdns_update.service
● duckdns_update.service - Duckdns update Service
   Loaded: loaded (/etc/systemd/system/duckdns_update.service; disabled; vendor preset: enabled)
   Active: inactive (dead)
```

Now we can enable and test our service:

```bash
sudo systemctl enable duckdns_update.service
sudo systemctl start duckdns_update.service
```

Another status check shows the service is enabled

```bash
$ systemctl status duckdns_update.service
● duckdns_update.service - Duckdns update Service
     Loaded: loaded (/etc/systemd/system/duckdns_update.service; enabled; vendor preset: enabled)
     Active: inactive (dead) since Fri 2020-06-19 19:17:57 UTC; 31min ago
    Process: 494 ExecStart=/root/scripts/duckdns/duckdns_update.sh (code=exited, status=0/SUCCESS)
   Main PID: 494 (code=exited, status=0/SUCCESS)

```

Reboot the computer to test if the service is working.

```bash
sudo systemctl reboot
```

You can edit the service and show it. After editing you must restart the service to take effect.

```bash
sudo systemctl restart duckdns_update.service
```

To prevent the service from running on startup you can disable it.

```bash
$ sudo systemctl disable duckdns_update.service
Removed /etc/systemd/system/multi-user.target.wants/duckdns_update.service.
```

One more status check to confirm disabled.

```bash
$ systemctl status duckdns_update.service
● duckdns_update.service - Duckdns update Service
     Loaded: loaded (/etc/systemd/system/duckdns_update.service; disabled; vendor preset: enabled)
     Active: inactive (dead)

```
## Logs

### ip.log

The current public ip address will be stored in the log file `~/.duckdns/log/ip.log` after the script is run.

The contents of this file can be viewed in a terminl window with the following command.

```bash
cat ~/.duckdns/log/ip.log
```

If for any reason the script can not find a valid public ip address then `~/.duckdns/log/ip.log` file will contain a message and **not** a valid ip address.

### duckdns.log

When this script sucessfully updates [duckdns.org](https://www.duckdns.org) the `~/.duckdns/log/duckdns.log` will contain the message `OK`.

The contents of this file can be viewed in a terminl window with the following command.

```bash
cat ~/.duckdns/log/duckdns.log
```
