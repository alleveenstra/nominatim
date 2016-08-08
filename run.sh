#!/bin/sh

# Command prefix that runs the command as the web user
asweb="setuser www-data"

die () {
    msg=$1
    echo "FATAL ERROR: " msg > 2
    exit
}

_startservice () {
    service $1 start || die "Could not start $1"
}

startdb () {
    _startservice postgresql
}

initdb () {
    echo "Initialising postgresql"
    if [ -d /var/lib/postgresql/9.3/main ] && [ $( ls -A /var/lib/postgresql/9.3/main | wc -c ) -ge 0 ]
    then
        die "Initialisation failed: the directory is not empty: /var/lib/postgresql/9.3/main"
    fi
    mkdir -p /var/lib/postgresql/9.3/main && chown -R postgres /var/lib/postgresql/
    sudo -u postgres -i /usr/lib/postgresql/9.3/bin/initdb --pgdata /var/lib/postgresql/9.3/main
    ln -s /etc/ssl/certs/ssl-cert-snakeoil.pem /var/lib/postgresql/9.3/main/server.crt
    ln -s /etc/ssl/private/ssl-cert-snakeoil.key /var/lib/postgresql/9.3/main/server.key
    sudo -u postgres echo "host all  all    0.0.0.0/0  trust" >> /etc/postgresql/9.3/main/pg_hba.conf
    sudo -u postgres echo "listen_addresses='*'" >> /etc/postgresql/9.3/main/postgresql.conf
    sudo /app/src/configPostgresql.sh
}

createuser () {
    echo "Creating user $USER"
    setuser postgres createuser -ds root
    setuser postgres createuser -ds www-data
    setuser postgres createuser -ds nominatim
}

import () {
    echo "Importing ${import} into nominatim"
    /app/src/utils/setup.php --osm-file /maps/import.pbf --all --threads 16
}

dropdb () {
    echo "Dropping database"
    cd /var/www
    dropdb nominatim
}

cli () {
    echo "Running bash (hint, run with -it)"
    /bin/bash
}

startservices () {
    _startservice postgresql
    _startservice apache2
}

help () {
    cat /usr/local/share/doc/run/help.txt
}

_wait () {
    WAIT=$1
    NOW=`date +%s`
    BOOT_TIME=`stat -c %X /etc/container_environment.sh`
    UPTIME=`expr $NOW - $BOOT_TIME`
    DELTA=`expr 5 - $UPTIME`
    if [ $DELTA -gt 0 ]
    then
	sleep $DELTA
    fi
}

# Unless there is a terminal attached wait until 5 seconds after boot
# when runit will have started supervising the services.
if ! tty --silent
then
    _wait 5
fi

# Execute the specified command sequence
for arg 
do
    $arg;
done

echo "*** Ran all commands..."

# Unless there is a terminal attached don't exit, otherwise docker
# will also exit
if ! tty --silent
then
    # Wait forever (see
    # http://unix.stackexchange.com/questions/42901/how-to-do-nothing-forever-in-an-elegant-way).
    tail -f /dev/null
fi
