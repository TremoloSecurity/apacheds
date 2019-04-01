FROM ubuntu:18.04

MAINTAINER Tremolo Security, Inc. - Docker <docker@tremolosecurity.com>

ENV JDK_VERSION=1.8.0 \
    APACHEDS_VERSION=2.0.0.AM25 

LABEL io.k8s.description="ApacheDS" \
      io.k8s.display-name="ApacheDS" 

RUN apt-get update;apt-get -y install openjdk-8-jdk-headless curl apt-transport-https gnupg netcat ldap-utils && \
    apt-get -y upgrade;apt-get clean;rm -rf /var/lib/apt/lists/*; \
    groupadd -r apacheds -g 433 && \
    mkdir /usr/local/apacheds && \
    useradd -u 431 -r -g apacheds -d /usr/local/apacheds -s /sbin/nologin -c "ApacheDS image user" apacheds && \
    curl http://www.apache.org/dist/directory/apacheds/dist/$APACHEDS_VERSION/apacheds-$APACHEDS_VERSION.tar.gz -o /usr/local/apacheds/apacheds.tar.gz && \
    cd /usr/local/apacheds && \
    tar -xvzf apacheds.tar.gz



RUN chown -R apacheds:apacheds /usr/local/apacheds 


USER 431

CMD ["/usr/bin/java", "-jar", "/usr/local/apacheds/javascript-operator.jar"]