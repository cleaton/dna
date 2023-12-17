# Use the official ScyllaDB Docker image as the base
FROM scylladb/scylla:5.4
# remove scripts we don't need to reduce memory
RUN cd /etc/supervisord.conf.d/ && rm rsyslog.conf scylla-jmx.conf sshd-server.conf scylla-node-exporter.conf scylla-housekeeping.conf

ADD docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]