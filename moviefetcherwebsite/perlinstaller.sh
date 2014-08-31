#!/bin/bash
#Perl Module installer By Unnikrishnan
#unnikrishnan.a@directi.com
declare -a GROUPS_ARRAY;
declare VERSION="1.0"
declare CPUSER=$1;
declare PERL_MOD=$2;
declare COMPILER_GROUP="compiler";
declare BASH_BIN="/bin/bash";
declare USERMOD_BIN="/usr/sbin/usermod";
declare MY_NAME="$0";
function usage 
{
echo "Perl Module installer version ${VERSION}";
echo "Usage $MY_NAME CPANEL_USER_NAME PERL_MODULE_NAME";
}
if [ -z $CPUSER ]
then
        echo "Invalid Cpanel user name";
        usage;
        exit 192;
fi
cat /etc/domainusers | cut -d : -f1 | grep -qw $CPUSER
if [ $? -ne 0 ]
then
        echo "Not a Cpanel user name";
        usage;
        exit 192;
fi
echo "${PERL_MOD}" | egrep -qo "[A-Za-z0-9]+::[A-Za-z0-9]+";
if [ $? -ne 0 ] 
then
        echo "Input doesn't look like a perl module name";
        usage;
        exit 192;
fi
CURRENT_USER_SHELL=$(grep "${CPUSER}:" /etc/passwd | cut -d : -f7);
file /home/${CPUSER}/perl5 | grep -qo "symbolic link to.*"
if [ $? -ne 0 ] 
then
        mv /home/${CPUSER}/perl5 /home/${CPUSER}/perl5.old
        cd /home/${CPUSER}
        ln -s perl/usr/local perl5
        chown -h ${CPUSER}: /home/${CPUSER}/perl5
        cd -
fi
${USERMOD_BIN} -a -G $COMPILER_GROUP $CPUSER;
${USERMOD_BIN} -s $BASH_BIN $CPUSER;
su - $CPUSER -c "/scripts/perlinstaller ${PERL_MOD}"
${USERMOD_BIN} -G $CPUSER $CPUSER;
${USERMOD_BIN} -s $CURRENT_USER_SHELL $CPUSER;
exit 0
