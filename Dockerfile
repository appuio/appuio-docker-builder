# This image is intended for testing purposes, it has the same behavior as
# the ose-docker-builder image, but does so as a custom image so it can
# be used with Custom build strategies.  It expects a set of
# environment variables to parameterize the build:
#
#   OUTPUT_REGISTRY - the Docker registry URL to push this image to
#   OUTPUT_IMAGE - the name to tag the image with
#   SOURCE_URI - a URI to fetch the build context from
#   SOURCE_REF - a reference to pass to Git for which commit to use (optional)
#
# This image expects to have the Docker socket bind-mounted into the container.
# If "/root/.dockercfg" is bind mounted in, it will use that as authorization
# to a Docker registry.
#
# The standard name for this image is openshift/ose-custom-docker-builder
#
FROM rhel7

#RUN INSTALL_PKGS="bash openssh-clients" && \
#    yum install -y --disablerepo='*' --enablerepo=rhel-7-server-rpms --enablerepo=rhel-7-server-extras-rpms --enablerepo=rhel-7-server-optional-rpms $INSTALL_PKGS && \
#    rpm -V $INSTALL_PKGS && \
#    yum clean all

#    rpm -ihv https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \

LABEL io.k8s.display-name="APPUiO Docker Builder" \
      io.k8s.description="This is APPUiO Docker Builder which runs Docker builds in dedicated VMs."

ENV HOME=/root

COPY vmbuild.sh vmconnect.sh build.sh /tmp/
COPY ssh-privatekey /root/.ssh/id_rsa
RUN chmod -R og-rwx /root/.ssh; chmod +x /tmp/*.sh

ENTRYPOINT ["/tmp/vmbuild.sh"]
