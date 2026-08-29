#!/bin/bash
exec "$(cd "$(dirname "$0")" && pwd)/sync-mako.py" "$@"
