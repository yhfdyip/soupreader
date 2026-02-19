#!/usr/bin/env bash
#
# codex_task_monitor.sh — minimal scheduler that runs
# `codex --dangerously-bypass-approvals-and-sandbox exec
# "continue to next task"` on a loop, restarting immediately if the codex
# process stays silent for longer than the configured inactivity timeout.

set -euo pipefail

cmd=(
  codex
  --sandbox danger-full-access
  --dangerously-bypass-approvals-and-sandbox
  exec
  --skip-git-repo-check
  "continue to next task"
)

if [[ -n "${CODEX_MONITOR_CMD:-}" ]]; then
  cmd=(bash -lc "${CODEX_MONITOR_CMD}")
fi

print_current_command() {
  local part
  local quoted=()
  for part in "${cmd[@]}"; do
    quoted+=("$(printf '%q' "$part")")
  done
  echo "[codex-monitor] command: ${quoted[*]}"
}

terminate_codex_process() {
  local pid=$1
  local grace_seconds=${2:-5}

  if ! kill -TERM "$pid" 2>/dev/null; then
    return 0
  fi

  for (( i = 0; i < grace_seconds; i++ )); do
    if ! kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done

  kill -KILL "$pid" 2>/dev/null || true
}

# Allow overrides via env vars: CODEX_MONITOR_INACTIVITY_TIMEOUT (seconds)
# and CODEX_MONITOR_INTERVAL_SECONDS (pause between completed runs).
inactivity_timeout=${CODEX_MONITOR_INACTIVITY_TIMEOUT:-60}
pause_seconds=${CODEX_MONITOR_INTERVAL_SECONDS:-60}

run_codex_with_watchdog() {
  local inactivity_limit=$1
  local last_output
  last_output=$(date +%s)
  local exit_code=0
  local inactivity_triggered=0
  local line
  local output_dir
  output_dir=$(mktemp -d -t codex-monitor-XXXXXX)
  local output_fifo="$output_dir/codex-output"

  mkfifo "$output_fifo"
  TERM=xterm "${cmd[@]}" >"$output_fifo" 2>&1 &
  local codex_pid=$!

  exec 3<"$output_fifo"
  rm -f "$output_fifo"

  while true; do
    local read_something=0
    if IFS= read -r -t 1 -u 3 line; then
      read_something=1
      last_output=$(date +%s)
      printf '%s\n' "$line"
    fi

    if (( read_something )); then
      continue
    fi

    if ! kill -0 "$codex_pid" 2>/dev/null; then
      # Flush any remaining output before capturing the exit code.
      while IFS= read -r -u 3 line; do
        printf '%s\n' "$line"
      done

      if ! wait "$codex_pid"; then
        exit_code=$?
      else
        exit_code=0
      fi
      break
    fi

    local now
    now=$(date +%s)
    if (( now - last_output >= inactivity_limit )); then
      echo "[codex-monitor] no output from codex for ${inactivity_limit}s; terminating run..." >&2
      terminate_codex_process "$codex_pid"
      if ! wait "$codex_pid"; then
        exit_code=$?
      else
        exit_code=0
      fi
      inactivity_triggered=1
      break
    fi
  done

  exec 3<&-
  rm -rf "$output_dir"

  if (( inactivity_triggered )); then
    return 124
  fi

  return "$exit_code"
}

while true; do
  echo "[codex-monitor] starting run at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  print_current_command

  if run_codex_with_watchdog "$inactivity_timeout"; then
    echo "[codex-monitor] codex exec completed successfully (exit 0)."
    echo "[codex-monitor] waiting ${pause_seconds}s before the next run..."
    sleep "$pause_seconds"
    continue
  else
    exit_code=$?

    if [[ $exit_code -eq 124 ]]; then
      echo "[codex-monitor] codex exec produced no output for ${inactivity_timeout}s. Restarting immediately."
      continue
    fi

    echo "[codex-monitor] codex exec exited with errors (exit $exit_code)."
    echo "[codex-monitor] waiting ${pause_seconds}s before the next run..."
    sleep "$pause_seconds"
  fi
done
