#!/bin/bash
sudo apt update 
sudo apt install python3-pip -y
sudo pip3 install flask
curl https://raw.githubusercontent.com/vFawzi/securitylabs/main/test.py -o test.py
sudo python3 test.py
