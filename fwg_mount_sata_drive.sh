#!/bin/bash

##
# script to make docker containers' configuration persist between reboots of the firewalla box
# the script must be created at /home/pi/.firewalla/config/post_main.d/start_[service-name].sh

##
# as per our own configuration, the docker root has been moved to the ssd drive
# so, after every reboot, we must check whether or not, the drive is mounted
# and the /var/lib/docker directory has been copied to the new docker root path
# before starting the docker containers

##
# args
TMPDIR='/tmp'
MNTDIR='/mnt/data'
LOG_FILE='/tmp/mount_point.log'
FSTB_FILE='/etc/fstab'
CHCK_FILE='/.do_not_remove_this_file'
MNT_CMMNT='#mount on reboot the m.2 ssd sata drive'
SSD_UUID='875e8ad7-e48c-4fac-9551-0b6b1dcd8d0f'
MNT_OPTS='auto nosuid,nodev,nofail,x-gvfs-show 0 0'
USRNAME='pi'
USRGROUP='data'

##
# 1. create mount point directory
# 2. update /etc/fstab for persistent configuration
# 3. apply permissions and ownership to mount point
# 4. check for access to mount point
# 5. end

##
# start the script
printf "%s\n" "script has started..."
cd $TMPDIR
printf "%s\n" " - moved to $(pwd)"

##
# create the mount point directory
#
printf "%b\n" "\nlet's create the mount point directory..."
if [ -d "$MNTDIR" ]; then
  printf "%s\n" " - the mount point directory $MNTDIR already exists... ok"
else
  sudo mkdir -p $MNTDIR && sudo chmod 775 $MNTDIR && sudo chown -R nobody:nogroup $MNTDIR
  if [ -d "$MNTDIR" ]; then
      printf "%s\n" " - the mount point directory $MNTDIR has been created, permissions applied and group ownership updated..."
  else
      printf "%s\n" " * - couldn't create the mount point directory $MNTDIR... something is wrong"
      printf "%b\n" "$(date +%F) - couldn't create the mount point directory $MNTDIR... something is wrong" >> $LOG_FILE
      exit 1
  fi
fi

# update the /etc/fstab file with the mount point
#
printf "%b\n" "\ninserting mount point into the $FSTB_FILE file..."
if grep -Fq "${MNTDIR}" "${FSTB_FILE}"; then
  printf "%s\n" " - the mount point $MNTDIR is already declared in $FSTB_FILE... ok"
  if [[ -f $MNTDIR$CHCK_FILE ]]; then
    printf "%s\n" " - $MNTDIR$CHCK_FILE is accessible... ok"
  else
    printf "%s\n" " * - couldn't access $MNTDIR$CHCK_FILE... something is wrong"
    printf "%b\n" "$(date +%F) - couldn't access $MNTDIR$CHCK_FILE... something is wrong" >> $LOG_FILE
    exit 1
  fi
else
  sudo cp -p $FSTB_FILE ${FSTB_FILE}.bck-$(date +%F)
  #sudo su -c "$(printf "%b\n" "\n$MNT_CMMNT \nUUID=$SSD_UUID $MNTDIR $MNT_OPTS" >> $FSTB_FILE)"
  sudo su -c "echo -e '\n$MNT_CMMNT \nUUID=$SSD_UUID $MNTDIR $MNT_OPTS' >> $FSTB_FILE"
  sudo mount -a
  if grep -Fq "${MNTDIR}" "${FSTB_FILE}"; then
    if [[ -f $MNTDIR$CHCK_FILE ]]; then
      # create user group
      #
      printf "%b\n" "\ncreating group $USRGROUP..."
      if [ $(getent group $USRGROUP) ]; then
         printf "%s\n" " - the group $USRGROUP already exists... ok"
      else
         sudo groupadd $USRGROUP && sudo usermod -aG $USRGROUP $USRNAME
         printf "%s\n" " - the group $USRGROUP has been created and user $USRNAME added to group... ok"
      fi
      printf "%s\n" " - the mount point $MNTDIR has been added to $FSTB_FILE and mounted... ok"
      sudo chown -R $USRNAME:$USRGROUP $MNTDIR
      printf "%s\n" " - the mounted drive is accessible and group $USRGROUP ownership updated... ok"
    else
      printf "%s\n" " * - couldn't access $MNTDIR$CHCK_FILE... something is wrong"
      printf "%b\n" "$(date +%F) - couldn't access $MNTDIR$CHCK_FILE... something is wrong" >> $LOG_FILE
      exit 1
    fi
  else
    sudo mv ${FSTB_FILE}.bck-$(date +%F) $FSTB_FILE
    sudo mount -a
    printf "%s\n" " * - couldn't mount directory $MNTDIR... something is wrong"
    printf "%b\n" "$(date +%F) - couldn't mount directory $MNTDIR... something is wrong" >> $LOG_FILE
  fi
fi
# finished mounting the ssd hdd
printf "%b\n" "\nssd hdd mounting script has ended..."
##
