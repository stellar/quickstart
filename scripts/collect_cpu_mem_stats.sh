#!/usr/bin/env bash

# Collect cpu and memory stats from a running quickstart.
#
# Example:
#   while ./scripts/collect_cpu_mem_stats.sh >> stats.json; do sleep 1; done

time=$(date +%s)

docker=$(docker stats --no-stream --format json stellar)

ps=$(docker exec stellar ps -u stellar,postgres -o comm=,rss= \
    | jq -R '. | split(" +";"") | {"comm":.[0],"rss":.[1] | tonumber}' \
    | jq -s 'group_by(.comm) | map({"comm":.[0].comm,"rss":map(.rss) | add})')

jq -cn \
    --argjson time "$time" \
    --argjson docker "$docker" \
    --argjson ps "$ps" \
    '$ARGS.named'

