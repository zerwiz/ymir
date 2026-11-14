#!/usr/bin/env bash
# queue — the derived work queue is current.
gate queue       "the derived work queue is current"              bash "$ROOT/bin/gates/queue.sh" --check
