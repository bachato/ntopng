LDAP Configuration
==================

This readme shows how to configure slapd on Ubuntu to setup a sample LDAP
server to be used for authenticating ntopng users (posix). 

```
sudo apt update
sudo apt install slapd ldap-utils -y

sudo dpkg-reconfigure slapd
```

Recommended answers to the propt:

 - Omit OpenLDAP server configuration? No
 - DNS domain name: example.com
 - Organization name: Example Corp
 - Admin password: password
 - Database backend: mdb
 - Remove database when slapd is purged? No
 - Move old database? Yes

Create 01-add-ous.ldif:

```
dn: ou=users,dc=example,dc=com
objectClass: organizationalUnit
ou: users
dn: ou=groups,dc=example,dc=com
objectClass: organizationalUnit
ou: groups
```
Add the OUs:

```
ldapadd -x -D "cn=admin,dc=example,dc=com" -W -f 01-add-ous.ldif
```

Create 02-add-user-alfredo.ldif:

```
dn: uid=alfredo,ou=users,dc=example,dc=com
objectClass: inetOrgPerson
cn: Alfredo
sn: Example
uid: alfredo
mail: alfredo@example.com
userPassword: secret123
```

Add the user configuration:

```
ldapadd -x -D "cn=admin,dc=example,dc=com" -W -f 02-add-user-alfredo.ldif
```

Create 03-add-group-developers.ldif:

```
dn: cn=developers,ou=groups,dc=example,dc=com
objectClass: groupOfNames
cn: developers
member: uid=alfredo,ou=users,dc=example,dc=com
```

Add the group configuration:

```
ldapadd -x -D "cn=admin,dc=example,dc=com" -W -f 03-add-group-developers.ldif
```

Verify the LDAP users and groups:

```
ldapsearch -x -H ldap://192.168.2.97:389 -b 'dc=example,dc=com' -s sub "(objectclass=*)"

# example.com
dn: dc=example,dc=com
objectClass: top
objectClass: dcObject
objectClass: organization
o: Example Corp
dc: example

# users, example.com
dn: ou=users,dc=example,dc=com
objectClass: organizationalUnit
ou: users

# groups, example.com
dn: ou=groups,dc=example,dc=com
objectClass: organizationalUnit
ou: groups

# alfredo, users, example.com
dn: uid=alfredo,ou=users,dc=example,dc=com
objectClass: inetOrgPerson
cn: Alfredo
sn: Example
uid: alfredo
mail: alfredo@example.com

# developers, groups, example.com
dn: cn=developers,ou=groups,dc=example,dc=com
objectClass: groupOfNames
cn: developers
member: uid=alfredo,ou=users,dc=example,dc=com
```

Configure ntopng:

 - Account Type: Posix
 - Anonymous Binding: enabled
 - Search Path: dc=example,dc=com
 - User Group: developers

Log into ntopng with:

 - Login: alfredo
 - Password: secret123
