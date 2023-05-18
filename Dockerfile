FROM mcr.microsoft.com/dotnet/sdk:3.1.407-buster AS build-env

ARG SONAR_HOST
ARG SONAR_PRJ_KEY
ARG SONAR_TOKEN

ENV SONAR_HOST=$SONAR_HOST
ENV SONAR_PRJ_KEY=$SONAR_PRJ_KEY
ENV SONAR_TOKEN=$SONAR_TOKEN

RUN set -eux; \
    apt-get clean; \
        wget https://packages.microsoft.com/config/ubuntu/22.10/packages-microsoft-prod.deb -O packages-microsoft-prod.deb; \
        wget https://packages.microsoft.com/ubuntu/18.04/prod/pool/main/n/netstandard-targeting-pack-2.1/netstandard-targeting-pack-2.1_2.1.0-1_amd64.deb; \
        dpkg -i packages-microsoft-prod.deb; \
        dpkg -i netstandard-targeting-pack-2.1_2.1.0-1_amd64.deb; \
        rm packages-microsoft-prod.deb; \
        rm netstandard-targeting-pack-2.1_2.1.0-1_amd64.deb; \
        apt-get update; \
        apt-get install -y --no-install-recommends \
        nuget \
                bzip2 \
                unzip \
                xz-utils \
                wget \
                netstandard-targeting-pack-2.1 \
                dotnet-sdk-6.0 \
                \
                binutils \
                \
                fontconfig libfreetype6 \
                \
                ca-certificates p11-kit \
        ; \
        rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME /usr/local/openjdk-16
ENV PATH $JAVA_HOME/bin:$PATH

# Default to UTF-8 file.encoding
ENV LANG C.UTF-8

# https://jdk.java.net/
# >
# > Java Development Kit builds, from Oracle
# >
ENV JAVA_VERSION 16

RUN set -eux; \
        \
        arch="$(dpkg --print-architecture)"; \
        case "$arch" in \
                'amd64') \
                        downloadUrl='https://download.java.net/java/GA/jdk16/7863447f0ab643c585b9bdebf67c69db/36/GPL/openjdk-16_linux-x64_bin.tar.gz'; \
                        downloadSha256='e952958f16797ad7dc7cd8b724edd69ec7e0e0434537d80d6b5165193e33b931'; \
                        ;; \
                'arm64') \
                        downloadUrl='https://download.java.net/java/GA/jdk16/7863447f0ab643c585b9bdebf67c69db/36/GPL/openjdk-16_linux-aarch64_bin.tar.gz'; \
                        downloadSha256='273d3ae0ff14af801c5ffa71fd081f1cc505354f308ce11c77af55302c83d2bf'; \
                        ;; \
                *) echo >&2 "error: unsupported architecture: '$arch'"; exit 1 ;; \
        esac; \
        \
        wget --progress=dot:giga -O openjdk.tgz "$downloadUrl"; \
        echo "$downloadSha256 *openjdk.tgz" | sha256sum --strict --check -; \
        \
        mkdir -p "$JAVA_HOME"; \
        tar --extract \
                --file openjdk.tgz \
                --directory "$JAVA_HOME" \
                --strip-components 1 \
                --no-same-owner \
        ; \
        rm openjdk.tgz*; \
        \
# update "cacerts" bundle to use Debian's CA certificates (and make sure it stays up-to-date with changes to Debian's store)
# see https://github.com/docker-library/openjdk/issues/327
#     http://rabexc.org/posts/certificates-not-working-java#comment-4099504075
#     https://salsa.debian.org/java-team/ca-certificates-java/blob/3e51a84e9104823319abeb31f880580e46f45a98/debian/jks-keystore.hook.in
#     https://git.alpinelinux.org/aports/tree/community/java-cacerts/APKBUILD?id=761af65f38b4570093461e6546dcf6b179d2b624#n29
        { \
                echo '#!/usr/bin/env bash'; \
                echo 'set -Eeuo pipefail'; \
                echo 'trust extract --overwrite --format=java-cacerts --filter=ca-anchors --purpose=server-auth "$JAVA_HOME/lib/security/cacerts"'; \
        } > /etc/ca-certificates/update.d/docker-openjdk; \
        chmod +x /etc/ca-certificates/update.d/docker-openjdk; \
        /etc/ca-certificates/update.d/docker-openjdk; \
        \
# https://github.com/docker-library/openjdk/issues/331#issuecomment-498834472
        find "$JAVA_HOME/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; \
        ldconfig; \
        \
# https://github.com/docker-library/openjdk/issues/212#issuecomment-420979840
# https://openjdk.java.net/jeps/341
        java -Xshare:dump; \
        \
# basic smoke test
        fileEncoding="$(echo 'System.out.println(System.getProperty("file.encoding"))' | jshell -s -)"; [ "$fileEncoding" = 'UTF-8' ]; rm -rf ~/.java; \
        javac --version; \
        java --version

ENV DOTNET_ROOT /usr/lib/dotnet

RUN dotnet tool install -g dotnet-sonarscanner

ENV PATH="$PATH:/root/.dotnet/tools"

COPY . /src

WORKDIR /src

# Start Sonar Scanner
RUN dotnet sonarscanner begin \
  /k:"$SONAR_PRJ_KEY" \
  /o:"$SONAR_PRJ_KEY" \
  /d:sonar.host.url="$SONAR_HOST" \
  /d:sonar.login="$SONAR_TOKEN"

RUN dotnet restore

COPY . .

RUN dotnet build

WORKDIR /src

# End Sonar Scanner
RUN dotnet sonarscanner end /d:sonar.login="$SONAR_TOKEN"
