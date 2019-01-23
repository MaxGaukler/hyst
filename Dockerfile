# Dockerfile building a docker container with Hyst and all related tools
# This file is also helpful as a machine-readable and automatically tested instruction on how to build Hyst.

FROM ubuntu:18.04

# add the following line to use a mirror which is nearer to you than the default archive.ubuntu.com (example: ftp.fau.de):
RUN sed 's@archive.ubuntu.com@ftp.fau.de@' -i /etc/apt/sources.list

ENV RUNNING_IN_DOCKER true
# The installation is split into two steps so that the container can be rebuilt faster if only Hyst itself has changed.
# Step 1: everything except Hyst
ADD ./install_on_ubuntu_18_04.sh /tmp/
RUN HYST_PREFIX=/ /tmp/install_on_ubuntu_18_04.sh --only-dependencies

# Step 2: only Hyst
ADD . /tmp/hyst
RUN HYST_PREFIX=/ /tmp/hyst/install_on_ubuntu_18_04.sh --no-dependencies



# load environment variables
ENTRYPOINT /tmp/hyst/docker_entrypoint.sh

##################
# As default command: run the tests
##################

CMD ant test

# # USAGE:
# # Build container and name it 'hyst':
# docker build . -t hyst
# # run tests (default command)
# docker run hyst
# # get a shell:
# docker run hyst -it bash
# -> Hyst is available in /hyst/src, tools are in /tools, everything is on the path (try 'hyst -help', 'spaceex --help')
# # run Hyst:
# docker run hyst hyst -help
# # run Hyst via java path:
# docker run hyst java -jar /hyst/src/Hyst.jar -help
# # NOTE: like for a VM, the host system's folders need to be explicitly shared with the guest container.
# # To map /path_on_host to /data in the container:
# docker run -v /path_on_host:/data hyst hyst -t pysim '' -i /data/foo.xml -o /data/bar.xml
