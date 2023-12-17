#!/bin/bash

add_or_replace_yaml() {
    FILE=$1
    KEY=$2
    VALUE=$3

    # Check if the key exists in the file
    if grep -q "^$KEY:" "$FILE"; then
        # If the key exists, replace it
        sed -i "s/^$KEY:.*/$KEY: $VALUE/" "$FILE"
    else
        # If the key doesn't exist, add it
        echo "$KEY: $VALUE" >> "$FILE"
    fi
}

# Check if the required parameters (APPNAME and MEMORY_LIMIT) are supplied
if [ -z "$APPNAME" ]; then
    export APPNAME="${FLY_APP_NAME}"
fi

if [ -z "$MEMORY_LIMIT" ]; then
    echo "Error: MEMORY_LIMIT environment variable is not set"
    exit 1
fi

add_or_replace_yaml /etc/scylla/scylla.yaml "enable_ipv6_dns_lookup" "true"

# Fetch the local IPv6 address
LISTEN_ADDRESS=$FLY_PRIVATE_IP

# Fetch the seed nodes using Python
SEED_NODES=$(python3 -c "import socket; \
    try: \
        addr_info = socket.getaddrinfo('${APPNAME}.internal', None, socket.AF_INET6); \
        ips = ','.join([info[4][0] for info in addr_info]); \
        print(ips); \
    except socket.gaierror: \
        exit()" 2>/dev/null)

# Convert SEED_NODES into an array
IFS=',' read -ra ADDR <<< "$SEED_NODES"

# Initialize an empty array to hold the filtered seed nodes
FILTERED_SEED_NODES=()

# Loop through the array
for i in "${ADDR[@]}"; do
    # If the element does not match LISTEN_ADDRESS, add it to the new array
    if [ "$i" != "$LISTEN_ADDRESS" ]; then
        FILTERED_SEED_NODES+=("$i")
    fi
done

# Convert the new array back into a string
SEED_NODES=$(IFS=','; echo "${FILTERED_SEED_NODES[*]}")


# Prepare the Scylla command-line arguments
SCYLLA_ARGS="--listen-address ${LISTEN_ADDRESS} --rpc-address ${LISTEN_ADDRESS} --memory ${MEMORY_LIMIT}"


# Add seeds argument if seed nodes were fetched successfully
if [ ! -z "$SEED_NODES" ]; then
    SCYLLA_ARGS="${SCYLLA_ARGS} --seeds ${SEED_NODES}"
fi

echo $SCYLLA_ARGS

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