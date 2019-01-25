#!/bin/bash
# To run this script without download, type the following in a terminal:
# TODO set the correct URL and branch here
# curl -fL https://raw.githubusercontent.com/MaxGaukler/hyst/dev/install_on_ubuntu_18_04.sh | sudo bash
sudo apt-get update
sudo apt-get -qy install git
cd ~
# TODO set the correct URL and branch here
git clone https://github.com/MaxGaukler/hyst --branch=dev --depth=1
cd hyst
sudo ./install_on_ubuntu_18_04.sh
