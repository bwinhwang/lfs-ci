#!/bin/bash



# this is the static configuration, which is valid for all scripting
# stuff in here.
# it must be also valid for all slaves and the master

# ....
declare -A sitesBuildShareMap=(  ["Ulm"]="ulling01:/build/home/${USER}/lfs/"                  \
                                ["Oulu"]="ouling04.emea.nsn-net.net:/build/home/${USER}/lfs/" \
)

# ....
declare -A platformMap=(         ["fct"]="fsm3_octeon2" \
                           ["qemu_i386"]="qemu"         \
                         ["qemu_x86_64"]="qemu_64"      \
                                ["fspc"]="fspc"         \
                                ["fcmd"]="fcmd"         \
                                 ["arm"]="fsm35_k2"     \
                           ["keystone2"]="fsm35_k2"     \
                                 ["axm"]="fsm35_axm"    \
)

# ....
declare -A archMap=(         ["fct"]="mips64-octeon2-linux-gnu"      \
                       ["qemu_i386"]="i686-pc-linux-gnu"             \
                     ["qemu_x86_64"]="x86_64-pc-linux-gnu"           \
                            ["fspc"]="powerpc-e500-linux-gnu"        \
                            ["fcmd"]="powerpc-e500-linux-gnu"        \
                             ["axm"]="arm-cortexa15-linux-gnueabihf" \
                       ["keystone2"]="arm-cortexa15-linux-gnueabihf" \
)

# maps the location name to the branch name in the svn delivery repos
declare -A locationToSubversionMap=( ["pronb-developer"]="PS_LFS_OS_MAINBRANCH" \
                                     ["FSM_R4_DEV"]="PS_LFS_OS_FSM_R$" \
                                   )

declare -a branchToLocationMap=( ["trunk"]="pronb-developer" \
                                 ["fsmr4"]="FSM_R4_DEV" \
                               )

# define the mapping from branch to label/tag name
labelPrefix=$(getConfig labelPrefix)
declare -A branchToTagRegexMap=( ["pronb-developer"]="${labelPrefix}_$(date +%Y)_$(date +%m)_([0-9][0-9])" \
                                      ["FSM_R4_DEV"]="FSMR4_${labelPrefix}_1404_$(date +%m)_([0-9][0-9])" \
                                          ["FB1404"]="FB_${labelPrefix}_1404_04_([0-9][0-9])" \
                                  ["KERNEL_3.x_DEV"]="KERNEL3x_${labelPrefix}_$(date +%Y)_$(date +%m)_([0-9][0-9])" \
                               )

