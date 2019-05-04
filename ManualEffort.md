# Things that have to be done manually

It's not that I'm lazy, but I had two machines I needed to setup and I spent enough time banging my head against a wall trying to figure things out. For the things here, I just didn't do a good job fitting them for automation. I'll fix this later, promise!

## Config files

```bash
cd $HOME
yadm clone https://github.com/etkeys/dotfiles.git
yadm stash drop
yadm decrypt
cd $HOME
```

## Scripts

```bash
cd $HOME/repos
git clone https://github.com/etkeys/scripts.git
cd $HOME
```

**NOTE**
For best results, at this point log out then log back in. There are some environment variables that will be set that are needed for other steps later


## Install randombg-dotnet

```bash
cd $HOME/repos
git clone https://github.com/etkeys/randombg-dotnet.git
cd randombg-dotnet
./publishcore-release
mkdir -p $HOME/bin/randombg-dotnet.d
cp bin/Release/netcoreapp2.1/linux-x64/publish/* $HOME/bin/randombg-dotnet.d/
ln -s $HOME/bin/randombg-dotnet.d/randombg-dotnet $HOME/bin/randombg-dotnet
cd $HOME
randombg-dotnet updatedb
randombg-dotnet setbg
```

## i3block-blocklets

```bash
cd $HOME/repos
git clone https://github.com/etkeys/i3blocks-blocklets.git
cd i3blocks-blocklets
mkdir -p $HOME/bin/i3blocks
./deploy
cd $HOME
```

## Vim extensions

Logout and log back in because some of the script path is not set yet.

```bash
mkdir -p $HOME/.vim
$HOME/repos/scripts/update-vim-plugins
```

## Theme

### Look and feel

Need to figure out how to tell tar to extract to a particular directory. -C "$tdir" doesn't work, it just prints the files but I don't know where they go ...

```bash
tdir=$(mktemp -d)
cp $HOME/.themes/*.tar.gz "$tdir"
# this extracts from tmp into home dir... how to specify rando dir?
# tar -C "$tdir" -xf doesn't seem to work
ls $tdir/*.tar.gz | head -n 1 | xargs tar -vxf 
rm $tdir/*.tar.gz
cp -rfT $tdir/* $HOME/
```

### Sounds

**AS ROOT**

cd /usr/share/sounds/ubuntu/stereo
/home/erik/repos/scripts/cpb dialog-{error,warning}.ogg
ln -sfn dialog-error.ogg /home/erik/Public/sounds/newUbuntu/dialog-error.ogg
ln -sfn dialog-warning.ogg /home/erik/Public/sounds/newUbuntu/dialog-warning.ogg

## Handbrake

**AS ROOT**

```bash
apt install libdvd-pkg
dpkg-reconfigure libdvd-pkg
```

## Cron

```bash
crontab $XDG_CONFIG_HOME/cron.d/crontab.tab
```

## Firefox extensions

- Google App Launcher
- LastPass
- Text Contrast for Dark Themes
- Tree Style Tab
- uBlock Origin
- Vim Vixen


