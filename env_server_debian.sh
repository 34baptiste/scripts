#!/bin/bash

# ============================================================
#  Script de post-installation Debian
# ============================================================

# Vérifier exécution en root
if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être exécuté en root." 
    exit 1
fi

echo "=== Mise à jour du système ==="
apt update && apt full-upgrade -y && apt autoremove --purge -y


# ============================================================
# Installation SSH
# ============================================================
echo "=== Installation de OpenSSH Server ==="
apt install -y openssh-server

read -p "Voulez-vous changer le port SSH (défaut 22) ? (o/n) : " CHANGE_PORT </dev/tty

if [[ "$CHANGE_PORT" == "o" || "$CHANGE_PORT" == "O" ]]; then
    read -p "Entrez le nouveau port SSH : " SSH_PORT

    sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
    ufw allow "$SSH_PORT"/tcp
    echo "Port SSH modifié et ouvert dans UFW."
else
    SSH_PORT=22
    ufw allow OpenSSH
fi

systemctl restart ssh


# ============================================================
# UFW Firewall
# ============================================================
echo "=== Configuration de UFW ==="
apt install -y ufw
ufw allow "$SSH_PORT"/tcp
ufw --force enable


# ============================================================
# Fixer l'adresse IP
# ============================================================
echo "=== Configuration IP statique ==="
read -p "Nom de l'interface réseau (ex: enp0s3) : " IFACE </dev/tty
read -p "Adresse IP souhaitée (ex: 192.168.1.50) : " IPADDR </dev/tty
read -p "Masque réseau (ex: 255.255.255.0) : " NETMASK </dev/tty
read -p "Passerelle (ex: 192.168.1.1) : " GATEWAY </dev/tty
read -p "DNS (ex: 1.1.1.1 9.9.9.9) : " DNS </dev/tty

INTERFACES_FILE="/etc/network/interfaces"

cp "$INTERFACES_FILE" "${INTERFACES_FILE}.backup"

cat <<EOF > $INTERFACES_FILE
auto lo
iface lo inet loopback

auto $IFACE
iface $IFACE inet static
    address $IPADDR
    netmask $NETMASK
    gateway $GATEWAY
    dns-nameservers $DNS
EOF

systemctl restart networking || echo "Redémarrage du networking échoué (peut être normal sous NetworkManager)."


# ============================================================
# Ajouter utilisateur à sudo
# ============================================================
echo "=== Ajout de l'utilisateur principal dans sudo ==="
apt install -y sudo
read -p "Nom de l'utilisateur principal : " MAINUSER </dev/tty
usermod -aG sudo "$MAINUSER"
echo "Utilisateur $MAINUSER ajouté au groupe sudo."


# ============================================================
# Outils de base
# ============================================================
echo "=== Installation des outils de base ==="
apt install -y curl wget git vim htop net-tools unzip bash-completion


# ============================================================
# Fail2ban
# ============================================================
echo "=== Installation et activation de Fail2ban ==="
apt install -y fail2ban

systemctl enable fail2ban --now

echo "Création d'une configuration basique pour SSH..."
cat <<EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = $SSH_PORT
logpath = /var/log/auth.log
maxretry = 5
EOF

systemctl restart fail2ban


# ============================================================
# Fin
# ============================================================
echo
echo "================================================================="
echo "   Script terminé !"
echo "   - SSH opérationnel sur le port $SSH_PORT"
echo "   - UFW actif"
echo "   - IP fixe configurée"
echo "   - Utilisateur $MAINUSER ajouté à sudo"
echo "================================================================="
echo
