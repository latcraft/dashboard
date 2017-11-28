FROM ubuntu:16.04

RUN apt-get -y -q update && \
    apt-get -y -q upgrade

RUN apt-get -y -q install ruby ruby-dev nodejs g++ bundler sqlite3 libsqlite3-dev

RUN mkdir -p /opt/dashing && \
    cd /opt/dashing && \
    gem install dashing && \
    gem install rspec

VOLUME /app
VOLUME /var/lib/sqlite

WORKDIR /app

EXPOSE 3030

CMD ["bash", "-c", "bundle install --path /tmp/bundle && dashing start -P /var/run/thin.pid"]
