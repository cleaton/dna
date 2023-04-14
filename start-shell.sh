#!/bin/bash
# start background process and close it when the script is closed
MIX_ENV=dev elixir --sname background -S mix run --no-halt &
trap "kill %1" EXIT
# start the server
MIX_ENV=dev iex --sname shell -S mix