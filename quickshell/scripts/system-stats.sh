#!/bin/bash
# Prints a single JSON line with CPU/memory/disk/temperature stats for the
# System tab's sparklines. Combines what used to be four separate processes
# into one call so the panel only spawns a single shell per tick.

cpu_percent=$(top -bn2 -d 0.5 | grep '^%Cpu' | tail -1 | awk '{print 100-$8}')
cpu_cores=$(nproc)

read -r mem_percent mem_used mem_total <<< "$(free -g | awk 'NR==2 {printf "%.1f %.1f %.1f", ($3/$2)*100, $3, $2}')"

read -r disk_percent disk_used disk_free disk_total <<< "$(df -h / | awk 'NR==2 {gsub("G","",$3); gsub("G","",$4); gsub("G","",$2); gsub("%","",$5); print $5" "$3" "$4" "$2}')"

temp_c=$(sensors 2>/dev/null | grep -E 'Package id 0:|Tctl:|^CPU:' | head -1 | grep -oE '\+[0-9]+\.[0-9]+' | head -1 | tr -d '+')
temp_c="${temp_c:-0}"

python3 -c "
import json
print(json.dumps({
    'cpuPercent': float('$cpu_percent' or 0),
    'cpuCores': int('$cpu_cores' or 0),
    'memPercent': float('$mem_percent' or 0),
    'memUsedGb': float('$mem_used' or 0),
    'memTotalGb': float('$mem_total' or 0),
    'diskPercent': float('$disk_percent' or 0),
    'diskUsedGb': float('$disk_used' or 0),
    'diskFreeGb': float('$disk_free' or 0),
    'diskTotalGb': float('$disk_total' or 0),
    'tempC': float('$temp_c' or 0),
}))
"
