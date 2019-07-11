# IO (Digital Citizenship) Ansible confiuration files

## Prerequisites

* The recommended version of Ansible is 2.7+

* The shared private key contained within the vault with secret name "terraformsshkey".\
Saved as `/home/<your user>/.ssh/daf_id_rsa`

## Ansible playbooks how to

Generally, Ansible playbooks are run against VMs pre-provisioned on Azure using Terraform and Terragrunt.

## How to run playbooks

```shell
ansible-playbook YOUR_PLAYBOOK -i inventory/YOUR_INVENTORY -K
```

* YOUR_PLAYBOOK is the playbook to 
* YOUR_INVENTORY is the inventory to use. Choices are *hosts-dev*, *hosts-staging*, *hosts-prod* 
* -K will ask for sudo password at command line

If you want to customize the ssh key path used to connect, just run ansible with extra-vars option

```shell
ansible-playbook YOUR_PLAYBOOK -i inventory/YOUR_INVENTORY -K --extra-vars "ansible_ssh_private_key_file=/my_customdir/my_key"
```

## How to download Ansible requirements

Often playbooks need additional software to run. These packages are downloaded using `ansible-galaxy`:

```shell
ansible-galaxy install --force --roles-path roles_galaxy -r REQUIREMENTS-FILE.yml
```

For example:

```shell
ansible-galaxy install --force --roles-path roles_galaxy -r openvpn-requirements.yml
```

## How to connect to hosts

In most of the cases hosts should be reachable via their private IP address / DNS name, through a VPN connection previously established.

## The special case of OpenVPN and FreeIPA: initial setup

OpenVPN is used to provide VPN access to the management infrastructure.

The OpenVPN machine has two interfaces: one public, facing the Internet, and one facing the other private networks of the infrastructure.

Besides very few cases, none of the hosts should be publicly accessible through the Internet using SSH.

One of these very few special cases is the VPN server itself, while it's setup.

The paragraph describes how to properly configure the systems to provide the right access to the users, while keeping the environment safe.

The assumption is that the underlying Azure infrastructure has all been provisioned using the Terraform scripts. 

### 1 - OpenVPN server: make sure the port 22 is open facing Internet

At the very beginning, port 22 facing Internet should be open, otherwise Ansible won't be able to run and the initial setup won't be possible.
This is managed through some Terraform configuration files.

### 2 - Provision the VPN server - certificate based authentication

You should still have public SSH access to the OpenVPN machine.

It's time to install the OpenVPN software and run the first set of configurations.

* Edit the openvpn.yml file and make sure a list of names representing personal certificates is included in the bottom list.
* Download the `openvpn-requirements.yml` using Galaxy.
* Run the OpenVPN playbook.
* Ssh into the OpenVPN server (find the address in the inventory file you're using). Download your personal certificate, located in the `/etc/openvpn` folder. Then, install it in your VPN client and connect to the VPN.
After the VPN has been installed a copy of the file should have also be downloaded on the local client machine performing the configuration under the `/tmp` directory.

### 3 - Close port 22 facing Internet and keep only 443 open

You should now be able to access the infrastructure using the VPN. For security reasons, you should close port 22 facing Internet (using Terraform!) and keep 443 only open.

## Further modifications to the OpenVPN machine

Sometimes, operators may need to execute again the openvpn.yml playbook to set additional configuartion on the OpenVPN machine. This will likely cause the VPN connection to go down. As such, if this kind of operation is done through the private address of the machine some inconsistencies may arise.

Thus, it's strongly suggested to run the Ansible playbook through the public SSH interface of the OpenVPN server. To do this, operators can *temporarily* allow SSH incoming traffic from Internet from the corresponding security group in the Azure portal.
Immediately after the configuration has been changed and having verified that the new configuration works, the port should be closed again.
