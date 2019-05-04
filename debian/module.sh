#!/bin/sh

maininstall(){
    if ! $aptupdated ; then apt update; aptupdated=true; fi
    apt-get install -y $1 > /dev/null
}

debianrefreshkeysandppas(){
    run-parts --report "$script_path/debian/pre.d"

    add-apt-repository -y ppa:webupd8team/java #For java 8
    add-apt-repository -y ppa:linuxuprising/java
    add-apt-repository -y ppa:remmina-ppa-team/remmina-next
    add-apt-repository -y universe

    apt update
    aptupdated=true
}


