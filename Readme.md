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

### Installing `duckdns_update.sh`

In a terminal window the following command may be run to install the script into the `~/scripts/duckdns/` directory for the current user.

```bash
mkdir -p ~/scripts/duckdns && cd ~/scripts/duckdns && wget https://raw.githubusercontent.com/Amourspirit/duckdns_script/master/duckdns_update.sh && chmod 700 duckdns_update.sh && ls
```

## Configuration

The following setting can be placed in a file `~/duckdns/config.cfg`
See the [sample.cfg](sample.cfg) file.

### GENERAL Section

[GENERAL]
| Setting        | Default                        | Descripton                                                                                                  |
|----------------|--------------------------------|-------------------------------------------------------------------------------------------------------------|
| TOKEN_FILE     | $HOME/.duckdns/token           | The Path to file that contains the token obtained from duckdns.org account.                                 |
| IP_LOGFILE     | $HOME/.duckdns/log/ip.log      | This file will contain the current ip address upon successful update.                                       |
| OLD_IP_LOGFILE | $HOME/.duckdns/log/ip_old.log  | The path to log file used to capture the previous ip address.                                               |
| RESULT_LOGFILE | $HOME/.duckdns/log/duckdns.log | The file that result of running the script will be logged into.                                             |
| CACHED_IP_FILE | /tmp/current_ip_address        | The temp file that is used to cache the ip address.                                                         |
| MAX_IP_AGE     | 5                              | The number of minutes to keep ip address cached                                                             |
| IP_URL         | https://checkip.amazonaws.com/ | The URL used to retrieve public ip address                                                                  |
| PERSIST_LOG    | 0                              | If value is 1 then log file will persist; Otherwise, RESULT_LOGFILE will be clear at the start of execution |

### DOMAINS Section

A list of domins to update on duckdns.org when script executes.

| [DOMAINS]  |
|-----------|
| mydomain  |
| supercool |

## Command line interface (CLI)

CLI switches

```txt
-c  The path to the cached IP address
-d  Comma seperated sub domain name(s) such as special,worderful,myhomeserver
-f  Force ip update ignoring cache
-i  The ip address to be used. Default the the ip address provided by: https://checkip.amazonaws.com/
-k  The path to the token File
-o  The path to the old Log File
-p  Persist Log File. if true then log file will be persistent; Otherwise, Log will be wiped each time script is run
-r  The path to the results log file.
-t  The amount of time the IP address is cached in minutes. Default is 5
-u  The url that will be used to query IP address. Default is https://checkip.amazonaws.com/
-v  Display version info
-h  Display help.
```

Overrides of `~/.duckdns/config.cfg`

-c overrides `CACHED_IP_FILE` setting in `[GENERAL]` Section  
-d overrides **[DOMAINS]** Section  
-k overrides `TOKEN_FILE` setting in `[GENERAL]` Section  
-o overrides `OLD_IP_LOGFILE` setting in `[GENERAL]` Section  
-p overrides `PERSIST_LOG` setting in `[GENERAL]` Section  
-r overrides `RESULT_LOGFILE` setting in `[GENERAL]` Section  
-t overrides `MAX_IP_AGE` setting in `[GENERAL]` Section  
-u overrides `IP_URL` setting in `[GENERAL]` Section  

### Updating DuckDns IP Address

Once the `~/.duckdns/token` and `~/duckdns/config.cfg` files are set up you can update [duckdns.org](https://www.duckdns.org) by running the following command.

```bash
/bin/bash ~/scripts/duckdns/duckdns_update.sh
```

### Force update

By running the following command in a terminal window it will force update to [duckdns.org](https://www.duckdns.org).

```bash
/bin/bash ~/scripts/duckdns/duckdns_update.sh -f
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
