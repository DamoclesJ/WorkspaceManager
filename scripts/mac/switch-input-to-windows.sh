#!/bin/bash

if ! command -v m1ddc >/dev/null 2>&1; then
  echo "Error: m1ddc was not found in PATH." >&2
  exit 1
fi

echo "Switching Thunderbird U8 to Windows DP..."
m1ddc display 1 set input 7
status=$?

if [ "$status" -ne 0 ]; then
  echo "Error: m1ddc failed with exit code $status." >&2
  exit "$status"
fi

echo "U8 input switch command completed."
