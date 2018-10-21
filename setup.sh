#!/bin/bash
set -euo pipefail

########################
### SCRIPT VARIABLES ###
########################

# Name of the user to create and grant sudo privileges
USERNAME=scikit

# Whether to copy over the root user's `authorized_keys` file to the new sudo
# user.
COPY_AUTHORIZED_KEYS_FROM_ROOT=true

# Additional public keys to add to the new sudo user
# OTHER_PUBLIC_KEYS_TO_ADD=(
#     "ssh-rsa AAAAB..."
#     "ssh-rsa AAAAB..."
# )
OTHER_PUBLIC_KEYS_TO_ADD=(
)

####################
### SCRIPT LOGIC ###
####################

# Add sudo user and grant privileges
useradd --create-home --shell "/bin/bash" --groups sudo "${USERNAME}"

# Check whether the root account has a real password set
encrypted_root_pw="$(grep root /etc/shadow | cut --delimiter=: --fields=2)"

if [ "${encrypted_root_pw}" != "*" ]; then
    # Transfer auto-generated root password to user if present
    # and lock the root account to password-based access
    echo "${USERNAME}:${encrypted_root_pw}" | chpasswd --encrypted
    passwd --lock root
else
    # Delete invalid password for user if using keys so that a new password
    # can be set without providing a previous value
    passwd --delete "${USERNAME}"
fi

# Expire the sudo user's password immediately to force a change
chage --lastday 0 "${USERNAME}"

# Create SSH directory for sudo user
home_directory="$(eval echo ~${USERNAME})"
mkdir --parents "${home_directory}/.ssh"

# Copy `authorized_keys` file from root if requested
if [ "${COPY_AUTHORIZED_KEYS_FROM_ROOT}" = true ]; then
    cp /root/.ssh/authorized_keys "${home_directory}/.ssh"
fi

# Add additional provided public keys
for pub_key in "${OTHER_PUBLIC_KEYS_TO_ADD[@]}"; do
    echo "${pub_key}" >> "${home_directory}/.ssh/authorized_keys"
done

# Adjust SSH configuration ownership and permissions
chmod 0700 "${home_directory}/.ssh"
chmod 0600 "${home_directory}/.ssh/authorized_keys"
chown --recursive "${USERNAME}":"${USERNAME}" "${home_directory}/.ssh"

# Disable root SSH login with password
sed --in-place 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
if sshd -t -q; then
    systemctl restart sshd
fi


###############################################
##       Customize server - LEMP             ##
###############################################

add-apt-repository ppa:certbot/certbot -y

apt update
apt install nginx mysql-server-5.7 -y
apt install zip unzip git python-certbot-nginx -y
apt install php-fpm php7.2-cli php-mysql php-pear php7.2-bcmath php7.2-gd php7.2-curl php7.2-xml php7.2-zip php7.2-dev php7.2-mbstring -y

############### skip ufw in GCP ###############
ufw allow 'Nginx Full'
ufw allow OpenSSH
ufw status
sufw --force enable
###############################################


############### prep local user ###################################
curl -L https://storage.googleapis.com/scikit-downloads/server-setup.zip -o /home/scikit/server-setup.zip

unzip /home/scikit/server-setup.zip -d /home/scikit/

############### Adjust Nginx configs for local user ###############
ln -nfs /home/scikit/config/nginx /etc/nginx/sites-enabled


# generate ssh key
ssh-keygen -t rsa -f /home/scikit/.ssh/id_rsa -q -P ""

# install composer
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('SHA384', 'composer-setup.php') === '93b54496392c062774670ac18b134c3b3a95e5a5e5c8f1a9f115f203b75bf9a129d5daa8ba6a13e2cc8a1da0806388a8') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"

mv composer.phar /usr/local/bin/composer

# install phpmyadmin
git clone --depth=1 --branch=STABLE git://github.com/phpmyadmin/phpmyadmin.git /home/scikit/apps/phpmyadmin
cp /home/scikit/apps/phpmyadmin/config.sample.inc.php /home/scikit/apps/phpmyadmin/config.inc.php

# grant www-data write access
chown -R scikit /home/scikit/apps
chown -R scikit /home/scikit/config
chown -R scikit /home/scikit/server-setup.zip
chown -R scikit /home/scikit/.ssh/id_rsa
chown -R scikit /home/scikit/.ssh/id_rsa.pub
chown -R scikit /home/scikit/.ssh/id_rsa.pub
chown -R scikit /usr/local/bin/composer

chgrp -R www-data /home/scikit/apps
chmod -R ug+rwx /home/scikit/apps

chgrp -R www-data /home/scikit/config
chmod -R ug+rwx /home/scikit/config

systemctl reload nginx


# display default ssh key
cat /home/scikit/.ssh/id_rsa.pub

echo "SETUP COMPLETED SUCCESSFULLY"
