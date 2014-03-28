#!/bin/bash

# this is the static configuration, which is valid for all scripting
# stuff in here.
# it must be also valid for all slaves and the master

# hostname (fqdn) of the jenkins master server
jenkinsMasterServerHostName=maxi.emea.nsn-net.net

# http port of the jenkins master webinterface
jenkinsMasterServerHttpPort=1280

# https port of the jenkins master webinterface
jenkinsMasterServerHttpsPort=12443

# the http (unsecure) url of the jenkins master webinterface
jenkinsMasterServerHttpUrl=http://${jenkinsMasterServerHostName}:${jenkinsMasterServerPort}/

# the https (secure) url of the jenkins master webinterface
jenkinsMasterServerHttpsUrl=http://${jenkinsMasterServerHostName}:${jenkinsMasterServerPort}/

# home directory of the jenkins master server installation
# (only valid on the master server)
jenkinsMasterServerPath=/var/fpwork/${USER}/lfs-jenkins/home/

# path to the share, where the build artifacts are located
# (location for ulm, not valid for other sites)
artifactesShare=/build/home/${USER}/lfs/

svnMasterServerHostName=svne1.access.nokiasiemensnetworks.com
svnSlaveServerUlmHostName=ulscmi.inside.nsn.com
