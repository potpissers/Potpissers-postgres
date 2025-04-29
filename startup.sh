#!/bin/bash

while true; do
    git fetch origin
    git reset --hard origin/master

    psql -U postgres -d potpissers -f main.sql
    sudo -u postgres psql -d potpissers

    echo Server restarting...
    echo Press CTRL + C to stop.
done
