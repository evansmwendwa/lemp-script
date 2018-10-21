## LEMP - Linux Nginx Mysql PHP setup script

This script is extremely experimental and might not be optimized for most scenarios.
This is customized to my personal use and I assume no liability whatsoever

If you proceed to use it make sure to customize to your own setup


### Instructions

This script is will perform a PHP7.2 setup on any Ubuntu server. Tested in Ubuntu 18 LTS

**NB:** It's highly customized for my personal use and makes several modifications to how the server operates

Assumes `cert.key` and `cert.pem` ssl files are available in `/config/ssl` directory

This follow Digital oceans initial server setup at https://www.digitalocean.com/community/tutorials/automating-initial-server-setup-with-ubuntu-18-04

Copy script to your new server

```
bash setup.sh
```
