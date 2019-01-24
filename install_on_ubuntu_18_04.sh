#!/bin/bash

# USAGE:
# - Install an Ubuntu 18.04 VM
# - Unpack the Hyst repository somewhere
# - Open a terminal in the directory containing this file
# - Run this script as root (or with sudo: sudo ./install_ubuntu_18_04.sh)
# -> Hyst can be found in the current directory (or as a symlink in /opt/hyst), and the tools at /opt/tools.

# exit if anything fails
set -e
set -o pipefail
shopt -s failglob

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# where should hyst and the tools be installed? Default: /opt
HYST_PREFIX=${HYST_PREFIX:-/opt}

echo "This script will install hyst at ${HYST_PREFIX}/hyst, and install its dependencies at ${HYST_PREFIX}/tools."
if [ -z "${RUNNING_IN_DOCKER}" ]; then
    echo "DO NOT RUN THIS DIRECTLY ON YOUR NORMAL COMPUTER, ONLY IN AN EXTRA VIRTUAL MACHINE OR CONTAINER,"
    echo "because some of the script's actions will permanently change configuration, uninstall packages et cetera."
fi
if tty -s; then
    # ask for confirmation if interactive session
    echo "Press Ctrl-C to exit, Enter to continue."
    read
fi

mkdir -p ${HYST_PREFIX}

# For better caching in the Dockerfile, this script can be run in two phases:
# --only-dependencies (does not require the hyst folder, only requires this shell script)
# --no-dependencies (requires the hyst folder)

if ! [ "x$1" == "x--no-dependencies" ]; then
    echo "Removing old installation"
    rm -rf ${HYST_PREFIX}/hyst ${HYST_PREFIX}/tools
    echo > ${HYST_PREFIX}/environment
    
    
    echo "Installing dependencies"
    
    # apt should not ask any questions:
    export DEBIAN_FRONTEND=noninteractive

    ##################
    # Install Hyst dependencies
    ##################
    apt-get update && apt-get -qy install ant python2.7 python-scipy python-matplotlib git libglpk-dev build-essential python-cvxopt python-sympy gimp

    # Bug in sympy < 1.2: "TypeError: argument is not an mpz" (probably https://github.com/sympy/sympy/issues/7457, was fixed Nov 2017)
    # -> we use sympy 1.2
    apt-get -qy install python-pip python-sympy- && pip install sympy==1.2

    ##################
    # Install Hylaa
    ##################
    # branch or tag of hylaa to use
    HYLAA_VERSION=v1.1
    MY_PYTHONPATH=${MY_PYTHONPATH}:${HYST_PREFIX}/tools/hylaa:${HYST_PREFIX}/tools/hylaa/hylaa/
    mkdir -p ${HYST_PREFIX}/tools/hylaa && git clone https://github.com/stanleybak/hylaa ${HYST_PREFIX}/tools/hylaa --branch $HYLAA_VERSION  --depth 1
    cd ${HYST_PREFIX}/tools/hylaa/hylaa/glpk_interface && make
    ls -l ${HYST_PREFIX}/tools/hylaa
    echo $HOME
    # BUG (TODO report???)  The hylaa unittests cannot be run noninteractive because matplotlib fails if no X server is running. Workaround by changing the default backend from TkAgg (interactive) to Agg (noninteractive).
    sed -i 's/^backend *: *TkAgg$/backend: Agg/i' /etc/matplotlibrc
    cd ${HYST_PREFIX}/tools/hylaa/tests && PYTHONPATH=$PYTHONPATH:${MY_PYTHONPATH} python -m unittest discover

    # TODO: performance warning because numpy is not compiled with OpenBLAS

    ##################
    # Install flowstar
    ##################
    # Configuration:
    # FLOWSTAR_VERSION: version of flowstar,
    # FLOWSTAR_FILE_SHA512SUM: sha512sum hash of the .tar.gz download archive of flowstar.
    # to disable the hash check, change the line to:
    # FLOWSTAR_FILE_SHA512SUM=' '

    FLOWSTAR_VERSION=2.0.0
    FLOWSTAR_FILE_SHA512SUM='641179b88a2eb965266f3ec0d8adca6726d5b2a172a5686ae59c1b8fc6bb9dc662ef67d95eb8c158175fd1f411e5db7355a83e5dd12fd4d8fb196e27d4988f79'

    # We can't use 2.1.0 yet due to this bug: https://github.com/verivital/hyst/issues/44
    # FLOWSTAR_VERSION=2.1.0
    # FLOWSTAR_FILE_SHA512SUM='d5243f3bbcdd6bffcaf2f1ae8559278f62567877021981e4443cd90fbf2918e0acb317a2d27724bc81d3a0e38ad7f7d48c59d680be1dd5345e80d2234dd3fe3b'


    mkdir -p ${HYST_PREFIX}/tools/flowstar
    cd ${HYST_PREFIX}/tools/flowstar
    apt-get install -qy curl flex bison libgmp-dev libmpfr-dev libgsl-dev gnuplot 
    curl -fL https://www.cs.colorado.edu/~xich8622/src/flowstar-${FLOWSTAR_VERSION}.tar.gz > flowstar.tar.gz
    # print and check hash
    sha512sum flowstar.tar.gz | tee flowstar.sha512sum && grep -q "${FLOWSTAR_FILE_SHA512SUM}" flowstar.sha512sum
    tar xzf flowstar.tar.gz
    cd ${HYST_PREFIX}/tools/flowstar/flowstar-${FLOWSTAR_VERSION}/
    make
    MY_PATH="${MY_PATH}:${HYST_PREFIX}/tools/flowstar/flowstar-${FLOWSTAR_VERSION}/"


    ##################
    # Install SpaceEx
    ##################
    # SHA512 hash of the downloaded file (set hash to ' ' to disable hash checking)
    SPACEEX_FILE_SHA512SUM='30eab345ca8cbc5722df38e7ed6009c728e197184eca7c49558eeb73055ef340177315aa72f0809acca1dbde4a969779729ea1cb2529ed0b6a3e221ffd0c82b3'
    mkdir -p ${HYST_PREFIX}/tools/spaceex
    cd ${HYST_PREFIX}/tools/spaceex
    # We use the SpaceEx 64bit executable file.
    # TODO: SpaceEx doesn't provide a publicly available download URL, you need to fill out the registration form first :-( -> As a workaround, we use the following Github link.
    curl -fL https://github.com/MaxGaukler/hyst/raw/1b50946bc01051626ff0fc3c90f5d5a6e625a89a/spaceex_exe-0.9.8f.tar.gz > spaceex.tar.gz
    # print and check hash
    sha512sum spaceex.tar.gz | tee spaceex.sha512sum && grep -q "${SPACEEX_FILE_SHA512SUM}" spaceex.sha512sum
    tar xzf ./spaceex.tar.gz
    apt-get install -qy plotutils
    MY_PATH="${MY_PATH}:${HYST_PREFIX}/tools/spaceex/spaceex_exe/"
    cd "${HYST_PREFIX}/tools/spaceex/spaceex_exe/"
    ./spaceex --version

    ##################
    # Install dReach (included in dReal3)
    ##################
    # version and SHA512 hash (set hash to ' ' to disable hash checking)
    # see https://github.com/dreal/dreal3/releases for available versions
    # It seems that dReal4 does no longer include dReach, so we're stuck wich dReal3.
    DREAL_VERSION=3.16.06.02
    DREAL_FILE_SHA512SUM='199c02d90d3d448dff6b9d2d1b99257d4ae4efcf22fa4d66d30eeb0cb6215b06ff8824c4256bf1b89ebaf01b872655ab3105d298c3db0a28d6c0c71a24fa0712'

    mkdir -p "${HYST_PREFIX}/tools/dreach"
    cd "${HYST_PREFIX}/tools/dreach"
    curl -fL https://github.com/dreal/dreal3/releases/download/v3.16.06.02/dReal-3.16.06.02-linux.tar.gz > dreach.tar.gz
    # print and check hash
    sha512sum dreach.tar.gz | tee dreach.sha512sum && grep -q "${DREAL_FILE_SHA512SUM}" dreach.sha512sum
    tar xzf dreach.tar.gz
    cd "${HYST_PREFIX}/tools/dreach/dReal-${DREAL_VERSION}-linux/"
    ls -l
    MY_PATH="${MY_PATH}:${HYST_PREFIX}/tools/dreach/dReal-${DREAL_VERSION}-linux/bin"
    ./bin/dReach -h

    ##################
    # Install HyCreate
    ##################
    # version and SHA512 hash (set hash to ' ' to disable hash checking)
    # see http://stanleybak.com/projects/hycreate/hycreate.html for available versions
    HYCREATE_VERSION=2.81
    HYCREATE_FILE_SHA512SUM='e801d1fb01e112803f83a37d5339c802a638c2cd253d1a5b3794477f69d123ee243206561a51d99502d039f5cc5df859b14dc2c9fd236f58b67b83033d220ca9'

    apt-get -qy install unzip openjdk-8-jdk-headless
    mkdir "${HYST_PREFIX}/tools/hycreate"
    cd "${HYST_PREFIX}/tools/hycreate"

    curl -fL http://stanleybak.com/projects/hycreate/HyCreate2.81.zip > hycreate.zip
    # print and check hash
    sha512sum hycreate.zip | tee hycreate.sha512sum && grep -q "${HYCREATE_FILE_SHA512SUM}" hycreate.sha512sum
    unzip hycreate.zip
    cd ${HYST_PREFIX}/tools/hycreate/HyCreate${HYCREATE_VERSION}/
    ls -l
    MY_PATH="${MY_PATH}:${HYST_PREFIX}/tools/hycreate/HyCreate${HYCREATE_VERSION}/"
    # BUG (reported at https://github.com/verivital/hyst/issues/47 ): hypy expects HyCreate2.8.jar, not HyCreate 2.81.jar.
    test -f HyCreate2.8.jar || ln -s HyCreate*.jar HyCreate2.8.jar
    # create startup file so that you can type "hycreate" on the terminal
    cat <<- EOF > hycreate
    #!/bin/bash
    exec java -jar ${HYST_PREFIX}/tools/hycreate/HyCreate${HYCREATE_VERSION}/HyCreate2.8.jar "\$@"
EOF
# Note: the previous line must not be indented
    chmod +x hycreate
    
    # Set environment for Hyst
    
    MY_PYTHONPATH="${MY_PYTHONPATH}:${HYST_PREFIX}/hyst/src/hybridpy"
    HYPYPATH="$HYPYPATH:${HYST_PREFIX}/hyst/src"
    MY_PATH="${MY_PATH}:${HYST_PREFIX}/hyst"
    
    # save environment variables to file
    echo "export PATH=\"\$PATH:${MY_PATH}\"" >> ${HYST_PREFIX}/environment
    echo "export PYTHONPATH=\"\$PYTHONPATH:${MY_PYTHONPATH}\"" >> ${HYST_PREFIX}/environment
    echo "export HYPYPATH=\"\$HYPYPATH:${HYPYPATH}\"" >> ${HYST_PREFIX}/environment
    
    # automatically load environment variables on login
    echo "source '${HYST_PREFIX}/environment'" > /etc/profile.d/99-hyst.sh
fi

if ! [ "x$1" == "x--only-dependencies" ]; then

    ##################
    # Install Hyst
    ##################

    source ${HYST_PREFIX}/environment
    
    ln -sf "${SCRIPT_DIR}/" "${HYST_PREFIX}/hyst"
    cd "${HYST_PREFIX}/hyst/src"
    ant build
    # workaround: make directory accessible to all users, to simplify modifications of Hyst
    chmod --recursive a+w .

fi

echo "You need to log in and out again to load the required environment variables. Or run the following command:"
echo "source '${HYST_PREFIX}/environment'"
echo ""
echo "The tools are then available on the command line (hyst, spaceex, ...)."
