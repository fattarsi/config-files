sudo apt-get purge $(dpkg --list | grep -P -o "linux-(headers|image(-extra)?)-\d\S+" |grep -v $(uname -r | grep -P -o ".+\d"))
