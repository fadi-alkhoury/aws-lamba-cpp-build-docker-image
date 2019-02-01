FROM amazonlinux:2
 
ENV DOCKER_VERSION="19.03.1" \
 DOCKER_COMPOSE_VERSION="1.24.0" \
 DOCKER_BUCKET="download.docker.com" \
 DOCKER_CHANNEL="stable" \
 DOCKER_SHA256="6e7d8e24ee46b13d7547d751696d01607d19c8224c1b2c867acc8c779e77734b" \
 DIND_COMMIT="3b5fac462d21ca164b3778647420016315289034" \
 SRC_DIR="/usr/src" \
 EPEL_REPO="https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
  
# Install git, SSH, and other common requirements
RUN set -ex \
    && yum install -y openssh-clients \
    && mkdir ~/.ssh \
    && touch ~/.ssh/known_hosts \
    && ssh-keyscan -t rsa,dsa -H github.com >> ~/.ssh/known_hosts \
    && ssh-keyscan -t rsa,dsa -H bitbucket.org >> ~/.ssh/known_hosts \
    && chmod 600 ~/.ssh/known_hosts \
    && yum install -y $EPEL_REPO \
    && rpm --import https://download.mono-project.com/repo/xamarin.gpg \
    && curl https://download.mono-project.com/repo/centos7-stable.repo | tee /etc/yum.repos.d/mono-centos7-stable.repo \
    && amazon-linux-extras enable corretto8 \
    && yum groupinstall -y "Development tools" \
    && yum install -y zlib-devel \
    && yum install -y libcurl-devel \
    && yum install -y wget fakeroot jq \
       bzr mercurial procps-ng \
       ImageMagick \
       openssl-devel libdb-devel \
       libevent-devel libffi-devel GeoIP-devel glib2-devel \
       libjpeg-devel krb5-server xz-devel \
       mariadb-devel \
       ncurses-devel postgresql-devel readline-devel \
       libsqlite3x-devel libwebp-devel \
       libxml2-devel libxslt-devel libyaml-devel \
       e2fsprogs iptables xfsprogs \
       mono-devel groff \
       asciidoc cvs cvsps docbook-dtds docbook-style-xsl \
       perl-DBD-SQLite perl-DBI perl-HTTP-Date \
       perl-IO-Pty-Easy libserf subversion-perl tcl perl-TimeDate \
       perl-YAML-LibYAML bzrtools python-configobj \
       sgml-common xmlto libxslt \
       tk xorg-x11-server-Xvfb expect parallel rsync \
  && yum install -y glibc-static \
  && export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/lib64/" \
  && ldconfig \
  && yum clean all \
  && rm -rf /var/cache/yum
  
# Install Docker
RUN set -ex \
    && curl -fSL "https://${DOCKER_BUCKET}/linux/static/${DOCKER_CHANNEL}/x86_64/docker-${DOCKER_VERSION}.tgz" -o docker.tgz \
    && echo "${DOCKER_SHA256} *docker.tgz" | sha256sum -c - \
    && tar --extract --file docker.tgz --strip-components 1  --directory /usr/local/bin/ \
    && rm docker.tgz \
    && docker -v \
    # set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
    && groupadd dockremap \
    && useradd -g dockremap dockremap \
    && echo 'dockremap:165536:65536' >> /etc/subuid \
    && echo 'dockremap:165536:65536' >> /etc/subgid \
    && wget "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -O /usr/local/bin/dind \
    && curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64 > /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/dind /usr/local/bin/docker-compose \
    # Ensure docker-compose works
    && docker-compose version

# https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html 
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_CLI_installation.html
RUN curl -sS -o /usr/local/bin/aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/linux/amd64/aws-iam-authenticator \
 && curl -sS -o /usr/local/bin/kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/linux/amd64/kubectl \
 && curl -sS -o /usr/local/bin/ecs-cli https://s3.amazonaws.com/amazon-ecs-cli/ecs-cli-linux-amd64-latest \
 && chmod +x /usr/local/bin/kubectl /usr/local/bin/aws-iam-authenticator /usr/local/bin/ecs-cli

VOLUME /var/lib/docker

# Configure SSH
COPY ssh_config /root/.ssh/config

COPY dockerd-entrypoint.sh /usr/local/bin/

COPY share temp

# Install requirements for building cpp lambdas
RUN set -ex \
    && cd temp \
      && wget https://cmake.org/files/v3.10/cmake-3.10.0.tar.gz \
      && tar -xvzf cmake-3.10.0.tar.gz \
      && cd cmake-3.10.0 \
        && ./bootstrap \
        && make -j6 \
        && make install \
        && cd ../ \
      && git clone https://github.com/awslabs/aws-lambda-cpp.git \
      && cd aws-lambda-cpp \
        && mkdir build \
        && cd build\
          && cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
          && make -j4 \
          && make install \ 
          && cd ../ \
        && cd ../ \
      && git clone https://github.com/aws/aws-sdk-cpp.git \
      && cd aws-sdk-cpp \
        && mkdir build \
        && cd build\
          && cmake .. -DBUILD_SHARED_LIBS=OFF -DENABLE_UNITY_BUILD=ON  -DCMAKE_BUILD_TYPE=Release  \
          && make -j6 \
          && make install \
          && cd ../ \
        && cd ../ \
      && curl "https://d1vvhvl2y92vvt.cloudfront.net/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
      && unzip awscliv2.zip \
      && ./aws/install \ 
      && cd ../ \
      && rm -rd temp 
  
ENV PATH="/usr/local/bin:$PATH"

ENTRYPOINT ["dockerd-entrypoint.sh"]
