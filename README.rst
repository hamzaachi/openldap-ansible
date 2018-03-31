Ansible Playbooks to install and manage OpenLDAP using Ansible 2.4 and higher. To use these Playbooks do the following:

	1. Define Your Environment:
        ===========================

 	To specify the settings and variables of your environment review the ``etc`` folder, which holds:
		* ``config.sh``: This file defines the variables of the target nodes like IP@, root pw, ssh key.....
		* ``*.pem`` file: This file is the SSH key used to SSHing into the target nodes.
		* ``globals.yml``: This file defines the settings of LDAP server like domaine_name, admin_password, replication mode....It also used to define the list  of LDAP users to be added or removed. The variables that must be reviewed/changed are:
			- ldap_ha_mode: To define which type of a high availabilty deployment when having more than 1 server.
			- ldap_admin_info: To define your domaine name, password..... 
			- ldap_groups_users_list: To define the list of groups/users to ab created/removed from openldap. To limit the login time for 1 or more groups set the variable "session_duration" following the same syntax in the example
			- openldap_ssl: To enable/disable ssl, when enabling it (True) you will also need to put your certificate files in the folder "certs" and define your Common Name in "openldap_ssl_cn" variable. If you would like to use a self-signed certificate refer to the annex.


	2. Launch the Deployment:
        =========================

	After setting up your environment you just need to run ``./deploy.sh``, as "root".

	3. Managing LDAP:
        ======================

		* To add new LDAP servers type (After defining them):
		  ldap-deployer --tags ldapservers

		* To add new LDAP clients type (After defining them):
		  ldap-deployer --tags ldapclients

		* To add or remove users/groups simply append them into the file ``globals.yml`` following the same syntax, then launch the command( "OnServer": on which server to create users ,"OnClient: on which client to remove the home directory of the removed users". both of these vars are optional) : 
                  ldap-deployer --tags ldap-gr-usr -e OnServer=SERVER_INVENTORY_HOSTNAME -e OnClient=CLIENT_INVENTORY_HOSTNAME
