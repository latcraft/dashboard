FROM ubuntu:14.04

RUN apt-get -y -q update && \
    apt-get -y -q upgrade

RUN apt-get -y -q install sqlite3 libsqlite3-dev && \
    apt-get -y -q install ruby ruby-dev nodejs g++ bundler

RUN mkdir -p /var/lib/sqlite \
    && touch /var/lib/sqlite/latcraft.db \

RUN gem install dashing

WORKDIR /vagrant
COPY . /vagrant

VOLUME /vagrant
VOLUME /var/lib/sqlite

RUN cd /vagrant && \
    bundle install

EXPOSE 3030

#ENTRYPOINT ["dashing"]
CMD ["dashing", "start"]

