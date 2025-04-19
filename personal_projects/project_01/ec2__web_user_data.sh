#!/bin/bash
yum install httpd
systemctl start httpd
systemctl enable httpd
touch /var/www/html/index.html
INSTANCE_HOSTNAME=$(hostname)
echo "<h1>Web server is up</h1><br><p>Hostname : ${INSTANCE_HOSTNAME}</p>" > /var/www/html/index.html
