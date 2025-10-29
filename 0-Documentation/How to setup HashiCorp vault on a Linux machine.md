
Author: Ofir and Irakli
How to setup HashiCorp vault on a Linux machine

first SSH into a Linux machine
ssh 192.168.1.195 -p 6005 -l blueteam
ssh -J root@192.168.1.195 blueteam@10.0.2.24

on the Linux machine run the following commands to install require packages:
sudo apt update && sudo apt install unzip curl gpg apt-transport-https -y

run the following command to add the hashicorp Repo:
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list

run the following command to install the vault:
sudo apt update && sudo apt install vault -y

change the vault.hcl config file to look like the following:
ui = true

storage "file" {
	path = "/opt/vault/data"
}

listener "tcp" {
	adress       = "0.0.0.0:8200"
	tls_disable = 1
}

api_addr = "http://0.0.0.0:8200"
cluster_name = "vault-cluster"
log-level = "info"

run the following to enable and start the vault:
sudo systemctl enable vault
sudo systemctl restart vault

then run the following command that will generate 5 unseal keys and a Initial root token
vault operator init

Unseal the vault by running the following command 3 times with a different unseal key each time:
vault operator unseal

lastly set up a port forward using 8200 as the port



