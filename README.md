# provision_vagrant
Provision Vagrant for use in developing and testing a ruby app/gem or elixir app (ubuntu LTS)

Local and Vagrant shell provisioner for rails / elixir projects
===============================================================

This script is for my own projects, and thus is not trying to be all things to all people,
just all the things I care about for me.

It can be used in two different ways:
1. Copy provision_gist.sh to bin/provision for configuring your local dev system
2. Add the following to Vagrantfile:
```
    config.vm.provision "shell",
     path: "https://gist.githubusercontent.com/ianheggie/978f54360dd00f8e8f2494c229f63459/raw/provision.sh?cache_bust=#{Process.pid}",
     args: %w{ --prefix myproject mysql-server /vagrant }
```

My intent is that each project I do will have a bin/provision for the local system and Vagrantfile provisioning
that will setup whatever is required to develop and test the software.

My choice is to:
1. save the root mysql password in /root/.my.cnf and lock mysql down.
2. use chruby and ruby-build

Some ideas come from the rails engine from nanobox (to textually inspect Gemfile* and install packages based on strings found within).

This script is not intended to replace using ansible or nanobox for staging or production systems 
as this script installs packages but does minimal configuration of the system.
This script is intended to be run under human supervision on trusted source, not as a frequently run automated process.

Your millage may vary - if it breaks, you get to keep the pieces!
