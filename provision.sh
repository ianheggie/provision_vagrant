#!/bin/bash
#
# Provision for development
#
# Add the following to Vagrantfile:
#   config.vm.provision "shell",
#     path: "https://raw.githubusercontent.com/ianheggie/provision_vagrant/master/provision.sh?cache_bust=#{Process.pid}",
#     args: %w{ --prefix myproject mysql-server /vagrant }
#
# Meaning of arguments:
# --prefix myproject: a mysql user called myproject with password myproject that has access to databases named myproject_* will be created
# mysql-server: install and configure mysql-server
# /vagrant - look in this directory for Gemfile* (rails projects) or mix.exs (phoeninx/elixir projects) and install 
#            packages as appropriate
# 

echo "provision.sh version: 2.0"

chruby_version=0.3.9
min_total_memory=2048

db_user=
db_password=
db_prefix=

while [ $# -gt 0 ] 
do
    case "$1" in
    --prefix)
        db_prefix="$2"
        db_user="$2"
        db_password="$2"
        ;;
    --minmemory)
        min_total_memory="$2"
        ;;
    --chruby)
        chruby_version="$2"
        ;;
    *)
        break
        ;;
    esac
    shift
    shift
done

chruby=chruby-${chruby_version}

# Auto detect vagrant
if [ $# -eq 0 ] ; then
  if [ -d /vagrant ] ; then
    set -- /vagrant
  elif [ -s Gemfile -o -s mix.exs ] ; then
    set -- .
  fi
fi

set -e

update_apt() {
    echo . ; echo . ;  echo Update Apt
    if find /tmp/done-apt-update -mtime -1 > /dev/null 2>&1 ; then
        echo Apt has been updated in the last day
    else
        sudo apt-get -y update | sudo tee /tmp/done-apt-update
    fi
    sudo apt-get -y autoremove
}

add_swap_if_needed()
{
    # Modified version of https://gist.github.com/shovon/9dd8d2d1a556b8bf9c82

    echo . ; echo . ;  echo "Checking if swapfile is needed (Minimum $min_total_memory) ..."
    free -m -t
    if grep -q "swapfile" /etc/fstab
    then
        echo Swapfile already exists - skipping test
    else
        mem=`free -m | sed -n 's/^Mem[^0-9]*\([0-9][0-9]*\).*/\1/p'`
        echo "Memory configured: $mem MB"
        if [ -n "$mem" ] && [ $min_total_memory -gt $mem ] 
        then
            swapsize=`expr $min_total_memory - $mem`
            echo "swapfile not found. Adding swapfile of ${swapsize} MB"
            sudo fallocate -l ${swapsize}M /swapfile
            sudo chmod 600 /swapfile
            sudo mkswap /swapfile
            sudo swapon /swapfile
            echo '/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab
            echo "Memory/swap now:"
            free -m -t
        else
            echo "Swapfile not required: memory ($mem MB) is greater than required ($min_total_memory MB)"
        fi
    fi
}

install_package() {
    echo . ; echo . ;  echo Install Package $*
    export DEBIAN_FRONTEND=noninteractive
    echo Installing packages: $*
    sudo apt-get install --yes $*
}

install_gem_packages() {
    echo . ; echo . ;  echo Checking for gem: $1
    if [ -s $app_root/Gemfile ] && grep "$1" $app_root/Gemfile $app_root/Gemfile.lock ; then
        shift
        install_package $*
    fi
}

install_mix_packages() {
    echo . ; echo . ;  echo Checking for mix package: $1
    if [ -s $app_root/mix.exs ] && grep "$1" $app_root/mix.exs ; then
        shift
        install_package $*
    fi
}

install_chruby() {
    echo . ; echo . ;  echo Installing chruby ...
    if which chruby-exec
    then
      echo chruby already installed
    else
    (
      cd /tmp
      if [ ! -d ${chruby} ] ; then
          wget -O ${chruby}.tar.gz https://github.com/postmodern/chruby/archive/v${chruby_version}.tar.gz
          tar -xzvf ${chruby}.tar.gz
      fi
      cd ${chruby}/
      sudo make install
      (
        cat <<'EOF'
    if [ -n "$BASH_VERSION" ] || [ -n "$ZSH_VERSION" ]; then
      source /usr/local/share/chruby/chruby.sh
      source /usr/local/share/chruby/auto.sh
    fi
EOF
    ) | sudo tee /etc/profile.d/chruby.sh
      sudo chmod a+r /etc/profile.d/chruby.sh
    )
    fi
}

install_ruby_build() {
    echo . ; echo . ;  echo Installing ruby-build ...
    if which ruby-build
    then
      echo ruby-build already installed
    else
    (
      cd /tmp
      git clone https://github.com/rbenv/ruby-build.git
      sudo env PREFIX=/usr/local ./ruby-build/install.sh
      sudo mkdir -p /opt/rubies
    )
    fi
}

install_ruby_version() {
    echo . ; echo . ;  echo Checking ruby version
    v=''
    if [ -s $app_root/.ruby-version ] ; then
        v=`cat $app_root/.ruby-version`
        if [ -n "$v" ] ; then
            dest=/opt/rubies/$v
            if [ -x $dest/bin/ruby ] ; then
              echo $dest already created
            else
                ruby-build ${v} ${dest}
                case "$v" in
                1.8*)
                    ${dest}/bin/gem update --system 1.8.25
                    ;;
                esac
                if [[ $EUID -eq 0 ]]; then
                    echo "Skipping installing bundler - it should not be run as root"
                else
                    ${dest}/bin/gem install bundler
                fi
            fi
        fi
    fi
    if [ -s $app_root/.ruby-versions ] ; then
        while read v
        do
            if [ -n "$v" ] ; then
                dest=/opt/rubies/$v
                if [ -x $dest/bin/ruby ] ; then
                  echo $dest already created
                else
                    ruby-build ${v} ${dest}
                    case "$v" in
                    1.8*)
                        ${dest}/bin/gem update --system 1.8.25
                        ;;
                    esac
                    if [[ $EUID -eq 0 ]]; then
                        echo "Skipping installing bundler - it should not be run as root"
                    else
                        ${dest}/bin/gem install bundler
                    fi
                fi
            fi
        done < $app_root/.ruby-versions
    fi
}

install_standard_packages()
{
    echo . ; echo . ;  echo Installing standard tools, libraries and build environment
    install_package vim-nox tmux apt-transport-https \
        qt4-qmake curl git-core python-software-properties \
        insserv subversion
}

provision_machine()
{
    #[ -d /vagrant ] || ( echo Must be run in vagrant VM ; exit 1)
    #egrep 'Trusty' /etc/os-release > /dev/null || exec echo Only designed for Trusty at present!

    update_apt

    install_standard_packages

    add_swap_if_needed

    first_time_ruby=true
    first_time_elixir=true

    for app_root
    do

        if [ gui = $app_root ] ; then
            install_package lubuntu-core
        fi

        if [ mysql-server = $app_root ] ; then
            if [ -t 0 -a -t 1 ] ; then
                echo . ; echo . ; echo Installing with manual setting of passwords
                install_package mysql-server
                echo Securing mysql
                mysql_secure_installation
            else
                if [ -f /root/.my.cnf ] ; then
                    echo "Mysql has already been installed by this script..."
                else
                    echo . ; echo . ; echo Unattended install of mysql-server
                    echo Generating a random password
                    pass=`tr -dc A-Za-z0-9 < /dev/urandom | head -c10`
                    if [ -z "$pass" ] ; then
                      pass=randomword
                    fi
                    echo -e "[client]\nuser=root\npassword=${pass}" | sudo tee /root/.my.cnf
                    sudo chmod 600 /root/.my.cnf
                    echo Setting default responses for install ...
                    echo "mysql-server-5.6 mysql-server/root_password password ${pass}" | sudo debconf-set-selections
                    echo "mysql-server-5.6 mysql-server/root_password_again password ${pass}" | sudo debconf-set-selections
                    install_package mysql-server
                    echo Securing mysql
                    echo -e "${pass}\nn\nY\nY\nY\nY\n" | mysql_secure_installation
                    echo . ; echo . ; echo Creating users ...

                fi
            fi
            sudo service mysql restart

            if [ -n "$db_prefix" ] ; then
                user_results=`echo "select host, user from mysql.user where user = '${db_user}';" | sudo mysql --defaults-extra-file=/root/.my.cnf`
                if [ -n "$user_results" ] ; then
                  echo "User is defined:"
                  echo "$user_results"
                else                
                  echo "CREATE USER '${db_user}'@'localhost' IDENTIFIED BY '${db_password}'; " | \
                    sudo mysql --defaults-extra-file=/root/.my.cnf 
                fi
                echo "GRANT ALL ON \`${db_prefix}\_%\`.* TO '${db_user}'@'localhost'; " | \
                  sudo mysql --defaults-extra-file=/root/.my.cnf 
            fi
        fi
        
        # Projects requiring extra entries in /etc/hosts
        
        extra_host_entries_file=$app_root/config/etc-hosts-entries
        if [ -s $extra_host_entries_file ]
        then
          while read line
          do
              if [ -n "`grep "$line" /etc/hosts`" ] ; then
                  echo "Already in /etc/hosts: $line"
              else
                  echo "Adding to /etc/hosts: $line"
                  echo "$line" | sudo tee -a /etc/hosts
              fi
          done < $extra_host_entries_file
        fi

        # Ruby projects
        if [ -s $app_root/Gemfile ] ; then
            install_gem_packages capybara-webkit qt5-default libqt5webkit5-dev gstreamer1.0-plugins-base gstreamer1.0-tools gstreamer1.0-x
            install_gem_packages cld3 pkgconf protobuf zlib1g-dev
            install_gem_packages libxml libxml2
            install_gem_packages listen inotify
            install_gem_packages memcache memcached
            install_gem_packages image_science libfreeimage-dev
            install_gem_packages mysql mysql-client libmysqlclient-dev
            install_gem_packages nokogiri libxml2 libxslt1-dev zlib1g-dev
            install_gem_packages pg postgresql-client
            install_gem_packages redi redis-server
            install_gem_packages rmagick ImageMagick libmagickwand-dev
            install_gem_packages sqlite slite3 libsqlite3-dev
            install_gem_packages therubyracer nodejs
            install_gem_packages typhoeus curl
        fi
        if [ -s $app_root/Gemfile -o -s $app_root/.ruby_version -o ruby = $app_root ] ; then
            if $first_time_ruby ; then
                first_time_ruby=false
                : ruby-build/wiki suggested-build-environment
                install_package gcc autoconf bison build-essential libssl-dev libyaml-dev libreadline-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm3 libgdbm-dev
                install_chruby
                install_ruby_build
            fi
            install_ruby_version
            if [ -s $app_root/Gemfile -a -s $app_root/.ruby-version ] ; then
                if [[ $EUID -eq 0 ]]; then
                    echo "Skipping bundle install - it should not be run as root"
                else
                    (                        
                        echo . ; echo . ; echo Running bundler to install gems ...
                        cd $app_root
                        chruby-exec `cat .ruby-version` -- bundle install
                    )
                fi
            fi
        fi

        # Elixir projects
        if [ -s $app_root/mix.exs ] ; then
            echo "TO DO: examine mix.exs!!"
            #        install_mix_packages cld3 pkgconf protobuf zlib1g-dev
            #        install_mix_packages libxml libxml2
            #        install_mix_packages listen inotify
            #        install_mix_packages memcache memcached
            #        install_mix_packages mysql mysql-client
            #        install_mix_packages nokogiri libxml2 libxslt1-dev zlib1g-dev
            #        install_mix_packages pg postgresql-client
            #        install_mix_packages redi redis-server
            #        install_mix_packages rmagick ImageMagick
            #        install_mix_packages sqlite slite3
            #        install_mix_packages therubyracer nodejs
            #        install_mix_packages typhoeus curl
        fi
        if [ -s $app_root/mix.exs -o elixir = $app_root ] ; then
            if $first_time_elixir ; then
                first_time_elixir=false
                echo "TO DO: install erlang/elixir packages"
                #        install_package gcc autoconf bison build-essential libssl-dev libyaml-dev libreadline-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm3 libgdbm-dev
                #        install_erlang
                #        install_ruby_build
            fi
        fi
    done
}

#Do we need?:
#  linux-headers-generic linux-headers-`uname -r` \
#  libxslt1-dev libxml2-dev    \
#  libcurl4-openssl-dev libqt4-dev  \
#  libmysqlclient-dev

provision_machine "$@"

echo "Completed provision.sh script!"
