#!/bin/bash
# Create or start scylla container
docker start dna-scylla || \
    docker run --name dna-scylla --net=host -d scylladb/scylla:5.2.0-rc3 --listen-address 127.0.0.1 --smp 1 --overprovisioned 1 --memory 128M
# Wait for scylla port to open
while ! nc -z localhost 9042; do sleep 1; done
# create table if not exists
docker exec dna-scylla cqlsh -e "CREATE KEYSPACE IF NOT EXISTS dna WITH REPLICATION = {'class' : 'SimpleStrategy', 'replication_factor' : 1};"
docker exec dna-scylla cqlsh -e "CREATE KEYSPACE IF NOT EXISTS test WITH REPLICATION = {'class' : 'SimpleStrategy', 'replication_factor' : 1};"