#!/bin/sh

### OPTIONS AND VARIABLES ###
for arg in "$@"; do
    shift
    case "$arg" in
        "--no-create-user") set -- "$@" "-C" ;;
        "--no-dialog")      set -- "$@" "-D" ;;
        "--"*)              set -- "$@" "-h" ;;
        *)                  set -- "$@" "$arg" ;;
    esac
done

while getopts ":a:p:r:CDh" o; do case "${o}" in
	h) printf "Optional arguments for custom use:\\n  -r: Dotfiles repository (local file or url)\\n  -p: Dependencies and programs csv (local file or url)\\n  -a: AUR helper (must have pacman-like syntax)\\n  -h: Show this message\\n" && exit ;;
	r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit ;;
	p) progsfile=${OPTARG} ;;
	a) aurhelper=${OPTARG} ;;
    C) nocreateuser=true ;;
    D) nodialog=true ;;
	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit ;;
esac done

# DEFAULTS:
version="0.1"
[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/etkeys/dotfiles.git"
[ -z "$progsfile" ] && progsfile="progs.csv"
[ -z "$aurhelper" ] && aurhelper="yay"
[ -z "$nocreateuser" ] && nocreateuser=false
[ -z "$nodialog" ] && nodialog=false

aptupdated=false
archdistro=false
debiandistro=false
script_path="$(cd "$(dirname "$0")"; pwd -P)"

### FUNCTIONS ###

error() { printf "ERROR:\\n%s\\n" "$1"; exit;}

distrocheck(){
    case "$(lsb_release --id --short)" in
        "Arch") 
            archdistro=true
            . "$script_path/arch/module.sh"
            ;;
        "Ubuntu")
            debiandistro=true
            . "$script_path/debian/module.sh"
            ;;
        *) return false ;;
    esac
    echo "Arch distro: $archdistro"
    echo "Debian distro: $debiandistro"
}

welcomemsg() { 
    printf "\n\n***************************************************************\n"
    printf "Welcome to System Bootstrapping (v$version)\n"
    printf "\t(Inspired by LARBS, https://larbs.xyz)\n\n"
}

getuserandpass() {
    # TODO handle nodialog option
	# Prompts user for new username an password.
    if ! $nocreateuser; then
        name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit
        while ! echo "$name" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do
            name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
        done
        pass1=$(dialog --no-cancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
        pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
        while ! [ "$pass1" = "$pass2" ]; do
            unset pass2
            pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
            pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
        done ;
    else
        name=$(who | cut -d " " -f 1)
    fi

    export name
}

usercheck() {
    # TODO handle nodialog option
	! (id -u "$name" >/dev/null) 2>&1 ||
	dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "No wait..." --yesno "The user \`$name\` already exists on this system. LARBS can install for a user already existing, but it will \\Zboverwrite\\Zn any conflicting settings/dotfiles on the user account.\\n\\nLARBS will \\Zbnot\\Zn overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that LARBS will change $name's password to the one you just gave." 14 70
}

preinstallmsg() { 
    # TODO hanlde nodialog option
    printf "\n\n"
    printf "The installation will now being. This will make system-wide changes\n"
    printf "to your setup. Near the begining you may be required to take action.\n\n"
    printf "Continue? (y/n) "
    read response
    if [ ! "$response" = "y" ]; then exit; fi
}

refreshkeysandppas() {
    # TODO handle nodialog option
    printf "Refreshing keyring and fetching additonal install references...\n"

    if $archdistro ; then
        archrefreshkeysandppas
    elif $debiandistro ; then
        debianrefreshkeysandppas
    fi
}

setrunfile(){
    if [ -f "$script_path/$progsfile" ] && \
        sed '/^#/d; /^$/d' "$script_path/$progsfile" > /tmp/progs.csv ; then
        echo "Found run file in script directory."
        return 0
    elif [ -f /usr/bin/curl ] && curl -Ls "$progfile" | sed '/^#/d' > /tmp/progs.csv ; then
        echo "Retrieved fun file from web source with curl."
        return 0
    elif [ -f /usr/bin/wget ] && wget "$profile" | sed '/^#/d' > /temp/progs.csv ; then
        echo "Retrieved run file from web source with wget."
        return 0
    else
        return 1
    fi
}

installationloop() {
	total=$(wc -l < /tmp/progs.csv)
    # TODO what is this used for?
	#aurinstalled=$(pacman -Qm | awk '{print $1}')
	while IFS=, read -r tag program comment; do
		n=$((n+1))
		echo "$comment" | grep "^\".*\"$" >/dev/null 2>&1 && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
        printprogline "$program" "$comment"
		case "$tag" in
			"") maininstall "$program" "$comment" ;;
			"A") aurinstall "$program" "$comment" ;;
			"G") gitmakeinstall "$program" "$comment" ;;
			"N") nodeinstall "$program" "$comment" ;;
			"P") pipinstall "$program" "$comment" ;;
			"S") snapinstall "$program" "$comment" ;;
		esac
	done < /tmp/progs.csv
}

printprogline(){
    printf "($n/$total) $1: $2\n"
}

gitmakeinstall() {
	dir=$(mktemp -d)
    url="$(head -n 1 "$script_path/git/$1")"
    retdir="$PWD"
	git clone --depth 1 "$url" "$dir" >/dev/null 2>&1
	cd "$dir" || exit
    tail -n +2 "$script_path/git/$1" | \
        while read -r line ; do
            eval "$line"
        done 
	cd "$retdir" || return 
}

nodeinstall(){
    node install -g "1" > /dev/null
}

pipinstall() {
    # FIXME What if pip3 is named pip?
	yes | pip3 install -q "$1" 
}

snapinstall(){
    if [ ! $(echo "$PATH" | grep -Eq "^\/snap\/bin:|:\/snap\/bin:") ] ; then
        PATH=/snap/bin:$PATH
    fi
    eval "snap install $1" > /dev/null
}

getconfigfiles() { # Downlods a gitrepo $1 and places the files in $2 only overwriting conflicts
    # TODO handle dialog
	#dialog --infobox "Downloading and installing config files..." 4 60
	tdir=$(mktemp -d)
    retdir="$PWD"
	[ ! -d "$2" ] && mkdir -p "$2" && chown -R "$name:$name" "$2"

    cd "$HOME"
    yadm clone "$1" >/dev/null 2>&1 && yadm stash drop >/dev/null 2>&1

    # TODO copy all the files known to yadm into tdir
    ttargets=$(mktemp)
    tdir="$(mktemp -d)/configs"
    yadm ls-tree -r master --name-only > "$ttargets"
    cat "$ttargets" | \
        while read -r line ; do
            dirpath="$(dirname line)"
            newdir="$tdir/$dirpath"
            if [ "$dirpath" != "." ] && \
                [ ! -d "$newdir" ] ; then

                mkdir -p "$newdir"
            fi
            cp "$line" "$newdir"
        done

    chown -R "$name:$name" "$tdir"
	sudo -u "$name" cp -rfT "$tdir" "$2"

    cd "$retdir"
}

getfonts(){
    tdir="$(mktemp -d)"/.fonts
    url="https://assets.ubuntu.com/v1/fad7939b-ubuntu-font-family-0.83.zip"
    
    mkdir -p "$tdir"
    curl -o /tmp/incomingfonts.zip "$url"
    unzip -jd "$tdir" /tmp/incomingfonts.zip
    chown -R "$name:$name" "$tdir/.."
    sudo -u "$name" cp -rfT "$tdir/.." "/home/$name"
    fc-cache -fv "/home/$name/.fonts"
}
    
applytheme(){
    tdir=$(mktemp -d)
    cp "/home/$name/.themes/*.tar.gz" "$tdir"
    chown -R "$name:$name" "$tdir"
    sudo -u "$name" tar -xf "$tdir/*.tar.gz" -C "$tdir/"
    rm "$tdir/*.tar.gz"
    sudo -u "$name" cp -rfT "$tdir/*" "/home/$name/"
}

updategrub(){
    sed -i=.bak -E "
        s/^GRUB_TIMEOUT_STYLE=.+/GRUB_TIMEOUT_STYLE=menu/;
        s/^GRUB_TIMEOUT=.+/GRUB_TIMEOUT=2/;
        s/^GRUB_CMDLINE_LINUX_DEFAULT.+/GRUB_CMDLINE_LINUX_DEFAULT=\"\"/ 
    " /etc/default/grub

    update-grub
}

postinstall(){
    if $archdistro; then
        run-parts "$script_path/arch/post.d"
    elif $debiandistro; then
        run-parts "$script_path/debian/post.d"
    fi

    if [ -d "/home/$name/Downloads" ] ; then
        rm -rf "/home/$name/Downloads"
    fi
    ln -s /tmp "/home/$name/Downloads"
}

finalize(){
    if $nodialog ; then
        printf "\n\n"
        printf "All done!\n"
        printf "Congrats! Provided there were no hidden errors, the script completed\n"
        printf "successfully and all the programs and configuration files should be\n"
        printf "in place.\n"
    else
        dialog --title "All done!" --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place." 12 80
    fi

    printf "\n"
}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Check if user is root on Arch distro. Install dialog.
distrocheck || error "Cannot determine distribution information"
maininstall dialog || error "Are you sure you're running this as the root user? Are you sure you're using an approved distro? ;-) Are you sure you have an internet connection? Are you sure your keyring is updated?"

# Welcome user.
welcomemsg || error "User exited."

# Get and verify username and password.
getuserandpass || error "User exited."

# Give warning if user already exists.
$nocreateuser || usercheck || error "User exited."

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

### The rest of the script requires no user input.

$nocreateuser || adduserandpass || error "Error adding username and/or password."

# Refresh Arch keyrings.
refreshkeysandppas || error "Error automatically refreshing keyring. Consider doing so manually."

# TODO arch has some pre-install requirements: AUR Helper and base-devel
# TODO later versions will support this and similar for debian systems
setrunfile || error "Could not get list of programs to install."

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop

# FIXME Get getconfigfiles working with yadm as root
# getconfigfiles "$dotfilesrepo" "/home/$name"

getfonts

# applytheme

updategrub

postinstall

# Last message! Install complete!
finalize

