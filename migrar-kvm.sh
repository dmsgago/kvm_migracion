#!/bin/bash

# Diego Martín Sánchez
# ASIR IES Gonzalo Nazareno. -Virtualización-

# Consulta y almacena la IP de la máquina
ip=$(virsh net-dhcp-leases default|grep mv1| egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')

# Copia los scripts necesarios a la máquina de destino.
echo ip: $ip
scp fstab.sh usuario@$ip:~/

# Permisos de ejecución
ssh usuario@$ip sudo chmod 755 fstab.sh

# Comenta vdb en el fichero /etc/fstab
ssh usuario@$ip ./fstab.sh

# Clonacion del disco raiz y la swap
echo -e "\nClonando el disco raiz..."
lvcreate --size 3G --snapshot --name s_kvmraiz /dev/sistema/kvm_raiz_mv1
dd if=/dev/sistema/s_kvmraiz of=/tmp/kvmraiz.raw
lvcreate --name kvm_raiz_mv2 --size 3G sistema
dd if=/tmp/kvmraiz.raw of=/dev/sistema/kvm_raiz_mv2
echo [OK]

# Clonación de la máquina
echo -e "\nClonando la máquina..."
virsh detach-disk mv1 vdb
virsh dumpxml mv1>/tmp/mv1.xml
uuid=$(cat /proc/sys/kernel/random/uuid)
mac=$(echo c2:$(openssl rand -hex 5 | sed 's/\(..\)/\1:/g; s/.$//'))
luuid=$(cat /tmp/mv1.xml |grep \<uuid\>)
lname=$(cat /tmp/mv1.xml |grep \<name\>)
lmemory=$(cat /tmp/mv1.xml |grep \<memory\ unit)
lmemory2=$(cat /tmp/mv1.xml |grep \<currentMemory)
lmac=$(cat /tmp/mv1.xml |grep \<mac\ address)
read -p "Nombre de la nueva máquina: " name
sed -i 's%'"$lname"'%  <name>'"$name"'</name>%g' /tmp/mv1.xml
sed -i 's%'"$luuid"'%  <uuid>'"$uuid"'</uuid>%g' /tmp/mv1.xml
sed -i 's%'"$lmemory"'%  <memory unit\='\'"KiB"\''>1048576</memory>%g' /tmp/mv1.xml
sed -i 's%'"$lmemory2"'%  <currentMemory unit\='\'"KiB"\''>1048576</currentMemory>%g' /tmp/mv1.xml
sed -i 's%'"$lmac"'%    <mac address\='"\'$mac\'"'/>%g' /tmp/mv1.xml
mv /tmp/mv1.xml /etc/libvirt/qemu/$name.xml
virsh define /etc/libvirt/qemu/$name.xml
virsh start $name
echo [OK]

# Espera a que la máquina se levante
echo -e "\nConfigurando la máquina $name..."
ip2=""
while [[ -z $ip2 ]]
do
    ip2=$(virsh net-dhcp-leases default|grep $mac| egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
    sleep 2
done

# Configuración básica y redimensionado de vda
scp redimensionado.sh usuario@$ip2:~/
ssh usuario@$ip2 sudo chmod 755 redimensionado.sh
ssh usuario@$ip2 ./redimensionado.sh $name

# Migración de vdb
echo -e "\nMigración de los datos de PostgreSQL..."
virsh detach-disk mv1 /dev/sistema/kvm_psql_mv1
lvextend -L +1G /dev/sistema/kvm_psql_mv1
virsh attach-disk mv2 /dev/sistema/kvm_psql_mv1 vdb
scp postgre.sh usuario@$ip2:~/
ssh usuario@$ip2 sudo chmod 755 postgre.sh
ssh usuario@$ip2 ./postgre.sh
