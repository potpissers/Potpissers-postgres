#!/bin/bash

while true; do
    git fetch origin
    git reset --hard origin/master

    echo Server restarting...
    echo Press CTRL + C to stop.
done
