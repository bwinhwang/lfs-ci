#!/bin/bash

# this is the static configuration, which is valid for all scripting
# stuff in here.
# it must be also valid for all slaves and the master

jenkinsMasterServerHostName=maxi.emea.nsn-net.net
jenkinsMasterServerPort=1280
jenkinsMasterServerUrl=http://${jenkinsMasterServerHostName}:${jenkinsMasterServerPort}/
jenkinsMasterServerPath=/var/fpwork/${USER}/lfs-jenkins/home/

artifactesShare=/build/home/${USER}/lfs/


