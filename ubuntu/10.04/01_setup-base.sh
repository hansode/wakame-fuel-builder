#!/bin/sh
#
# Ubuntu-10.04 LTS
#

export LANG=C
export DEBIAN_FRONTEND=noninteractive

# core packages
pkgs="
 ruby ruby1.8-dev rdoc1.8 ri1.8 rubygems1.8
 rabbitmq-server
 make g++ libopenssl-ruby libsqlite3-dev
 ec2-ami-tools
"

[ -f /etc/apt/sources.list ] && {
  perl -pi -e 's, multiverse,,g; s,$, multiverse,' /etc/apt/sources.list
}
apt-get update
apt-get -y install ${pkgs}

# wakame account
getent group  wakame >/dev/null || {
  groupadd wakame
}
getent passwd wakame >/dev/null || {
  useradd -d /home/wakame -s /bin/bash -g wakame -m wakame
}

# wakame installation
echo "#Setting up wakame ..."
su - wakame -c "
  gem list | grep -q -w wakame || {
    #gem install /tmp/wakame-0.5.1.gem --no-rdoc --no-ri
    gem install wakame --no-rdoc --no-ri
  }
"
[ -d /home/wakame/wakame.proj ] || {
  su - wakame -c "
    /home/wakame/.gem/ruby/1.8/bin/wakame /home/wakame/wakame.proj
  "
}

[ -d /home/wakame/wakame.proj/tmp/config ] || {
  su - wakame -c "
    mkdir /home/wakame/wakame.proj/tmp/config
  "
}

# wakame system configuration
cat <<EOS > /etc/default/wakame
GEM_HOME=/home/wakame/.gem/ruby/1.8/
WAKAME_ROOT=/home/wakame/wakame.proj/
WAKAME_ENV=EC2
WAKAME_CLUSTER_ENV=development
EOS

# add service
[ -L /etc/init.d/wakame-master ] || {
  ln -s /home/wakame/wakame.proj/config/init.d/wakame-master /etc/init.d/
  /usr/sbin/update-rc.d wakame-master defaults 40
}
[ -L /etc/init.d/wakame-agent ] || {
  ln -s /home/wakame/wakame.proj/config/init.d/wakame-agent /etc/init.d/
  /usr/sbin/update-rc.d wakame-agent  defaults 41
}

# ssh key pair
[ -d /home/wakame/config ] || {
  su - wakame -c "
    mkdir /home/wakame/config
  "
}
[ -f /home/wakame/config/root.id_rsa ] || {
  su - wakame -c "
    ssh-keygen \
     -t rsa \
     -N '' \
     -C wakame-master \
     -f /home/wakame/config/root.id_rsa
  "
  cat /home/wakame/config/root.id_rsa.pub >> /root/.ssh/authorized_keys
}

# disable apparmor
[ -x /etc/init.d/apparmor ] && {
  /etc/init.d/apparmor stop
  /usr/sbin/update-rc.d -f apparmor remove
}

# disable apparmor
[ -x /etc/init.d/rabbitmq-server ] && {
  /etc/init.d/rabbitmq-server stop
  /usr/sbin/update-rc.d -f rabbitmq-server remove
}
[ -d /var/lib/rabbitmq/mnesia ] && {
  rm -rf /var/lib/rabbitmq/mnesia
}
