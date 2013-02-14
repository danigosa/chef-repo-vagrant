#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

sudo sysctl -w kernel.shmmax=<%= node[:inf_shmmax]  =%>
sudo sysctl -w kernel.shmall=<%= node[:inf_shmmall]  =%>
sudo service postgresql restart
sudo service uwgsi restart
sudo service nginx restart

exit 0
