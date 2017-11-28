
Vagrant.configure("2") do |config|
  
  config.vm.box = "aestasit/devops-ubuntu-14.04"
  config.vm.hostname = "devternity-dashing"  
  config.vm.network "private_network", ip: "192.168.111.201"

  config.vm.provider "virtualbox" do |vb|
    vb.name = "devternity-dashing"
    vb.customize ["modifyvm", :id, "--memory", "2048"]
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end

  config.vm.provision "shell", inline: "cd /vagrant && sudo ./run-docker.sh"

end


