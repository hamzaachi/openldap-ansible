#!/usr/bin/python3

import pwd
import grp
import random

from ansible.module_utils.basic import AnsibleModule
from ansible.module_utils.pycompat24 import get_exception

try:
    import ldap
    import ldap.modlist
    import ldap.sasl

    HAS_LDAP = True
except ImportError:
    HAS_LDAP = False

def get_id():
        user_limit = {'min_uid': 20000,
                  'max_uid': 30000,
                  'min_gid': 10000,
                  'max_gid': 20000}
        result = {}

        all_uid = [x.pw_uid for x in pwd.getpwall()]
        all_gid = [x.gr_gid for x in grp.getgrall()]

        uid = random.randrange(user_limit['min_uid'], user_limit['max_uid'])
        gid = random.randrange(user_limit['min_gid'], user_limit['max_gid'])
        while (uid in all_uid):
           uid = random.randrange(user_limit['min_uid'], user_limit['max_uid'])

        while (gid in all_gid):
           gid = random.randrange(user_limit['min_gid'], user_limit['max_gid'])

        result['uid'] = uid
        result['gid'] = gid

        return result

class LdapEntry(object):
    def __init__(self, module):
        # Shortcuts
        self.module = module
        self.bind_dn = self.module.params['bind_dn']
        self.bind_pw = self.module.params['bind_pw']
        self.dn = self.module.params['dn']
        self.server_uri = self.module.params['server_uri']
        self.start_tls = self.module.params['start_tls']
        self.state = self.module.params['state']

        # Add the objectClass into the list of attributes
        self.module.params['attributes']['objectClass'] = (
            self.module.params['objectClass'])

        # Load attributes
        if self.state == 'present':
            self.attrs = self._load_attrs()

        # Establish connection
        self.connection = self._connect_to_ldap()


    def _load_attrs(self):
        """ Turn attribute's value to array. """
        attrs = {}

        for name, value in self.module.params['attributes'].items():
            if name not in attrs:
                attrs[name] = []

            if isinstance(value, list):
                attrs[name] = value
            else:
                attrs[name].append(str(value))
        
        return attrs


    def add(self):
        """ If self.dn does not exist, returns a callable that will add it. """
        def _add():
            self.connection.add_s(self.dn, modlist)

        if not self._is_entry_present():
            modlist = ldap.modlist.addModlist(self.attrs)
            action = _add
        else:
            action = None

        return action

    def delete(self):
        """ If self.dn exists, returns a callable that will delete it. """
        def _delete():
            self.connection.delete_s(self.dn)

        if self._is_entry_present():
            action = _delete
        else:
            action = None

        return action

    def _is_entry_present(self):
        try:
            self.connection.search_s(self.dn, ldap.SCOPE_BASE)
        except ldap.NO_SUCH_OBJECT:
            is_present = False
        else:
            is_present = True

        return is_present

    def _connect_to_ldap(self):
        connection = ldap.initialize(self.server_uri)

        if self.start_tls:
            try:
                connection.start_tls_s()
            except ldap.LDAPError:
                e = get_exception()
                self.module.fail_json(msg="Cannot start TLS.", details=str(e))

        try:
            if self.bind_dn is not None:
                connection.simple_bind_s(self.bind_dn, self.bind_pw)
            else:
                connection.sasl_interactive_bind_s('', ldap.sasl.external())
        except ldap.LDAPError:
            e = get_exception()
            self.module.fail_json(
                msg="Cannot bind to the server.", details=str(e))

        return connection


def main():
    module = AnsibleModule(
        argument_spec={
            'attributes': dict(default={}, type='dict'),
            'bind_dn': dict(),
            'bind_pw': dict(default='', no_log=True),
            'dn': dict(required=True),
            'objectClass': dict(type='raw'),
            'params': dict(type='dict'),
            'server_uri': dict(default='ldapi:///'),
            'start_tls': dict(default=False, type='bool'),
            'state': dict(default='present', choices=['present', 'absent']),
        },
        supports_check_mode=True,
    )

    if not HAS_LDAP:
        module.fail_json(
            msg="Missing requried 'ldap' module (pip install python-ldap).")

    state = module.params['state']

    # Chek if objectClass is present when needed
    if state == 'present' and module.params['objectClass'] is None:
        module.fail_json(msg="At least one objectClass must be provided.")

    # Check if objectClass is of the correct type
    if (
            module.params['objectClass'] is not None and not (
                isinstance(module.params['objectClass'], basestring) or
                isinstance(module.params['objectClass'], list))):
        module.fail_json(msg="objectClass must be either a string or a list.")

    ids = {}
    ids = get_id()

    # Update module parameters with user's parameters if defined
    if 'params' in module.params and isinstance(module.params['params'], dict):
        for key, val in module.params['params'].items():
            if key in module.argument_spec:
                module.params[key] = val
            else:
                module.params['attributes'][key] = val
        # Remove the params
        module.params.pop('params', None)

    # Instantiate the LdapEntry object
    ldap = LdapEntry(module)
    
    # Get the action function
    if state == 'present':
        action = ldap.add()
    elif state == 'absent':
        action = ldap.delete()

    # Perform the action
    if action is not None and not module.check_mode:
        try:
            action()
        except Exception:
            e = get_exception()
            module.fail_json(msg="Entry action failed.", details=str(e))

    module.exit_json(changed=(action is not None))


if __name__ == '__main__':
    main()
