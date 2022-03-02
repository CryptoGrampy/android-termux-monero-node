# Monerod-in-Termux
Run a Monero Node on Android using Termux

<center> 
<figure>
<img src="assets/notification.jpeg" width="400">
<figcaption>Monero Node Status in Android Notifications </figcaption>
</figure>
</center>

## Table of Contents
- [Background](#background)
- [TLDR / Install](#tldr--install)
- [Table of Contents](#table-of-contents)
  - [⚠️ Warnings](#warnings)
  - [Controls Overview](#controls-overview)
  - [Connecting to your Node / Seeding the Network](#connecting-to-your-node--seeding-the-network)
    - [Wallet Connections](#wallet-connections)
    - [P2P Seeding](#p2p-seeding)
  - [Updates](#updates)
  - [TODO's](#todos)
  - [Donate](#donate)

# Background

The goal of this project is to give newbs a stupid-easy way to run an energy-efficient, full or pruned Monero node on Android.

Ideally, this is an older device that's currently sitting in a drawer, doing nothing.  
Why not set it up as a Monero node?

Battery Life
- Recommend leaving charger connected during initial sync, which can take a couple days.
- Battery usage after sync completion is quite low, but not 0 due to wake-lock being applied. 
- While the node can be run on your main device, it is recommended to keep the device plugged in when running 24/7 or better, to run on a spare/old device. 

Data Usage
- Over 100 gb initial download.
- After fully synced, and using config settings of: 1gb max up/down speeds; 32/100 out/in peers; averaging 25kb/s up/down:
  - Approx 2gb/day (dl) as of Sunday, January 02, 2022. 
  - Slightly more than 4gb if P2P seeding is enabled.
- You can check your data usage using the **XMR Node Status** shortcut from the widget. It will show in the terminal that pops up.

Running a Monero node allows you to connect your wallet (Feather, CakeWallet, Monerujo etc) to your node.
While Monero is private, using a _remote_ node (one operated by a 3rd party) involves some level of trust. 
A remote node receives certain information from you, such as the date, time of a tx and the IP that sent it to the node.  
Running a node on Android is an easy and more decentralized way to both use and improve Monero and the Monero network.


# TLDR / Install

Prerequisites:

    - Android 7.0+ with ARMv8/v7 architecture
      - The script will check the architecture before running
    - 50GB min free space (64GB+ Recommended) for Pruned node
    - 150GB min free space (256GB+ Preferred) for Full Node
    - External Storage is recommended.

Steps:

1. Install the [F-Droid App Store](https://f-droid.org/)

2. Install these Apps from F-Droid:

     (Do **NOT** install from Play store. If any of these are already installed from gplay, uninstall them)
    - [Termux](https://f-droid.org/packages/com.termux)
    - [Termux:Widget](https://f-droid.org/packages/com.termux.widget)
    - [Termux:API](https://f-droid.org/packages/com.termux.api)
    - [Termux:Boot](https://f-droid.org/packages/com.termux.boot)

2. Set app permissions:

     Go to:
     1. Android Settings > search for ”Special Access" 
     2. Select "Battery Optimization" > All Apps
        Then disable battery optimization for
         - Termux
         - Termux:Boot
     3. Return to "Special Access" screen
     4. Select "Draw over other apps"
        Enable draw over apps aka draw on top for:
         - Termux 

3. In termux, issue the command 
```bash
sh -c "$(curl -fsSL https://github.com/CryptoGrampy/android-termux-monero-node/raw/main/src/install-monerod-in-termux.sh)" 
```
4. Follow the prompts. 

    _**All Users:**_ 

    Press Y when/if asked to use package maintainers version of sources.list

5. Add the 2x2 Termux widget to your home screen.

6. SUCCESS

NOTE: YOU WILL NOT BE ABLE TO TRANSACT UNTIL YOUR NODE IS 100% SYNCED.

**Extras**
  1. Run on Boot: Open the "Termux:Boot" app (once).
  2. Run in Fore/Background: "Stop" then "Start" the node from widget.
  3. Connect to your Node: [Wallet Connections](#wallet-connections).
  4. Enable P2P seeding (distributing) of the Blockchain [Forwarding P2P (seeding) port](#p2p-seeding).

More info on running a Monero Node:

https://www.reddit.com/r/Monero/comments/kkr04n/infographic_running_a_node_which_ports_should_i/
https://www.reddit.com/r/Monero/comments/kkgly6/message_to_all_monero_users_we_need_more_public/
https://www.reddit.com/r/Monero/comments/ko0xd1/i_put_together_a_new_guide_for_running_a_monero/

# WARNINGS...

1. Ideally you should store the blockchain on external storage (MicroSD etc).
   Regardless of whether the blockchain is stored on SD or Internal..
   You should run this AT YOUR OWN RISK and READ THE CODE. Feel free to make or suggest improvements.

2. Monero is mostly writes and reads - not rewrites - which are what kill storage the fastest.

3. You may risk your data or the lifespan of your microSD / Internal storage may be shortened.  

   It is recommended to backup before running, and preferably to run on a dedicated / spare / old device.

4. **Do _NOT_ forward port 18081 (the UNRESTRICTED RPC port)**

# Controls Overview

Using the Termux Widget, you can 'Start XMR Node', 'Stop XMR Node', 'Update XMR Node', and check the 'XMR Node Status'. 

The notification will be automatically be updated every 15 minutes. The first notification after starting your node may not appear until after 30 seconds have passed.

The notification might not be 100% accurate on slower devices. You can force a refresh of the notification from notification itself, or by using the 'XMR Node Status' shortcut in the Termux widget.

Alternatively, you can "Stop" the node, and "Start" it in the foreground.

# Connecting to your Node / Seeding the Network

Following are a few ip addresses and ports to make note of. 

## Wallet Connections

NOTE:  YOU WILL NOT BE ABLE TO TRANSACT UNTIL YOUR NODE IS 100% SYNCED.

| Wallet relationship to node: | IP: | Port: (Why?) | Forward? |
| ---------------------------- | ------ | ------ | --- |
| The same device | 127.0.0.1 | 18081 (Unrestricted RPC Port) | Yes |
| Different devices on the same local network | Check Notification | 18089 (Restricted RPC Port) | No |
| Different devices on seperate networks | Public / Internet facing IP. [Search DuckDuckGo for ”my ip"](https://ddg.gg/?q=my+ip&ia=answer)| 18089 (Restricted RPC Port) | Yes |

These are the default ports set in the config file.
You can edit the config file (located at crypto/monero-cli).
[Here is a nice Monerod reference guide]([src/full-monero-node-install](https://monerodocs.org/interacting/monerod-reference/)) 

## P2P Seeding

If you want to seed (help distribute) the Monero network (Recommended)
| Port: (Why?) | Forward? |
| -------------- | --- |
| 18080 (P2P Port) | Yes |

The process for port forwarding may vary slightly depending on the router used.
If you [DuckDuckGo "port forwarding"](https://ddg.gg/port-forwarding) and add the name / brand of your router, you should find a guide.

Example:

<center> 
<img src="assets/p2p-setup2.png" width="800">
</center>

<center> 
<img src="assets/p2p-setup.png" width="800">
</center>

If you decide, for whatever reason, that you want to stop seeding the network, simply stop forwarding port 18080 in your router/remove the port forwarding rule.  

Troubleshooting:
  - If P2P stops working for you, it's possible your router changed the IP of your Android device (this is normal behavior for a router).  
    
    You will likely need to set up your Android device to use a 'static ip'... For this..

    Open Android Setting, and go to: wifi > tap & hold on current network > edit/modify > [show advanced] > ip settings

    Change DHCP from "auto/dynamic" to "manual/static". 

# Updates

- (Stable) CryptoGrampy/main Install script:
  Run
```bash
sh -c "$(curl -fsSL https://github.com/CryptoGrampy/android-termux-monero-node/raw/main/src/install-monerod-in-termux.sh)" 
  ```
  and follow the prompts.

- Updates to Monerod (node SW): Run the 'Update XMR Node' shortcut to install the new version.  

# TODO's:

- TBD

# Donate:

If you enjoy this software, please feel free to send a tip to:

- **[CryptoGrampy](https://twitter.com/CryptoGrampy)!** $XMR:
```
85HmFCiEvjg7eysKExQyqh5WgAbExUw6gF8osaE2pFrvUhQdf1HdD6XSTgAr4ECYMre6HjWutPJSdJftQcYEz3m2PYYTE6Y
```

  - **[plowsof](https://github.com/plowsof)** $XMR:
```
86aSNJwDYC2AshDDvbGgtQ17RWspmKNwNXAqdFiFF2Db91v9PC26uDxffD9ZYfcMjvJpuKJepsQtELAdmXVk85E1DsuL6rG
```

  - **[nahuhh](https://github.com/nahuhh)** ☠️ $XMR:
```
8343hzpypz2BR5ybAMNvvhaLtbXSMgCT7KqYSTfLBk3DF8Yayi5b7JGRWZc2GdqNu1EkALEFv1FHkCgeQ1zzkUFVMqtcTBy
```
