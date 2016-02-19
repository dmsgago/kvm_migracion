#!/bin/bash

# Diego Martín Sánchez
# ASIR IES Gonzalo Nazareno. -Virtualización-

sudo mount /dev/vdb /var/lib/postgresql/
sudo xfs_growfs /dev/vdb
sudo systemctl restart postgresql
echo [OK]
