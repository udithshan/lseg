#!/bin/bash -v

sudo apt install git

aws configure set default.region us-east-1
a=`aws rds describe-db-instances  --query 'DBInstances[*].["Endpoint"."Address"]' | grep rds`
newdb=`echo $a | sed 's/^.\(.*\).$/\1/'`

final=`echo "'$newdb',"`

git clone https://github.com/drupal/drupal.git

sudo cp -R drupal /opt/bitnami/

olddb=`cat /opt/bitnami/drupal/sites/default/settings.php | grep rds.amazonaws.com | awk '{print $3}'`
sudo sed -i "s/$olddb/$final/g" /opt/bitnami/drupal/sites/default/settings.php
