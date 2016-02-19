# Comenta vdb en el fichero /etc/fstab
echo "Comentando /etc/fstab..."
linea=$(sudo cat /etc/fstab|grep 'postgresql xfs')
sudo sed -i 's%'"$linea"'%#'"$linea"'%g' /etc/fstab
echo "[OK]"
