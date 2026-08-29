#!/usr/bin/env bash
# Stands in for `claude -p --output-format json` in offline tests: swallows
# the prompt on stdin, echoes a canned result envelope on stdout.
cat > /dev/null
printf '%s' '{"result": "ANSWER: A\nRULE: stub rule", "is_error": false, "total_cost_usd": 0.01, "usage": {"input_tokens": 100, "output_tokens": 20}}'
