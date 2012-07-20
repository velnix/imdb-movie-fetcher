#!/bin/bash
#installer version 1.1
if [ ! -w /usr/local/bin ]
then
printf "You don't have the sufficient privilege to install this. Are you not root ?\n"
exit 192
fi
install -Dm755 imdb-mf.sh /usr/local/bin/imdb-mf
install -Dm755 imdb-mf.conf /etc/imdb-mf.conf
if [ $? -eq 0 ]
then
printf "Installation completed. Execute \"imdb-mf -h\" for more info\n"
else
printf "Something went wrong. This script is unable to install the program\n"
exit 192
fi
exit 0
