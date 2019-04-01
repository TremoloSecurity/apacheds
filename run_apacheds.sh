#!/bin/bash

# -----------------------------------------------------------------------------
# Control Script for the ApacheDS Server
#
# Environment Variable Prerequisites
#
#   Do not set the variables in this script. Instead put them into 
#   $ADS_HOME/bin/setenv.sh to keep your customizations separate.
#
#   ADS_HOME        (Optional) The directory that contains your apacheds 
#                   install.  Defaults to the parent directory of the
#                   directory containing this script.
#
#   ADS_INSTANCES   (Optional) The parent directory for the instances.
#                   Defaults to $ADS_HOME/instances.
#
#   ADS_CONTROLS    Controls to register.
#
#   ADS_EXTENDED_OPERATIONS
#                   Extended operations to register.
#
#   ADS_INTERMEDIATE_RESPONSES
#                   Intermediate responses to register.
#
#   ADS_SHUTDOWN_PORT
#                   (Optional) If specified, it must be a valid port number
#                   between 1024 and 65536 on which ApacheDS will listen for 
#                   a connection to trigger a polite shutdown.  Defaults to 0
#                   indicating a dynamic port allocation.
#
#   JAVA_HOME       (Optional) The java installation directory.  If not
#                   not specified, the java from $PATH will be used.
#
#   JAVA_OPTS       (Optional) Any additional java options (ex: -Xms:256m)

set -m

CLASSPATH=$(JARS=("$ADS_HOME"/lib/*.jar); IFS=:; echo "${JARS[*]}")

ADS_INSTANCE="$ADS_INSTANCES/$ADS_INSTANCE_NAME"

ADS_OUT="$ADS_INSTANCE/log/apacheds.out"
ADS_PID="$ADS_INSTANCE/run/apacheds.pid"

eval "java $JAVA_OPTS $ADS_CONTROLS $ADS_EXTENDED_OPERATIONS $ADS_INTERMEDIATE_RESPONSES -Dlog4j.configuration=file:/usr/local/apacheds/conf/log4j.properties -Dapacheds.log.dir=$ADS_INSTANCE/log -classpath $CLASSPATH org.apache.directory.server.UberjarMain $ADS_INSTANCE 2>&1 &"

timeout 30 sh -c "while ! nc -z localhost 10389; do sleep 1; done"

echo "ApacheDS Started"

jnum=$(jobs -l | grep " $! " | sed 's/\[\(.*\)\].*/\1/')
echo "Backgroung job number: $jnum"

fg $jnum