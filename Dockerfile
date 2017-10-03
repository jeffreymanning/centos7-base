FROM centos:centos7

MAINTAINER Jeff Manning

## Atomic/OpenShift Labels - https://github.com/projectatomic/ContainerApplicationGenericLabels
LABEL name="centos7" \
      vendor="MITRE Corp" \
      version="1.1" \
      release="1" \
      summary="MITRE's base 7 image, Oracle Java, Maven" \
      description="Centos7, Oracle Java, Maven root image" \
### Required labels above - recommended below

      run='docker run -tdi --name ${NAME} ${IMAGE}' \
      io.k8s.description="Centos, Oracle Java, Maven base image" \
      io.k8s.display-name="centos, java, maven" \
      io.openshift.expose-services="" \
      io.openshift.tags="centos7,java,maven"

USER root

#install the basic packages, must install sudo - some downstream consumers cannot run as root
# cleans/runs must match to avoid yum caches (bloat) in a layer
RUN yum clean all && \
    yum -y update && \
    yum -y install sudo && \
    yum clean all -y
RUN INSTALL_PKGS="wget curl net-tools build-essential git wget zip unzip vim" && \
    yum install -y --setopt=tsflags=nodocs ${INSTALL_PKGS} && \
    yum clean all -y


### Install Java 8
#### Per version variables (Need to find out from http://java.oracle.com site for every update)
ARG JAVA_MAJOR_VERSION=8
ARG JAVA_UPDATE_VERSION=144
ARG JAVA_BUILD_NUMBER=01
ARG JAVA_TOKEN=090f390dda5b47b9b721c7dfaa008135
ARG UPDATE_VERSION=${JAVA_MAJOR_VERSION}u${JAVA_UPDATE_VERSION}
ARG BUILD_VERSION=b${JAVA_BUILD_NUMBER}
ARG JAVA_JDK_HREF_ROOT="http://download.oracle.com/otn-pub/java/jdk/${UPDATE_VERSION}-${BUILD_VERSION}/${JAVA_TOKEN}"

#jdk, jre picker
ARG JAVA_JDK_DOWNLOAD=jdk-${UPDATE_VERSION}-linux-x64.tar.gz
ARG JAVA_JRE_DOWNLOAD=server-jre-${UPDATE_VERSION}-linux-x64.tar.gz
ARG JAVA_DOWNLOAD=${JAVA_JRE_DOWNLOAD}

ENV JAVA_HOME /usr/jdk1.${JAVA_MAJOR_VERSION}.0_${JAVA_UPDATE_VERSION}
ENV PATH $PATH:$JAVA_HOME/bin
ENV INSTALL_DIR /usr

# currently set for jre install
RUN curl -sL --retry 3 --insecure \
  --header "Cookie: oraclelicense=accept-securebackup-cookie;" \
  "${JAVA_JDK_HREF_ROOT}/${JAVA_DOWNLOAD}" \
  | gunzip \
  | tar x -C $INSTALL_DIR/ \
  && ln -s $JAVA_HOME $INSTALL_DIR/java \
  && rm -rf $JAVA_HOME/man

#### Install Maven 3
ARG MVN_MAJOR=3
ARG MVN_MINOR=5
ARG MVN_BLD=0
ARG MAVEN_VERSION=${MVN_MAJOR}.${MVN_MINOR}.${MVN_BLD}
ARG MAVEN_REPO=http://archive.apache.org/dist/maven/maven-${MVN_MAJOR}
ENV MAVEN_HOME /usr/apache-maven-${MAVEN_VERSION}
ENV PATH $PATH:$MAVEN_HOME/bin
RUN curl -sL ${MAVEN_REPO}/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  | gunzip \
  | tar x -C /usr/ \
  && ln -s $MAVEN_HOME /usr/maven

### Setup user for build execution and application runtime
# see https://github.com/RHsyseng/container-rhel-examples/blob/master/starter-epel/Dockerfile
ENV APP_ROOT=/opt/app-root
ENV USER_NAME=default
ENV USER_UID=1001
ENV APP_HOME=${APP_ROOT}/src
ENV PATH=$PATH:${APP_ROOT}/bin
RUN mkdir -p ${APP_HOME}
COPY bin/ ${APP_ROOT}/bin/


# see https://docs.openshift.org/latest/creating_images/guidelines.html
# By default, OpenShift Origin runs containers using an arbitrarily assigned user ID. This provides additional
# security against processes escaping the container due to a container engine vulnerability and thereby achieving
# escalated permissions on the host node.

# For an image to support running as an arbitrary user, directories and files that may be written to by
# processes in the image should be owned by the root group and be read/writable by that group.
# Files to be executed should also have group execute permissions.

# group 0 is the root group..  this is not root privs
# works later down docker layer chain with mounted volumes
# umask 0022 vs 002 note
#   by setting -M (or -m) -d ${APP_ROOT} or -s /etc/nologin /etc/profile are not called resulting in 0022 setting
RUN chmod -R ug+x ${APP_ROOT}/bin && sync && \
    groupadd -r ${USER_NAME}  && \
#    useradd -l -u ${USER_UID} -r -g 0 -d ${APP_ROOT} -s /sbin/nologin -c "${USER_NAME} user" ${USER_NAME} && \
#    usermod -aG ${USER_NAME}  ${USER_NAME}  && \
    useradd -u ${USER_UID} -g ${USER_NAME} ${USER_NAME} && \
    usermod -aG 0  ${USER_NAME}  && \
#    echo 'default:' | chpasswd && \
    chown -R ${USER_UID}:0 ${APP_ROOT} && \
    chmod -R g=u ${APP_ROOT}

### create a back door to get effective root
# see http://blog.dscpl.com.au/2016/12/backdoors-for-becoming-root-in-docker.html
# Allow anyone in group 'root' to use 'sudo' without a password.
RUN echo '%root ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
# Set the password for the 'root' user to be an empty string.
RUN echo 'root:' | chpasswd

####### Add app-specific needs below. #######
### Containers should NOT run as root as a good practice
USER ${USER_NAME}
WORKDIR ${APP_ROOT}
CMD ${APP_ROOT}/bin/run

# older way...
# moved back into specific layers (until needed)
#RUN groupadd -r spark && groupadd -r staff && useradd --no-log-init -r -g spark spark
#RUN usermod -aG wheel spark
#RUN usermod -aG staff spark
#RUN chown -R -L spark:spark /data

# testing
#USER spark

#### Define default command.
# these are removed - prevents container from running in pods.  Note - just running bash will not work.
# to get container running in pod without crashloop uncomment out the following line
#CMD exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"

