#!/usr/bin/env bash

####### hostname:IP #######
#ldap-master03:192.20.0.14
export LDAP_SERVERS_LIST=(ldap-master01:192.20.0.5 ldap-master02:192.20.0.15 ldap-master03:192.20.0.14)
export LDAP_CLIENTS_LIST=(ldap-client:192.20.0.16)
export NODES_LIST=("${LDAP_SERVERS_LIST[@]}" "${LDAP_CLIENTS_LIST[@]}")
####### Method to authenticate against the system [sshkey]
export AUTH_METHOD="sshkey"
export SSH_Key="etc/ldap.pem"
####### Set root password in case the sshkey gets lost
export ROOT_PASSWORD="azerty"
