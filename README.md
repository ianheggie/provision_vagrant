# provision_vagrant
Provision Vagrant for use in developing and testing a ruby app/gem or elixir app (ubuntu LTS)

Local and Vagrant shell provisioner for rails / elixir projects
===============================================================

These scripts are for my own projects, and thus is not trying to be all things to all people,
just all the things I care about for me.

It can be used in two different ways:
1. Copy provision to bin/provision for configuring your local dev system using my latest script
2. Add the following to Vagrantfile:
```
    config.vm.provision "shell",
     path: "https://raw.githubusercontent.com/ianheggie/provision_vagrant/master/provision?cache_bust=#{Process.pid}",
     args: %w{ --prefix myproject mysql-server /vagrant }
```
3. Copy provision.sh to bin/provision and adjust as needed (doesn't track my changes)

My intent is that each project I do will have a bin/provision for the local system and Vagrantfile provisioning
that will setup whatever is required to develop and test the software.

I choose to:
1. save the root mysql password in /root/.my.cnf and lock mysql down.
2. use chruby and ruby-build

Some ideas come from the rails engine from nanobox (to textually inspect Gemfile* and install packages based on strings found within).

This script is not intended to replace using ansible or nanobox for staging or production systems 
as this script installs packages but does minimal configuration of the system!

This script is intended to be run under human supervision by experienced developers on trusted source, not as a frequently run automated process.

Your millage may vary - there is no warranty - if it breaks, you get to keep the pieces!

# Contributions

Feel free to fork the project and add stuff I havn't thought of.
I am interested in hearing what you do with it.

