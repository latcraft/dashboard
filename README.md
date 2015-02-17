LatCraft Event Dashboard
==========================

This is an official dashboard for LatCraft community events. Implementation is based on Shopify's Dashing.

<img src="https://raw.githubusercontent.com/latcraft/dashboard/master/assets/images/preview.png" />

Run within Vagrant
===========================

1. Install VirtualBox with extensions
2. Install Vagrant
3. Create `config/latcraft.yml` with proper API keys and secrets.
4. `vagrant up`
5. `vagrant ssh`
6. `cd /vagrant`
7. `sudo dashing start`
8. <http://192.168.78.11:3030/event>

To run this dashboard in any other environment you can "replay" same commands that appear in `Vagrantfile`'s shell provisioner.

