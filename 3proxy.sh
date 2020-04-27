#!/bin/bash
# Created by MegaLoadOn.

# Defining function installing 3proxy on CentOS
install_centos() {
        if test  -e /etc/yum.repos.d/epel.repo; then
                echo "Epel is already installed";
        else
                echo "Epel will be installed...";
                rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm &> /dev/null
                if [ `echo $?` -eq 0 ]; then
                        echo "Epel installed";
                else
                        echo "Errors occurred while installing Epel"
                        exit
                fi
        fi

        pwgen &> /dev/null
        if [ $? -eq 0 ]; then
                echo "pwgen is already installed"
        else
                echo "pwgen will be installed...";
                yum -y install pwgen &> /dev/null
                if [ `echo $?` -eq 0 ]; then
                        echo "pwgen installed";
                else
                        echo "Errors occurred while installing pwgen"
                        exit
                fi
        fi

        curl -s ifconfig.co &> /dev/null
        if [ $? -eq 0 ]; then
                echo "curl is already installed"
        else
                echo "curl will be installed...";
                yum -y install curl &> /dev/null
                if [ `echo $?` -eq 0 ]; then
                        echo "curl installed";
                else
                        echo "Errors occurred while installing curl"
                        exit
                fi
        fi

        echo "Installation 3proxy..."
        yum -y install 3proxy &> /dev/null
                if [ `echo $?` -eq 0 ]; then
                        echo "3proxy successfully installed" &> /dev/null
                else
                        echo "Errors occurred while installing 3proxy"
                        exit
                fi
}

# Defining function configuration 3proxy
configuration() {
        cp /etc/3proxy.cfg /etc/3proxy.cfg.$RANDOM
        cat > /etc/3proxy.cfg <<EOF
daemon
log /dev/null
allow * * * *
auth strong
nserver 8.8.8.8
nserver 77.88.8.8
nscache 65536
proxy -p1234 -n -a -i`curl -s ifconfig.co`  -e`curl -s ifconfig.co`
socks -p1235 -i`curl -s ifconfig.co` -e`curl -s ifconfig.co`
users user$RANDOM:CL:`pwgen -s 14 1`
EOF
}

# Defining function start service
start_service() {
        service 3proxy restart &> /dev/null
        systemctl enable 3proxy &> /dev/null
}

# Defining function check 3proxy
check_install() {
        rpm -qa | grep 3proxy &> /dev/null
        if [ $? -eq 0 ]; then
                INSTALL=1
        else
                INSTALL=0
        fi
}

# Definition function message
message() {
                echo ""
                echo "HTTP proxy - `curl -s ifconfig.co`:1234"
        echo "SOCKS proxy - `curl -s ifconfig.co`:1235"
        echo ""
        echo "`cat /etc/3proxy.cfg | grep users | awk '{print $2}' | sed 's/:CL:/:/'`"
        echo "============================="
        echo "We can check connections via https://proxy6.net/en/checker"
        echo "============================="
}

# Definition function iptables add
iptables_add() {
        iptables -I INPUT -p tcp --dport 1234 -j ACCEPT &> /dev/null
        iptables -I INPUT -p tcp --dport 1235 -j ACCEPT &> /dev/null
        iptables-save > /etc/sysconfig/iptables
}
# Definition function iptables remove
iptabless_remove() {
        iptables -D INPUT -p tcp --dport 1234 -j ACCEPT &> /dev/null
        iptables -D INPUT -p tcp --dport 1235 -j ACCEPT &> /dev/null
        iptables-save > /etc/sysconfig/iptables
}
echo ""
echo "What you want to do? select number"
echo "1. Install 3proxy."
echo "2. Remove 3proxy."
echo "3. Add users."
echo "4. Remove users."

read REPLY
echo
if [[ $REPLY =~ ^[1]$ ]]; then
        INSTALL_3PROXY=y
fi
if [[ $REPLY =~ ^[2]$ ]]; then
        DELETE_3PROXY=y
fi
if [[ $REPLY =~ ^[3]$ ]]; then
        ADD_USERS=y
fi
if [[ $REPLY =~ ^[4]$ ]]; then
        REMOVE_USERS=y
fi

if [[ "$INSTALL_3PROXY" = [yY] ]]; then
        check_install
        if [ $INSTALL -eq 1 ]; then
                echo -e "\e[1;31m3proxy already installed. Installation stoped\e[0m"
                exit
        fi
        if [ $INSTALL -eq 0 ]; then
                install_centos
                configuration
                                iptables_add
                start_service
                echo ""
                echo "=============================="
                echo -e "\e[1;32m3proxy successfully installed!\e[0m"
                message
        fi
fi

if [[ "$DELETE_3PROXY" = [yY] ]]; then
        check_install
        if [ $INSTALL -eq 1 ]; then
                echo "3proxy installed, and will be removed..."
                yum remove -y 3proxy &> /dev/null
                                iptabless_remove
                if [ $? -eq 0 ]; then
                        echo -e "\e[1;32m3proxy successfylly removed\e[0m"
                else
                        echo -e "\e[1;31m3proxy not removed from server. Check this problem.\e[0m"
                fi
        fi
        if [ $INSTALL -eq 0 ]; then
                echo -e "\e[1;31m3proxy not installed on this server\e[0m"
        fi
fi

if [[ "$ADD_USERS" = [yY] ]]; then
        check_install
        if [ $INSTALL -eq 1 ]; then
                echo ""
                echo "How many users do you want to add?"
                read REPLY
                while [ $REPLY -gt 0 ]
                do
                echo "users user$RANDOM:CL:`pwgen -s 14 1`" >> /etc/3proxy.cfg
                REPLY=$[ $REPLY - 1 ]
                done
                start_service
                echo ""
                echo "============================="
                echo -e "\e[1;32mUsers successfully added!\e[0m"
                message
        else
                echo -e "\e[1;31m3proxy not installed on this server\e[0m"
        fi
fi

if [[ "$REMOVE_USERS" = [yY] ]]; then
        check_install
        if [ $INSTALL -eq 1 ]; then
                echo ""
                echo "1. Remove all users?"
                echo "2. Reissue all users"
                echo "3. Remove a specific user"

                read REPLY
                if [[ $REPLY =~ ^[1]$ ]]; then
                        REMOVE_ALL=y
                fi
                if [[ $REPLY =~ ^[2]$ ]]; then
                        REISSUE_ALL=y
                fi
                if [[ $REPLY =~ ^[3]$ ]]; then
                        REMOVE_SPEC=y
                fi

                if [[ "$REMOVE_ALL" = [yY] ]]; then
                        sed -i '/users/d' /etc/3proxy.cfg &> /dev/null
                        start_service
                        echo -e "\e[1;32mAll users successfully removed!\e[0m"
                fi
                if [[ "$REISSUE_ALL" = [yY] ]]; then
                        COUNT=`cat /etc/3proxy.cfg | grep users | wc -l`
                        sed -i '/users/d' /etc/3proxy.cfg &> /dev/null
                        while [ $COUNT -gt 0 ]
                        do
                        echo "users user$RANDOM:CL:`pwgen -s 14 1`" >> /etc/3proxy.cfg
                        COUNT=$[ $COUNT - 1 ]
                        done
                        start_service
                        echo ""
                        echo "============================="
                        echo -e "\e[1;32mUsers successfully reissued!\e[0m"
                        message
                fi
                if [[ "$REMOVE_SPEC" = [yY] ]]; then
                        echo ""
                        echo "Please specify username (like user1234)"
                        read REPLY
                        sed -i '/'$REPLY'/d' /etc/3proxy.cfg &> /dev/null
                        start_service
                        echo -e "\e[1;32mUser $REPLY successfully removed!\e[0m"
                fi
        fi
fi
