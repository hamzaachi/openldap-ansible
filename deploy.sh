#!/usr/bin/env bash

## Shell Options -----------------------------------------------
set -e -u -x
set -o pipefail

source etc/config.sh

###################################### Bootstrap Ansible ##################################
function install_ansible(){
        yum -y update
	yum -y install python2 curl autoconf gcc-c++ \
          python2-devel gcc libffi-devel nc openssl-devel \
          python-pyasn1 pyOpenSSL python-ndg_httpsclient \
          python-netaddr python-prettytable python-crypto PyYAML \
          python-virtualenv python-pip

	pip install --index-url=http://pypi.python.org/simple/ --trusted-host pypi.python.org ansible
}
###################################### Allow root SSHing using Key #########################
function allow_root_sshing(){
	test -f /root/.ssh/id_rsa.pub || ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ''
	ssh_key=$(cat /root/.ssh/id_rsa.pub)

	for var in ${NODES_LIST[@]} ; do
	    ssh -i $SSH_Key -o StrictHostKeyChecking=no centos@$(echo $var|cut -f2 -d':') "
		sudo sed -i  's/^\(#\)\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
		sudo sed -i  's/^PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
		sudo systemctl restart sshd
                echo "root:$ROOT_PASSWORD"|sudo chpasswd
		echo "$ssh_key"|sudo tee -a /root/.ssh/authorized_keys
	   "
	done
}
################################## Nodes static name resolution ############################
function nodes_static_name_resol(){
	for record in  ${NODES_LIST[@]}; do
	     domain_name="$(grep -i 'domain_name:' etc/globals.yml |cut -d':' -f2|xargs)"
	     cert_cn="$(grep -i 'openldap_ssl_cn:' etc/globals.yml |cut -d':' -f2|xargs)"
	     grep -q "$(echo $record|cut -f2 -d':')" /etc/hosts || echo "$(echo $record|cut -f2 -d':') $(echo $record|cut -f1 -d':').$domain_name $(echo $record|cut -f1 -d':')" >> /etc/hosts
		for var in ${NODES_LIST[@]} ; do
		 ssh -o StrictHostKeyChecking=no root@$(echo $record|cut -f2 -d':') "
		 hostnamectl set-hostname "$(echo $record|cut -f1 -d':')"
	         grep -q "$cert_cn" /etc/hosts || echo "$(echo $record|cut -f2 -d':') $cert_cn" >> /etc/hosts
		 grep -q "$(echo $var|cut -f2 -d':')" /etc/hosts || echo "$(echo $var|cut -f2 -d':') $(echo $var|cut -f1 -d':').$domain_name $(echo $var|cut -f1 -d':')" >> /etc/hosts	
		 echo "${LDAP_SERVERS_LIST[@]}" > /root/openldap_server_hosts
			"
   		done
   	done	
}

################################## Generate Ansible Inventory ################################
function generate_inventory(){
	echo "" > inventory/prod-inventory
	echo '[ldapserver]' >> inventory/prod-inventory
	for node in  ${LDAP_SERVERS_LIST[@]}; do
		echo "$(echo $node|cut -f1 -d':')" >> inventory/prod-inventory
	done
	echo "" >> inventory/prod-inventory
	echo '[ldapclient]' >> inventory/prod-inventory
	for node in  ${LDAP_CLIENTS_LIST[@]}; do
		echo "$(echo $node|cut -f1 -d':')" >> inventory/prod-inventory
	done
}

################################# Install LDAP Python library #################################
function install_ldap_py_lib(){
	for node in  ${LDAP_SERVERS_LIST[@]}; do
	     ssh -o StrictHostKeyChecking=no root@$(echo $node|cut -f2 -d':') "
		sudo yum -y install openldap-devel python2 python2-devel python-pip gcc
		pip install --trusted-host pypi.python.org python-ldap
	    "
	done
}
################################# Run Ansible Playbook ########################################
function launch_ldap_playbook(){
	export ANSIBLE_HOST_KEY_CHECKING="${ANSIBLE_HOST_KEY_CHECKING:-False}"
        export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"
        cat > /usr/local/bin/ldap-deployer <<EOF
                export ANSIBLE_HOST_KEY_CHECKING="\${ANSIBLE_HOST_KEY_CHECKING:-False}"
                RUN_CMD=\$(basename \${0})
                VAR1="-i inventory/prod-inventory -e @etc/globals.yml site.yml"
                if [ "\${RUN_CMD}" == "ldap-deployer" ] || [ "\${RUN_CMD}" == "ansible-playbook" ]; then
                      ansible-playbook "\${@}" \${VAR1}
                else
                     \${RUN_CMD} "\${@}"
                fi
EOF
        chmod +x /usr/local/bin/ldap-deployer
	echo export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}" >> /root/.bashrc
        ldap-deployer

}
###############################################################################################

install_ansible
allow_root_sshing
nodes_static_name_resol
generate_inventory
install_ldap_py_lib
launch_ldap_playbook

