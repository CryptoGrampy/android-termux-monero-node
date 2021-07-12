# android-termux-monero-node
Run a Full or Pruned Monero Node on Android using Termux


<center> 
<figure>
<img src="assets/notification.jpeg" width="400">
<figcaption>Monero Node Status in Android Notifications </figcaption>
</figure>
</center>

## Table of Contents
- [android-termux-monero-node](#android-termux-monero-node)
  - [Table of Contents](#table-of-contents)
- [Why](#why)
- [Contributing to the Monero Network](#contributing-to-the-monero-network)
- [WARNING...](#warning)
- [Install](#install)
- [Controls Overview](#controls-overview)
- [TODO's:](#todos)
- [Donate:](#donate)

# Why

The goal of this project is to give newbs a stupid-easy way to run an energy-efficient, full or pruned Monero node with decent defaults on an Android device.  This isn't meant for power users, people with extreme use cases, etc. If you're already that smart, you should just hack up my code and use it however you like.

Battery Life- 
I'm running this on a phone that's plugged in most of the time, so I can't speak for battery life; I would assume that once you're fully synced, the battery usage will drop quite a bit. 

Data Usage-
No idea how much data Monero uses- you'll almost certainly want to be on WiFi while it's initially syncing, and turn off the node while out and about.  My node sits on a shelf next to my wifi router.  

Running a Monero node allows you to connect CakeWallet or Monerujo to the node running in the device itself, rather than connecting to a remote node; this is a safer way of using Monero, and it alleviates network strain on the remote nodes. You should also be able to connect from other devices in your LAN


# Contributing to the Monero Network

If you simply install and run this software without making any updates in your router, you are actually LEECHING from the rest of the users of the network.  To truly contribute back to the network, open port 18080 in your router to seed (distribute) the Monero blockchain to the rest. To verify you're helping seed the network and that you've set up your router correctly, you will see  🌱 P2P: 5 (some number larger than 0)  in your Android notifications.    

While I DO recommend connecting to your Android node from within your local network using RPC, I DON'T recommend opening the RPC port in your router (yet).  

More info on running a Monero Node:

https://www.reddit.com/r/Monero/comments/kkr04n/infographic_running_a_node_which_ports_should_i/
https://www.reddit.com/r/Monero/comments/kkgly6/message_to_all_monero_users_we_need_more_public/
https://www.reddit.com/r/Monero/comments/ko0xd1/i_put_together_a_new_guide_for_running_a_monero/

# WARNING...

1. Run this code AT YOUR OWN RISK and READ THE CODE (and feel free to reach out if you have any improvements 😜).

2. You WILL (likely) lose data saved on your microSD card.  Backup before running this code.

3. If things go awry, delete all of the Termux apps you're about to install, and all will be back to normal.


# Install

Video Install Guide (Use the code linked [here](src/full-monero-node-install) rather than the Pastebin shown in the video): 

[![Monero Full Node Install](https://img.youtube.com/vi/z46zAy-LoHE/0.jpg)](https://www.youtube.com/watch?v=z46zAy-LoHE)

1. Hardware Prep:
    - Android 7.0+ with ARMv8 CPU (Nearly all made in the last few years are fine) device with microSD slot.  
      - [Check your Android CPU 'Instruction Set' here](https://www.devicespecifications.com/en/model/f6cb274f)
    - For Full Node:  Freshly wiped 128GB (256GB+ Preferred) microSD set up in Android AS EXTERNAL STORAGE
    - For Pruned Node: at least 40-50 GB of available internal storage (code for pruned node on microSD will be released in future updates)

 <center> 
  <figure>
    <img src="assets/cpu-architecture.png" width="300">
    <figcaption>Example ARMv8 CPU Instruction Set</figcaption>
  </figure>
</center>


2. Install Necessary Apps
    - Install the Fdroid App Store (https://f-droid.org/)
    - Install these Apps from Fdroid (Do NOT install from Play store.  If any of these are already installed, uninstall them)
        - Termux
        - Termux:Boot
        - Termux:Widget
        - Termux:API

<center> 
<figure>
  <img src="assets/apps.jpeg" width="300">
  <figcaption>Apps to Install from F-Droid Store </figcaption>
</figure>
</center>

3. Set Android Permissions (Go into Android settings and search for the permission names if you're having trouble locating them)
  - Battery Optimization: Don't Optimize: Termux and Termux:Boot
  - Display Over Other Apps: Termux

<center> 
  <img src="assets/android-permissions-1.png" width="300">
  <img src="assets/android-permissions-2.png" width="300">
</center>

4. Add the 'Termux Widget 2x2' Widget to your Android home screen (press the refresh button after you've finished the install process)

<center> 
<img src="assets/termux-widget.jpeg" width="300">
</center>

5. Install
  
Copy the code (INCLUDING the parenthesis) from the links below based on the node type/storage available on your device. 

| Installed Node Type | Available Storage Required | Code you need copy |
| --- | ----------- | --------|
| Full Monero Node on microSD  | microSD with 128+ (ideally 256GB) | [full-monero-node-install](src/full-monero-node-install) |
| Pruned Monero Node on Internal Storage  | 40-50GB+ Internal Storage | [pruned-monero-node-install-no-sd](src/pruned-monero-node-install-no-sd) |

Open Termux, and paste the copied code into the terminal. Press the return button on the on-screen keyboard. You will likely need to give Termux permission to do various things (add repos, etc) during the install.  Read what it's asking, type y and then press return. 

6. SUCCESS!

# Controls Overview

Using the Termux Widget, you can 'Start XMR Node', 'Stop XMR Node', 'Update XMR Node', and check the 'XMR Node Status'. Try them all- you're not going to break anything.  Tap the arrow in the Android Termux notification in your swipe-down Android notifications to see detailed info on your Node.  If a Monero update is available, it will be present in this notification. 

The notifications will be automatically be updated every 15 minutes. The first notification after restarting your device or starting turning your node on might not be 100% accurate as the Monero node can take a while to start up.  If you press the 'XMR Node Status' button in the Termux widget, you will briefly see the actual command line status of Monerod pop up in a Termux shell, and the Android notification will also update with the most recent node information (useful if you don't want to wait 15 minutes for an update)

# TODO's:

- [ ] Generate node install scripts automatically using Github Actions with env variables rather than copy-pasta'ing (error prone)
- [ ] Ensure env variables can be altered safely (Monero-CLI directory definitely cannot currently)
- [ ] Create Uninstaller
- [ ] Implement QR code installer
- [ ] Turn off notifications and boot wake locks when user turns node off/add them back when node is turned on
- [ ] Custom Configs
- [ ] Check for external SD, if doesn't exist use different/symlinked install dir, check space before installing?/run as pruned
- [ ] Secure RPC defaults

# Donate:

- If you enjoy this software, please feel free to send $XMR tips to [CryptoGrampy](https://twitter.com/CryptoGrampy)!

- $XMR : 85HmFCiEvjg7eysKExQyqh5WgAbExUw6gF8osaE2pFrvUhQdf1HdD6XSTgAr4ECYMre6HjWutPJSdJftQcYEz3m2PYYTE6Y
 
