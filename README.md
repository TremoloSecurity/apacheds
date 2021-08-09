# ApacheDS Container

This container is designed to have an LDAP server that can be quickly launched for testing.  **NOTE:** This container is NOT designed for production use.

## Environment Variables

| Variable | Description | Example |
| -------- | ----------- | ------- |
| APACHEDS_ROOT_PASSWORD | The password for `uid=admin,ou=system` | my_password_is_secure! |
| APACHEDS_TLS_KS_PWD | The password for the Java keystore used for ApacheDS' TLS listener | still_super_secure! |
| DN | The root suffix of the directory | dc=domain,dc=com |
| OBJECT_CLASS | The object class of the root suffix's object | domain |
| LDIF_FILE | The path (in the container) of the initial LDIF file, optional | /etc/apacheds/data.ldif |
| PRE_RUN_SCRIPT | *Optional* - A script can be run after initializing the directory before loading data |

## Volumes

| Path | Description |
| ---- | ----------- |
| /etc/apacheds | External apacheds configuration options for the container.  **MUST** contain a keystore called `apacheds.jks` that has an RSA keypair used for TLS in apacheds |
| /var/apacheds | *Optional* - Where all persistent data is stored.  If not included as a separate mount all data is ephemeral and will be lost when the container is destroyed |
