# KCstudio Launchpad - Bash Platform

<a href="https://launchpad.kcstudio.nl">
  <img src="https://launchpad.kcstudio.nl/github/kcstudio_launchpad_banner.png" alt="KCStudio Launchpad Bash Logo" width="100%">
</a>
<br></br>

> **Turn a single VPS into a structured, security-hardened, multi-project application server — without containers.**

KCStudio Launchpad is a **Bash-based TUI platform** that helps solo developers and small teams deploy, manage, and operate multiple full-stack applications on a single VPS using **native Linux services**.

No Docker.  
No Kubernetes.  
Just your server, your code, and a guided menu that keeps everything under control.   

[![Fresh VPS to Live Apps in Minutes](https://img.shields.io/badge/Fresh%20VPS%20to%20Live%20Apps-In%20Minutes-yellow?style=for-the-badge)](https://launchpad.kcstudio.nl)

<p>
  <a href="LICENSE.md">
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT">
  </a>
  <img src="https://img.shields.io/badge/Platform-Ubuntu%2024.04-orange.svg" alt="Platform">
</p>


---

## TL;DR

**KCStudio Launchpad is a host-native alternative to container-heavy platforms.**  
It automates the boring, error-prone parts of server setup and application management, so you can confidently run **multiple real projects** on a single VPS.

It’s opinionated, pragmatic, and designed for people who want:
- Ownership of their stack
- Predictable behavior
- Fewer moving parts

<a href="https://launchpad.kcstudio.nl">
  <img src="https://launchpad.kcstudio.nl/img/KCstudio_Launchpad_Logo.webp" alt="KCStudio Launchpad Logo" width="18%">
</a>

---

## Why KCstudio Launchpad exists

Most self-hosting tools either:

* Hide everything behind containers, or

* Assume you already know how to be a sysadmin.

Launchpad sits in between:

* Host-native,

* Opinionated,

* Hard to accidentally break.

It’s what you build after breaking a VPS a few times.

---

## Quick start

Run this on a **fresh Ubuntu 24.04 VPS**, logged in as `root`:

```bash
wget https://github.com/kelvincdeen/kcstudio-launchpad/releases/latest/download/kcstudio-launchpad.deb && \
sudo apt install ./kcstudio-launchpad.deb
````
Once installed, run:
`launchpad`

Launchpad will guide you from there.

Distributed as a .deb for convenient install; target OS: Ubuntu 24.04.

Launchpad installs under /opt/kcstudio-launchpad/ and exposes the `launchpad` and `kcstudio-launchpad` commands system-wide.

---

## Who this is for (and who it isn’t)

### This is for you if:
- You are a **solo developer, indie hacker, or freelancer**
- You want to host **multiple apps** on one VPS
- You prefer understanding your server over abstracting it away
- You want security and structure without enterprise complexity

### This is *not* for you if:
- You need multi-server orchestration or auto-scaling clusters
- You want a managed PaaS where you never touch the server
- You enjoy maintaining Kubernetes YAML more than shipping apps

This tool is intentionally **simple, opinionated, and host-centric**.   
This is what makes KCstudio Launchpad powerfull.

---

## See it in action

The entire demo platform is **deployed and managed by Launchpad itself**.

**Live demo:**  
🌐 https://launchpad.kcstudio.nl/live-demo  
📚 https://launchpad.kcstudio.nl/api-docs  

🎥 **5-minute setup walkthrough:**  
https://youtu.be/B_mNKLXpL_0

Visit **main website** here: [Launchpad.KCstudio.nl](https://launchpad.kcstudio.nl/)

---

## How it works (the mental model)

### The Launchpad Hub (your starting point)

Every interaction with Launchpad starts in a single, central **Hub**.

From here, the toolkit:
- Guides you through each lifecycle step
- Explains *what it’s doing and why*, directly in the TUI
- Provides contextual help and documentation
- Acts as the control center for everything that follows

Each step is **interactive and self-documented** - you are never dropped into blind commands or unexplained automation. There is more to discover inside the toolkit than can be captured in a README.


## Launchpad guides you through a **four-step lifecycle**, from a blank VPS to a portfolio of running applications.

<a href="https://launchpad.kcstudio.nl">
  <img src="https://launchpad.kcstudio.nl/github/kcstudio_launchpad_hub_hardened.png" alt="KCStudio Launchpad Main Menu Startup">
</a>


### 1. Secure the foundation
**`SecureCoreVPS-Setup`** hardens a fresh Ubuntu 24.04 server:
- SSH key-only access, no root login
- Firewall and intrusion protection
- Hardened NGINX defaults
- Automatic security updates
- Final Lynis security audit

In addition, it provides guided **user** and **SSH key** management along with basic operational helpers, so first-time VPS users don’t have to guess their way through critical setup decisions.

You run this once.

---

### 2. Architect the apps
**`CreateProject`** generates and wires everything:
- Isolated system users per project
- systemd services with auto-restart
- NGINX reverse proxy with HTTPS
- Modular backend components (auth, database, storage, app)
- Sensible defaults for rate limiting, CORS, logging

On top of configuring it also **writes production-ready code** for backend components and cleans up safely if something fails. See `/api-docs` on the website for reference.

---

### 3. Manage projects day-to-day
**`ManageApp`** is your daily command center:
- Deploy updates from local paths or URLs
- Restart services with one key
- Stream live logs per component
- Edit configs and `.env` files safely
- Back up code and databases
- Fully remove a project when you’re done

All actions are performed through guided, reversible workflows, with previews and confirmations to help you operate confidently without fear of breaking a running system.

---

### 4. Operate the server
**`ServerMaintenance`** is a practical operations toolkit:
- Real-time system monitoring
- Disk and inode analysis
- Service management
- Traffic and security audits
- Database exploration
- Cron jobs, SSL, swap, and more

These tools are surfaced through a consistent, interactive interface that makes common operational and diagnostic tasks accessible without memorizing commands or paths.

---

## What using it *feels* like

- **New project ready?** It’s live in minutes.
- **Need to change code?** Edit, save, restart - done.
- **Something broke?** Jump straight into live logs.
- **Need a dependency?** Enter the app’s venv and install it.
- **Multiple projects?** Each one stays isolated and predictable.

Launchpad is about **flow** and **speed**.

---

## What a project looks like on disk

```

/var/www/example-project
├── app
├── auth
├── database
├── storage
├── website
├── logs
├── project.conf

````

Each component:
- Has its own logs
- Runs as its own service
- Can be restarted or debugged independently

No hidden magic. Everything lives where you expect it.

---

## Why no containers?

This is a deliberate choice.

For many solo developers, containers add:

* Indirection
* Debugging complexity
* Operational overhead

Launchpad uses **native Linux primitives**:

* systemd
* users
* files
* NGINX

You get fewer layers, clearer failure modes, and full ownership of your stack.

---

## The story behind it

I built KCstudio Launchpad after shouting through my first real VPS setup. As a builder, I want things to just *work*.

I created Launchpad with this in mind:

* What is security?
* What should be safe by default?
* How do I avoid breaking everything?
* How can I host multiple apps?
* What would I need at 2 a.m.?

Then I codified that learning into a tool I now use for every project.

KCstudio Launchpad is **my learning journey turned into software**. 

I'm making this open source to give back, because I'm standing on the shoulders of giants and this is my way of showing appreciation and respect.

---

## FAQ

**Is it free?**
Yes. MIT licensed.

**How many projects can I run?**
As many as your VPS can handle.

**Is it secure?**
It provides a strong baseline. You are still responsible for ongoing security.

**Do I need to understand Linux?**
You don’t need to be an expert, but you’ll learn naturally by using it.

---

## Contributing

PRs are welcome - especially around:

* Security improvements
* Operational robustness

Readable, function based code is prioritized.

---

## Roadmap (high-level)

* I iterate on and develop KCstudio Launchpad internally. Whenever I have a new baseline that is stable enough, I'll release new versions in one go.
* Development is primararly focused on implementing features absolutely needed and avoiding 'thats neat' bloat features.   

---

## ❤️ Like this project?

*   ⭐ **Star the repo**
*   💬 **Share it with a friend**
*   ☕ **Buy me a coffee** https://buymeacoffee.com/kelvincdeen

---

## About KCStudio

This toolkit reflects how I approach building products: holistic, pragmatic, polished, and end-to-end.

👉 [https://kcstudio.nl](https://kcstudio.nl)
