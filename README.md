# AutoDotFiles :hammer_and_wrench:

This repository contains an automatic setup program I've made to bring my whole environment on any computer in a matter of seconds.
It is meant for personal usage only, but as it's a relatively complex setup I make it public so anyone can check how it works.

It's built with very personal preferences towards which tools to use, lots of aliases and shortcuts, and methods to improve overall experience both as a terminal user and a developer.

Everything is divided into more or less independent modules, so you can review every part separately if you want to.

## One-line install

```bash
curl -L https://git.io/autodotfiles | bash
```

## Goal

The goal of this project is to install with a simple single command my whole environment - aliases, software, configuration files, tools, etc. - with a one-line update process with a simple rollback method in case something goes wrong.

It also adapts the environment depending on if the platform is WSL 2 or a real Linux distribution, and also if the computer is my main computer or not, meaning I also use it on my professional computer.

It greatly varied in size since the beginning, increasing to up to 8000 lines of ZSH at one point. Currently, it contains about 1000 lines (not counting blank lines and comments).

## Features

* Auto-installation and update of softwares
* Auto-installation and configuration of aliases, functions, configuration for softwares
* Auto-backup of current environment during update process
* Snapshots and rollback process
* Remote installer to setup the environment on a distant server
* Local and remote updater
* Works both on WSL (Ubuntu) and Debian-based distributions

### Update

On main computer use `zerupdate`, on any other one use `zerupdate_online` to update from the latest version of the source code from this repository.
