#!/bin/sh
if [ -r /etc/default/locale ]; then
    . /etc/default/locale
    export LANG LANGUAGE
fi

# Start XFCE session
exec startxfce4
