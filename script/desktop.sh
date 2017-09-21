#!/bin/bash

USERNAME=vagrant

# set the graphical.target for systemd so it will run startx on boot
ln -sf /lib/systemd/system/graphical.target /etc/systemd/system/default.target

# Configure gdm autologin.
 sed -i s/"daemon]$"/"daemon]\nAutomaticLoginEnable=true\nAutomaticLogin=vagrant"/ /etc/gdm/custom.conf
