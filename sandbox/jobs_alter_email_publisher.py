#!/usr/bin/env python
# -*- coding: utf-8 -*-

#
# Alter the email publisher of all Jenkins jobs.
# Set recipient address to lfs-ci-dev@mlist.emea.nsn-intra.net.
# Set "sendToIndividuals" and "dontNotifyEveryUnstableBuild" to "false".
# The config.xml file of the effected Jenkins jobs is backedup to config.xml.bak.
#

import sys
import os
import shutil
import xml.etree.ElementTree as ET

USER = os.getenv('USER')
jobs_dir = "/var/fpwork/%s/lfs-jenkins/home/jobs" % USER

def process_args():
    global jobs_dir
    if len(sys.argv) == 2:
        if sys.argv[1] in ("-h", "--help"):
            print ""
            print "\tAlter the email publisher of all Jenkins jobs."
            print "\tDefault path to Jenkins jobs is /var/fpwork/${USER}/lfs-jenkins/home/jobs"
            print ""
            print "\tUsage:"
            print "\t    %s <path-to-jobs-dir>" % sys.argv[0]
            print ""
            print "\tExamples:"
            print "\t    %s" % sys.argv[0]
            print "\t    %s /home/myusername/jenkins/jobs" % sys.argv[0]
            print ""
            sys.exit(0)
        else:
            jobs_dir=sys.argv[1]

    if not os.path.isdir(jobs_dir):
        print "ERROR: %s does not exist." % jobs_dir
        sys.exit(1)

def process_jobs():
    done = False
    for job_name in os.listdir(jobs_dir):
        job_config = "%s/%s/config.xml" % (jobs_dir, job_name)
        if not os.path.isfile(job_config):
            continue
        print "Processing job config %s" % job_config
        tree = ET.parse(job_config)
        root = tree.getroot()
        for child in root.getchildren():
            if child.tag == "publishers":
                for publisher in child.getchildren():
                    if publisher.tag == "hudson.tasks.Mailer":
                        for leaf in publisher.getchildren():
                            if leaf.tag == "recipients":
                                done = True
                                leaf.text = "lfs-ci-dev@mlist.emea.nsn-intra.net"
                            if leaf.tag == "dontNotifyEveryUnstableBuild":
                                done = True
                                leaf.text = "false"
                            if leaf.tag == "sendToIndividuals":
                                done = True
                                leaf.text = "false"
        if done:
            # Only write xml file if the job-config was altered.
            job_config_bak = "%s.bak" % (job_config)
            shutil.copyfile(job_config, job_config_bak)
            tree.write(job_config, "UTF-8")

if __name__ == "__main__":
    process_args()
    process_jobs()
