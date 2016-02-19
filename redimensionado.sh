#!/bin/bash

# Diego Martín Sánchez
# ASIR IES Gonzalo Nazareno. -Virtualización-

# Configuración básica y redimensionado de vda
sudo sed -i 's/mv1/'"$1"'/g' /etc/hosts
sudo sed -i 's/mv1/'"$1"'/g' /etc/hostname
sudo echo "d\nn\n\n\n\n\nw\nq"|sudo fdisk /dev/vda
sudo partprobe
sudo xfs_growfs /dev/vda1
echo "[OK]"
