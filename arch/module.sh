#!/bin/sh


archrefreshkeys(){
    pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1
}
