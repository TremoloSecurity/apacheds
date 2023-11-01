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

if [[ -f /etc/apacheds/apacheds.jks ]]
then
    echo "Starting TLS"

    ldapmodify -H ldap://127.0.0.1:10389 -D uid=admin,ou=system -w secret <<EOF
dn: ads-serverId=ldapServer,ou=servers,ads-directoryServiceId=default,ou=config
changeType: modify
replace: ads-keystoreFile
ads-keystoreFile: /etc/apacheds/apacheds.jks
-
replace: ads-certificatePassword
ads-certificatePassword: $APACHEDS_TLS_KS_PWD
-

EOF
else
    echo "/etc/apacheds/apacheds.jks does not exist, not starting TLS"
fi

echo "Deleting example partition"
ldapdelete -r  -H ldap://127.0.0.1:10389 -D uid=admin,ou=system -w secret ads-partitionId=example,ou=partitions,ads-directoryServiceId=default,ou=config

ldapmodify -H ldap://127.0.0.1:10389 -D uid=admin,ou=system -w secret <<EOF
version: 1

dn: cn=schema
changeType: modify
add: attributeTypes
attributeTypes: ( 1.2.3.4.5.6.7.8.9.0 NAME 'samAccountName' EQUALITY caseIgnoreMatch SUBSTR caseIgnoreSubstringsMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 SINGLE-VALUE USAGE userApplications X-SCHEMA 'core' )
-

dn: cn=schema
changeType: modify
add: attributeTypes
attributeTypes: ( 1.2.3.4.5.6.7.8.9.1 NAME 'memberOf' EQUALITY caseIgnoreMatch SUBSTR caseIgnoreSubstringsMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 SINGLE-VALUE USAGE userApplications X-SCHEMA 'core' )
-

dn: cn=schema
changeType: modify
add: objectClasses
objectClasses: ( 2.2.3.4.5.6.7.8.9.0 NAME 'user' DESC 'active directory user' SUP top STRUCTURAL MUST ( cn ) MAY ( sn $ userPassword $ mail $ samAccountName $ givenName $ telephoneNumber $ ou $ title $ memberOf $ l ) X-SCHEMA 'core' )

dn: cn=schema
changeType: modify
add: objectClasses
objectClasses: ( 2.2.3.4.5.6.7.8.9.1 NAME 'group' DESC 'active directory group' SUP top STRUCTURAL MUST (  cn ) MAY ( samAccountName $ description $ member ) X-SCHEMA 'core' )

dn: cn=schema
changeType: modify
add: objectClasses
objectClasses: ( 2.2.3.4.5.6.7.8.9.2 NAME 'container' DESC 'active directory container' SUP top STRUCTURAL MUST (  cn ) MAY ( description ) X-SCHEMA 'core' )
-

dn: cn=nis,ou=schema
changetype: modify
delete: m-disabled
m-disabled: TRUE
-
add: m-disabled
m-disabled: FALSE
-

EOF

if [[ -v PRE_RUN_SCRIPT ]]
then
  echo "Running script $PRE_RUN_SCRIPT"
  cp "$PRE_RUN_SCRIPT" /tmp/prerun.sh
  chmod +x /tmp/prerun.sh
  /tmp/prerun.sh
fi

export DN_COMP=`echo "${DN}" | sed 's/,.*//'`
export RDN=${DN_COMP/=/: }
export RDN_VAL=`echo "${DN_COMP}" | sed 's/.*=//'`

export CTX_ENTRY=`base64 -w 0 <<EOF
dn: $DN
objectClass: $OBJECT_CLASS
$RDN
EOF`


ldapmodify -H ldap://127.0.0.1:10389 -D uid=admin,ou=system -w secret -a <<EOF
dn: ads-partitionId=$RDN_VAL,ou=partitions,ads-directoryServiceId=default,ou=config
objectclass: top
objectClass: ads-base
objectclass: ads-partition
objectclass: ads-jdbmPartition
ads-partitionSuffix: $DN
ads-contextentry:: $CTX_ENTRY
ads-jdbmpartitionoptimizerenabled: TRUE
ads-partitioncachesize: 10000
ads-partitionsynconwrite: TRUE
ads-partitionid: $RDN_VAL
ads-enabled: TRUE

dn: ou=indexes,ads-partitionId=$RDN_VAL,ou=partitions,ads-directoryServiceId=default,ou=config
objectclass: organizationalUnit
objectclass: top
ou: indexes


dn: ads-indexAttributeId=administrativeRole,ou=indexes,ads-partitionId=$RDN_VAL,ou=partitions,ads-directoryServiceId=default,ou=config
objectclass: ads-base
objectclass: ads-index
objectclass: ads-jdbmIndex
objectclass: top
ads-indexattributeid: administrativeRole
ads-indexhasreverse: FALSE
ads-enabled: TRUE
ads-indexcachesize: 100

dn: ads-indexAttributeId=apacheAlias,ou=indexes,ads-partitionId=$RDN_VAL,ou=partitions,ads-directoryServiceId=default,ou=config
objectclass: ads-base
objectclass: ads-index
objectclass: ads-jdbmIndex
objectclass: top
ads-indexattributeid: apacheAlias
ads-indexhasreverse: FALSE
ads-enabled: TRUE
ads-indexcachesize: 100

dn: ads-indexAttributeId=apacheOneAlias,ou=indexes,ads-partitionId=$RDN_VAL,ou=partitions,ads-directoryServiceId=default,ou=config
objectclass: ads-base
objectclass: ads-index
objectclass: ads-jdbmIndex
objectclass: top
ads-indexattributeid: apacheOneAlias
ads-indexhasreverse: FALSE
ads-enabled: TRUE
ads-indexcachesize: 100

dn: ads-indexAttributeId=apachePresence,ou=indexes,ads-partitionId=$RDN_VAL,ou=partitions,ads-directoryServiceId=default,ou=config
objectclass: ads-base
objectclass: ads-index
objectclass: ads-jdbmIndex
objectclass: top
ads-indexattributeid: apachePresence
ads-indexhasreverse: FALSE
ads-enabled: TRUE
ads-indexcachesize: 100

dn: ads-indexAttributeId=apacheRdn,ou=indexes,ads-partitionId=$RDN_VAL,ou=partitions,ads-directoryServiceId=default,ou=config
objectclass: ads-base
objectclass: ads-index
objectclass: ads-jdbmIndex
objectclass: top
ads-indexattributeid: apacheRdn
ads-indexhasreverse: TRUE
ads-enabled: TRUE
ads-indexcachesize: 100

dn: ads-indexAttributeId=apacheSubAlias,ou=indexes,ads-partitionId=$RDN_VAL,ou=partitions,ads-directoryServiceId=default,ou=config
objectclass: ads-base
objectclass: ads-index
objectclass: ads-jdbmIndex
objectclass: top
ads-indexattributeid: apacheSubAlias
ads-indexhasreverse: FALSE
ads-enabled: TRUE
ads-indexcachesize: 100

dn: ads-indexAttributeId=dc,ou=indexes,ads-partitionId=$RDN_VAL,ou=partitions,ads-directoryServiceId=default,ou=config
objectclass: ads-base
objectclass: ads-index
objectclass: ads-jdbmIndex
objectclass: top
ads-indexattributeid: dc
ads-indexhasreverse: FALSE
ads-enabled: TRUE
ads-indexcachesize: 100

dn: ads-indexAttributeId=entryCSN,ou=indexes,ads-partitionId=$RDN_VAL,ou=partitions,ads-directoryServiceId=default,ou=config
objectclass: ads-base
objectclass: ads-index
objectclass: ads-jdbmIndex
objectclass: top
ads-indexattributeid: entryCSN
ads-indexhasreverse: FALSE
ads-enabled: TRUE
ads-indexcachesize: 100

dn: ads-indexAttributeId=krb5PrincipalName,ou=indexes,ads-partitionId=$RDN_VAL,ou=partitions,ads-directoryServiceId=default,ou=config
objectclass: ads-base
objectclass: ads-index
objectclass: ads-jdbmIndex
objectclass: top
ads-indexattributeid: krb5PrincipalName
ads-indexhasreverse: FALSE
ads-enabled: TRUE
ads-indexcachesize: 100

dn: ads-indexAttributeId=objectClass,ou=indexes,ads-partitionId=$RDN_VAL,ou=partitions,ads-directoryServiceId=default,ou=config
objectclass: ads-base
objectclass: ads-index
objectclass: ads-jdbmIndex
objectclass: top
ads-indexattributeid: objectClass
ads-indexhasreverse: FALSE
ads-enabled: TRUE
ads-indexcachesize: 100

dn: ads-indexAttributeId=ou,ou=indexes,ads-partitionId=$RDN_VAL,ou=partitions,ads-directoryServiceId=default,ou=config
objectclass: ads-base
objectclass: ads-index
objectclass: ads-jdbmIndex
objectclass: top
ads-indexattributeid: ou
ads-indexhasreverse: FALSE
ads-enabled: TRUE
ads-indexcachesize: 100

dn: ads-indexAttributeId=uid,ou=indexes,ads-partitionId=$RDN_VAL,ou=partitions,ads-directoryServiceId=default,ou=config
objectclass: ads-base
objectclass: ads-index
objectclass: ads-jdbmIndex
objectclass: top
ads-indexattributeid: uid
ads-indexhasreverse: FALSE
ads-enabled: TRUE
ads-indexcachesize: 100
EOF











kill $!


timeout 30 sh -c "while  nc -z localhost 10389; do sleep 1; done"


eval "java $JAVA_OPTS $ADS_CONTROLS $ADS_EXTENDED_OPERATIONS $ADS_INTERMEDIATE_RESPONSES -Dlog4j.configuration=file:/usr/local/apacheds/conf/log4j.properties -Dapacheds.log.dir=$ADS_INSTANCE/log -classpath $CLASSPATH org.apache.directory.server.UberjarMain $ADS_INSTANCE 2>&1 &"

timeout 30 sh -c "while ! nc -z localhost 10389; do sleep 1; done"

echo "ApacheDS Restarted"

if [[ -z "${LDIF_FILE}" ]]; then
    echo "No initial LDIF file provided"
else
    ldapmodify -H ldap://127.0.0.1:10389 -D uid=admin,ou=system -w secret -f "${LDIF_FILE}" -a -c
fi





echo "Setting admin password"

ldapmodify -H ldap://127.0.0.1:10389 -D uid=admin,ou=system -w secret <<EOF
dn: uid=admin,ou=system
changeType: modify
replace: userPassword
userPassword: $APACHEDS_ROOT_PASSWORD
-
EOF


jnum=$(jobs -l | grep " $! " | sed 's/\[\(.*\)\].*/\1/')
echo "Backgroung job number: ${jnum}"

fg "${jnum}"
