#!/bin/bash

export PATH=$PATH:~/.local/bin
pip install konsave
konsave -i $HOME/$SCRIPTHOME/configs/kde.knsv
sleep 1
konsave -a kde
