#!/bin/sh

CURRENT_IP=$1
CURRENT_ZK_ID=$2

#install dependencies
sudo add-apt-repository -y ppa:webupd8team/java
sudo apt-get update
echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
sudo apt-get install -y oracle-java8-installer

#Install binaries
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)
echo "deb http://repos.mesosphere.io/${DISTRO} ${CODENAME} main" | sudo tee /etc/apt/sources.list.d/mesosphere.list

sudo apt-get -y update

sudo apt-get install -y mesosphere

#In case of slaves comment mesosphere and uncomment mesos
#sudo apt-get install -y mesos

#Do on all the master/slave servers. Providing zoo keeper info
echo "zk://192.168.1.44:2181,192.168.1.45:2181,192.168.1.46:2181/mesos" | sudo tee /etc/mesos/zk

#Configure the Master Servers' Zookeeper Configuration
#First step is to set the id for the zk server
echo "${CURRENT_ZK_ID}" | sudo tee /etc/zookeeper/conf/myid
#Second step is to map the above id to the master hosts. 
#Two port configurations, first to communicate with leader,
#second to hold elections for leader
echo "server.1=192.168.1.44:2888:3888" | sudo tee -a /etc/zookeeper/conf/zoo.cfg
echo "server.2=192.168.1.45:2888:3888" | sudo tee -a /etc/zookeeper/conf/zoo.cfg
echo "server.3=192.168.1.46:2888:3888" | sudo tee -a /etc/zookeeper/conf/zoo.cfg


# Configure mesos on master servers
# Modify the Quorum to Reflect your Cluster Size. The quorum should be set so that 
# over 50 percent of the master members must be present to make decisions. 
# However, we also want to build in some fault tolerance so that if all of our 
# masters are not present, the cluster can still function.
# We have three masters, so the only setting that satisfies 
# both of these requirements is a quorum of two.
echo "2" | sudo tee /etc/mesos-master/quorum
#Specify hostname and ip address on each of the master servers
echo "${CURRENT_IP}" | sudo tee /etc/mesos-master/ip
sudo cp /etc/mesos-master/ip /etc/mesos-master/hostname

#Configure marathon on master servers
sudo mkdir -p /etc/marathon/conf
sudo cp /etc/mesos-master/hostname /etc/marathon/conf
#Provide the list of zookeeper masters that marathon requires for scheduling
sudo cp /etc/mesos/zk /etc/marathon/conf/master
#Enable marathon to store its information in zookeeper
sudo cp /etc/marathon/conf/master /etc/marathon/conf/zk
echo "zk://192.168.1.44:2181,192.168.1.45:2181,192.168.1.46:2181/marathon" | sudo tee /etc/marathon/conf/zk
#(Re)start services. Check http://ip:5050 for mesos status
sudo restart zookeeper
sudo start mesos-master
sudo start marathon 

#Configure slave servers
echo "${CURRENT_IP}" | sudo tee /etc/mesos-slave/ip
sudo cp /etc/mesos-slave/ip /etc/mesos-slave/hostname
sudo start mesos-slave
