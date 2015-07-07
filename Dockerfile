FROM ubuntu:14.04

RUN apt-get -y -q update
RUN apt-get -y -q upgrade

RUN apt-get -y -q install sqlite3 libsqlite3-dev
RUN apt-get -y -q install ruby ruby-dev nodejs g++ bundler

RUN mkdir -p /var/lib/sqlite \
    && touch /var/lib/sqlite/latcraft.db \

RUN gem install dashing


WORKDIR /vagrant
EXPOSE 3030
COPY . /vagrant
COPY ./config/latcraft.yml /etc/latcraft.yml
VOLUME /vagrant

RUN cd /vagrant && bundle install
