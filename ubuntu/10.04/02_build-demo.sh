#!/bin/sh
#
# Ubuntu-10.04 LTS
#
# ELB -> nginx -> spawn-fcgi -> fcgiwrap

export LANG=C
export DEBIAN_FRONTEND=noninteractive

# core packages
pkgs="
 nginx
 spawn-fcgi libfcgi-dev
 automake
 subversion git-core
"

[ -f /etc/apt/sources.list ] && {
  perl -pi -e 's, multiverse,,g; s,$, multiverse,' /etc/apt/sources.list
}
apt-get -y install ec2-ami-tools

apt-get -y install ${pkgs}

[ -x /etc/init.d/nginx ] && {
  /etc/init.d/nginx stop
  /usr/sbin/update-rc.d -f nginx remove
}

su - wakame -c "
  /home/wakame/wakame.proj/script/generate resource nginx
  /home/wakame/wakame.proj/script/generate resource ec2_elb
"


# fcgiwrap
cd /tmp
[ -f gnosek-fcgiwrap-latest.tar.gz ] && rm -f gnosek-fcgiwrap-latest.tar.gz

wget http://github.com/gnosek/fcgiwrap/tarball/master -O gnosek-fcgiwrap-latest.tar.gz || exit 1
dirname=$(tar ztf  gnosek-fcgiwrap-latest.tar.gz | head -1)

[ -d $dirname ] && rm -rf $dirname

tar zxvf gnosek-fcgiwrap-latest.tar.gz || exit 1

cd $(tar ztf  gnosek-fcgiwrap-latest.tar.gz | head -1) || exit 1
autoheader  || exit 1
autoconf    || exit 1
./configure || exit 1
make clean  || exit 1
make        || exit 1

install -m 755 fcgiwrap /usr/local/bin/fcgiwrap


cat <<'__EOS__' > /var/www/index.cgi
#!/bin/sh

api_base_uri=http://169.254.169.254/latest/meta-data/

retrieve_meta_data() {
  curl -s -f --retry 3 ${api_base_uri}$1
}

meta_data() {
  local param=$1

  echo ${param} | egrep '/$' -q && {
    for i in $(retrieve_meta_data ${param}); do
      meta_data ${param}${i}
    done
  } || {
    echo -n "${param} = "
    echo $(retrieve_meta_data ${param})
  }
}

cat <<EOS
Content-type: text/plain

EOS

echo "[wakame demo info]-----"
date +%Y/%m/%d-%H:%M:%S
hostname
echo

echo "[meta-data]-----"
meta_data /
echo

echo "[env]-----"
env

exit 0
__EOS__

chmod +x /var/www/index.cgi
