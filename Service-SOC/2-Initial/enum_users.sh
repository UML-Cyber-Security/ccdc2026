#!/bin/bash

OUTPUT="users.txt"
> "$OUTPUT"  # Clears and recreates the file on each run

COUNT=1

echo "$COUNT. root" >> "$OUTPUT"
COUNT=$((COUNT + 1))

while IFS=: read -r username _ uid _ _ _ shell; do
    if [[ "$uid" -ge 1000 && "$shell" != */nologin && "$shell" != */false ]]; then
        echo "$COUNT. $username" >> "$OUTPUT"
        COUNT=$((COUNT + 1))
    fi
done < /etc/passwd

echo "Users written to $OUTPUT"