#!/bin/bash -e
clear

function install_odoo18() 
{

db_pass=$(date +%s|sha256sum|base64|head -c 18)
db_user = odoo18

# Update the package list to ensure you are installing the latest versions of the packages.
sudo apt-get update
sudo apt-get upgrade -y

# Install Python 3 pip and other essential Python development libraries.
sudo apt-get install -y python3-pip
sudo apt-get install -y python3-dev libxml2-dev libxslt1-dev \
  zlib1g-dev libsasl2-dev libldap2-dev build-essential libssl-dev \
  libffi-dev libmysqlclient-dev libjpeg-dev libpq-dev libjpeg8-dev \
  liblcms2-dev libblas-dev libatlas-base-dev

# Create a symbolic link for Node.js and install Less and Less plugins.
sudo ln -s /usr/bin/nodejs /usr/bin/node
sudo apt install npm
sudo npm install -g less less-plugin-clean-css
sudo apt-get install -y node-less

# Install PostgreSQL (the database used by Odoo) and create a new user for Odoo 18.
sudo apt-get install -y postgresql
sudo su - postgres
createuser --createdb --username postgres --no-createrole --superuser --pwprompt odoo18 <<EOF
${db_pass}
${db_pass}
EOF
exit

# Create a system user for Odoo 18 and install Git to clone the Odoo source code.
sudo adduser --system --home=/opt/odoo18 --group odoo18
sudo apt-get install -y git
sudo su - odoo18 -s /bin/bash

git clone https://www.github.com/odoo/odoo --depth 1 --branch master --single-branch .


exit

# Install Python virtual environment and set up the Odoo environment.
sudo apt install -y python3-venv
sudo python3 -m venv /opt/odoo18/venv

# Switch to root, navigate to the Odoo directory, activate the virtual environment, and install required Python packages.
sudo -s
cd /opt/odoo18/
source venv/bin/activate
pip install -r requirements.txt

# Install wkhtmltopdf (used for printing PDF reports in Odoo) and resolve any missing dependencies.
if type curl >/dev/null 2>&1; then
    sudo curl https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb
else
    sudo wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb
fi

if type curl >/dev/null 2>&1; then
    sudo curl http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
else
    sudo wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
fi

sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb
sudo apt-get install -y xfonts-75dpi
sudo dpkg -i wkhtmltox_0.12.5-1.bionic_amd64.deb
sudo apt install -f
deactivate

# Configure the Odoo instance by copying the default config file and editing it to suit your needs.
# Odoo configuration file settings, including database connection and log file location.

sudo cp /opt/odoo18/debian/odoo.conf /etc/odoo18.conf
cat > /etc/odoo18.conf <<EOL
[options]
; This is the password that allows database operations:
; admin_passwd = admin
db_host = localhost
db_port = 5432
db_user = odoo18
db_password = ${db_pass}
addons_path = /opt/odoo18/addons
default_productivity_apps = True
logfile = /var/log/odoo/odoo18.log
EOL

# Set correct permissions on the Odoo configuration file to ensure security.
sudo chown odoo18: /etc/odoo18.conf
sudo chmod 640 /etc/odoo18.conf

# Create a directory for Odoo log files and set appropriate ownership.
sudo mkdir /var/log/odoo
sudo chown odoo18:root /var/log/odoo

# Create a systemd service file for Odoo 18 to manage it as a service.
# Odoo systemd service configuration.

#sudo nano /etc/systemd/system/odoo18.service

ODOO_PYTHON=$(ls /opt/odoo18/venv/bin/ | awk '/python3./ { print $1 }'); 
echo "/opt/odoo18/venv/bin/${ODOO_PYTHON}"

cat >> /etc/systemd/system/odoo18.service <<EOL
[Unit]
Description=Odoo18
Documentation=http://www.odoo.com
[Service]
# Ubuntu/Debian convention:
Type=simple
User=odoo18
ExecStart=/opt/odoo18/venv/bin/${ODOO_PYTHON} /opt/odoo18/odoo-bin -c /etc/odoo18.conf
[Install]
WantedBy=default.target
EOL

# Set permissions and ownership on the systemd service file.
sudo chmod 755 /etc/systemd/system/odoo18.service
sudo chown root: /etc/systemd/system/odoo18.service

# Start the Odoo 18 service and access Odoo from the browser.
sudo systemctl start odoo18.service

gateway=$(ip route show | awk '/default/ { print $3 }');
IP_address=$(ip route show | awk '/default/ { print $9 }');


echo "
DB DATA
===================
DB User: ${db_user}
DB password: ${db_pass}
#############################
" >> ~/.requirements
cat ~/.requirements
echo "Open in browser http://${IP_address}:8069"


# documentation www.odoo.com/documentation/master/index.html

clean
echo "ODOO 18 - Installed"
sleep 5
exit
}

install_odoo18

