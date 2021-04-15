#!/bin/bash

while true
do
    echo 'matando al proceso de la vpn'
    MATANDO_PROCESO=$(pkill openfortivpn)
    sleep 1
done