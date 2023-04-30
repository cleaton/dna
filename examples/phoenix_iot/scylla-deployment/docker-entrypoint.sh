#!/bin/bash

# Check if the required parameters (APPNAME and MEMORY_LIMIT) are supplied
if [ -z "$APPNAME" ]; then
    export APPNAME="${FLY_APP_NAME}"
fi

if [ -z "$MEMORY_LIMIT" ]; then
    echo "Error: MEMORY_LIMIT environment variable is not set"
    exit 1
fi

# Fetch the seed nodes using Python
SEED_NODES=$(python3 -c "import socket; \
    try: \
        addr_info = socket.getaddrinfo('${APPNAME}.internal', None, socket.AF_INET6); \
        ips = ','.join([info[4][0] for info in addr_info]); \
        print(ips); \
    except socket.gaierror: \
        exit()" 2>/dev/null)

# Fetch the local IPv6 address
LISTEN_ADDRESS=$(python3 -c "import socket, os; \
    info = socket.getaddrinfo('fly-local-6pn', None, socket.AF_INET6, socket.SOCK_STREAM, socket.IPPROTO_TCP); \
    print(info[0][4][0])")
# Prepare the Scylla command-line arguments
SCYLLA_ARGS="--listen-address ${LISTEN_ADDRESS} --memory ${MEMORY_LIMIT}"
echo SCYLLA_ARGS

# Add seeds argument if seed nodes were fetched successfully
if [ ! -z "$SEED_NODES" ]; then
    SCYLLA_ARGS="${SCYLLA_ARGS} --seeds ${SEED_NODES}"
fi

# Run the original entrypoint script with the command-line arguments
python3 /docker-entrypoint.py $SCYLLA_ARGS &


export CQLSH_HOST="${LISTEN_ADDRESS}"
# Wait for Scylla to come online
echo "Waiting for Scylla to come online..."
while true; do
    if cqlsh -e "SHOW VERSION" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

# Create keyspace using cqlsh
echo "Creating keyspace dna..."
cqlsh -e "CREATE KEYSPACE IF NOT EXISTS dna WITH REPLICATION = {'class' : 'SimpleStrategy', 'replication_factor' : 1};"

## Wait for scylla process to shut down
wait