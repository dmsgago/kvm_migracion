#!/bin/bash

# Diego Martín Sánchez
# ASIR IES Gonzalo Nazareno. -Virtualización-

# Consulta y almacena la IP de la máquina
ip=$(virsh net-dhcp-leases default|grep correcaminos| egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')

# Comenta vdb en el fichero /etc/fstab
echo "Comentando /etc/fstab..."
linea=$(cat /etc/fstab|grep 'postgresql xfs')
sed -i 's%'"$linea"'%#'"$linea"'%g' /etc/fstab
echo "[OK]"

# Clonacion del disco raiz y la swap
echo "\nClonando el disco raiz..."
lvcreate --size 3G --snapshot --name s_kvmraiz /dev/sistema/kvm_raiz_mv1
dd if=/dev/sistema/s_kvmraiz of=/tmp/kvmraiz.raw
lvcreate --name kvm_raiz_mv2 --size 3G sistema
dd if=/tmp/kvmraiz.raw of=/dev/sistema/kvm_raiz_mv2
echo "[OK]"

# Clonación de la máquina
echo "\nClonando la máquina..."
virsh detach-disk correcaminos vdb
virsh dumpxml correcaminos>/tmp/correcaminos.xml
uuid=$(cat /proc/sys/kernel/random/uuid)
mac=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//')
luuid=$(cat /tmp/correcaminos.xml |grep \<uuid\>)
lname=$(cat /tmp/correcaminos.xml |grep \<name\>)
lmemory=$(cat /tmp/correcaminos.xml |grep \<memory\ unit)
lmemory2=$(cat /tmp/correcaminos.xml |grep \<currentMemory)
lmac=$(cat /tmp/correcaminos.xml |grep \<mac\ address)
read -p "Nombre de la nueva máquina: " name
sed 's%'"$lname"'%  <name>'"$name"'</name>%g' /tmp/correcaminos.xml
sed 's%'"$luuid"'%  <uuid>'"$uuid"'</uuid>%g' /tmp/correcaminos.xml
sed 's%'"$lmemory"'%  <memory unit\='\'"KiB"\''>1048576</memory>%g'
sed 's%'"$lmemory2"'%  <currentMemory unit\='\'"KiB"\''>1048576</currentMemory>%g'
sed 's%'"$lmac"'%    <mac address\='"\'$mac\'"'/>%g'
mv /tmp/correcaminos.xml /etc/libvirt/qemu/$name.xml
virsh define /etc/libvirt/qemu/$name.xml
virsh start coyote
echo "[OK]"

# Espera a que la máquina se levante
echo "\nConfigurando la máquina $name..."
sleep 20
ip2=$(virsh net-dhcp-leases default|grep $name| egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')

# Configuración básica y redimensionado de vda
ssh usuario@$ip2 'sudo echo "127.0.0.1 localhost\n127.0.1.1 $name" > /etc/hosts'
ssh usuario@$ip2 'sudo echo "$name" > /etc/hostname'
ssh usuario@$ip2 'sudo echo "d\nn\n\n\n\n\nw\nq"|fdisk /dev/vda'
ssh usuario@$ip2 'sudo partprobe'
ssh usuario@$ip2 'sudo xfs_growfs /dev/vda1'
echo "[OK]"

# Migración de vdb
echo "\nMigración de los datos de PostgreSQL..."
virsh detach-disk correcaminos /dev/sistema/kvm_psql_mv1
lvextend -L +1G /dev/sistema/kvm_psql_mv1
virsh attach-disk coyote /dev/sistema/kvm_psql_mv1 vdb
ssh usuario@$ip2 'sudo mount /dev/vdb /var/lib/postgresql/'
ssh usuario@$ip2 'sudo xfs_growfs /dev/vdb'
ssh usuario@$ip2 'sudo systemctl restart postgresql'
