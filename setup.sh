 #!/bin/bash

chmod +x *.sh
chmod +x */*.sh
chmod +x *.py

. ./init-conf-and-folders.sh

if ! getent group g100999 2>&1 > /dev/null ; then
    # On the host create a group with gid 100999, and add the host user to that group.
    sudo groupadd g100999 --gid 100999
    sudo usermod -a -G g100999 $USER
fi

. ./ensure-permissions.sh

echo "Restart for the new groups to be active. (Or log out and log back in.)"
