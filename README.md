# IO (Digital Citizenship) infrastructure post configuration scripts

The repository contains the Ansible scripts and Kubernetes files used to configure IO resources after they've been instantiated with [Terraform](https://github.com/teamdigitale/io-infrastructure-live).

## What is IO?

More informations about the IO can be found on the [Digital Transformation Team website](https://teamdigitale.governo.it/en/projects/digital-citizenship.htm)

## Tools references

The repository makes mainly use of the following tools:

* [Ansible](https://www.ansible.com/)
* [Kubernetes](https://kubernetes.io/)

## How to use this repository and its tools

The repository is a collection of scripts to run in the IO infrastructure to configure various types of resources (i.e. VMs, containers, ...), previously provisioned using some [Terraform scripts](https://github.com/teamdigitale/io-infrastructure-live).

To configure the PDND infrastructure you should have full access to it with administrative privileges.

More specific informations about how to use the scripts are included in the sub-folders Ansible and Kubernetes of this repository.

## How to contribute

Contributions are welcome. Feel free to open issues and submit [pull requests](./pulls) at any time, but please read [our handbook](https://github.com/teamdigitale/io-handbook) first.

## License

Copyright (c) 2019 Presidenza del Consiglio dei Ministri

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program.  If not, see <https://www.gnu.org/licenses/>.
