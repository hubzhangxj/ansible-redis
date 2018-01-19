#!/bin/bash

ansible-playbook -i hosts site.yml --user=root --extra-vars "ansible_sudo_pass=root"  

