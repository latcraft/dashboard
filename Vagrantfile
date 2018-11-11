
Vagrant.configure("2") do |config|
  
  config.vm.box = "aestasit/devops-ubuntu-16.04"
  config.vm.hostname = "devternity-smashing"  
  config.vm.network "private_network", ip: "192.168.111.201"

  config.vm.provider "virtualbox" do |vb|
    vb.name = "devternity-smashing"
    vb.customize ["modifyvm", :id, "--memory", "2048"]
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end

  config.vm.provision "shell", inline: "cd /vagrant && sudo ./run-docker.sh"

end


