#!/bin/bash
# Fully custom idle daemon — no DE help, you own DPMS + suspend
# Polls loginctl IdleHint + CPU 1s + per-PID agent 4% (rate-limited = suspend ok)
# DPMS 300s, suspend 1800s — picky, manual-control friendly
set -euo pipefail

SYS_THRESH=4
AGENT_THRESH=4.0
DPMS_TIMEOUT=300
SUSPEND_TIMEOUT=1800
POLL=5
CLK_TCK=$(getconf CLK_TCK 2>/dev/null || echo 100)
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/custom-idle"
mkdir -p "$STATE_DIR"
DPMS_OFF=0

log() { echo "$(date '+%F %T'): $*" | systemd-cat -t custom-idle; echo "$*"; }

# idle seconds via loginctl (preferred, DE-agnostic) fallback to cursorpos polling
get_idle_sec() {
  local sess=$(loginctl --no-legend 2>/dev/null | grep "$(whoami)" | awk '{print $1}' | head -n1)
  if [ -n "$sess" ]; then
    local hint=$(loginctl show-session "$sess" -p IdleHint --value 2>/dev/null || echo no)
    if [ "$hint" = "yes" ]; then
      local since=$(loginctl show-session "$sess" -p IdleSinceHintMonotonic --value 2>/dev/null || echo 0)
      local now=$(awk '{print $1}' /proc/uptime 2>/dev/null | cut -d. -f1)
      # IdleSinceHintMonotonic is monotonic usec
      local since_sec=$((since / 1000000))
      local now_mono=$(awk '{print $1}' /proc/uptime 2>/dev/null | cut -d. -f1) # uptime ~ monotonic
      # fallback: use IdleSinceHint (wall time) if monotonic not reliable
      # Use: idle = now_mono - since_sec
      local idle=$((now_mono - since_sec))
      [ "$idle" -lt 0 ] && idle=0
      echo "$idle"
      return
    else
      echo 0
      return
    fi
  fi
  echo 0
}

# fallback cursorpos poll: track last pos
LAST_X=""; LAST_Y=""; LAST_MOVE=$(date +%s)
get_idle_fallback() {
  local pos=$(hyprctl cursorpos 2>/dev/null | tr -d ' ' || echo "0,0")
  local x=$(echo "$pos" | cut -d, -f1); local y=$(echo "$pos" | cut -d, -f2)
  if [ "$x" != "$LAST_X" ] || [ "$y" != "$LAST_Y" ]; then
    LAST_X="$x"; LAST_Y="$y"; LAST_MOVE=$(date +%s)
  fi
  echo $(( $(date +%s) - LAST_MOVE ))
}

sys_cpu_1s() {
  read -r cpu a b c idle1 rest < <(grep '^cpu ' /proc/stat); total1=$((a+b+c+idle1))
  sleep 1
  read -r cpu a b c idle2 rest < <(grep '^cpu ' /proc/stat); total2=$((a+b+c+idle2))
  local idle_diff=$((idle2-idle1)); local total_diff=$((total2-total1))
  [ "$total_diff" -eq 0 ] && echo 0 && return
  echo $((100*(total_diff-idle_diff)/total_diff))
}

agent_busy_1s() {
  local pats=("opencode" "claude" "codex" "pi")
  local pids_all=()
  declare -A start
  for pat in "${pats[@]}"; do
    local pids=$(pgrep -f "$pat" 2>/dev/null || true)
    for pid in $pids; do
      [ ! -d "/proc/$pid" ] && continue
      local all=$(pstree -p "$pid" 2>/dev/null | grep -o '([0-9]\+)' | tr -d '()' || echo "$pid")
      for apid in $all; do
        [ ! -d "/proc/$apid" ] && continue
        if [[ ! " ${pids_all[*]} " =~ " $apid " ]]; then
          pids_all+=("$apid")
          local ticks=$(awk '{print $14+$15+$16+$17}' /proc/$apid/stat 2>/dev/null || echo 0)
          start[$apid]=$ticks
        fi
      done
    done
  done
  [ ${#pids_all[@]} -eq 0 ] && return 1 # no agents -> not busy
  sleep 1
  for apid in "${pids_all[@]}"; do
    [ ! -d "/proc/$apid" ] && continue
    local ticks2=$(awk '{print $14+$15+$16+$17}' /proc/$apid/stat 2>/dev/null || echo 0)
    local t1=${start[$apid]:-0}
    local diff=$((ticks2 - t1)); [ "$diff" -lt 0 ] && diff=0
    local usage=$(awk -v d="$diff" -v clk="$CLK_TCK" 'BEGIN{printf "%.1f", (d/clk*100)}')
    local busy=$(awk -v u="$usage" -v t="$AGENT_THRESH" 'BEGIN{print (u+0 > t+0)}')
    if [ "$busy" = "1" ]; then
      local comm=$(ps -o comm= -p "$apid" 2>/dev/null | xargs)
      log "AGENT BUSY pid $apid ($comm) 1s ${usage}% > ${AGENT_THRESH}%"
      return 0
    fi
  done
  return 1
}

log "custom-idle start DPMS=${DPMS_TIMEOUT}s SUSPEND=${SUSPEND_TIMEOUT}s SYS=${SYS_THRESH}% AGENT=${AGENT_THRESH}% poll=${POLL}s"

while true; do
  # idle via loginctl, fallback to cursorpos if 0 but we know idle may be 0 due to IdleHint no
  idle=$(get_idle_sec)
  if [ "$idle" -eq 0 ]; then
    # if loginctl says not idle, check cursor fallback as secondary (helps when IdleHint not set)
    fb=$(get_idle_fallback)
    # take max? if either says idle, use it
    [ "$fb" -gt "$idle" ] && idle=$fb
  fi

  # DPMS
  if [ "$idle" -ge "$DPMS_TIMEOUT" ] && [ "$DPMS_OFF" -eq 0 ]; then
    log "idle ${idle}s >= DPMS ${DPMS_TIMEOUT}s -> dpms off"
    hyprctl dispatch 'hl.dsp.dpms({action = "off"})' 2>/dev/null || hyprctl dispatch dpms off 2>/dev/null || true
    DPMS_OFF=1
  elif [ "$idle" -lt "$DPMS_TIMEOUT" ] && [ "$DPMS_OFF" -eq 1 ]; then
    log "active ${idle}s < DPMS -> dpms on"
    hyprctl dispatch 'hl.dsp.dpms({action = "on"})' 2>/dev/null || hyprctl dispatch dpms on 2>/dev/null || true
    DPMS_OFF=0
  fi

  # suspend
  if [ "$idle" -ge "$SUSPEND_TIMEOUT" ]; then
    sys=$(sys_cpu_1s)
    if [ "$sys" -ge "$SYS_THRESH" ]; then
      log "idle ${idle}s but SYS ${sys}% >= ${SYS_THRESH}% -> skip suspend"
      sleep "$POLL"; continue
    fi
    if agent_busy_1s; then
      log "idle ${idle}s SYS ${sys}% < ${SYS_THRESH}% but agent busy -> skip suspend"
      sleep "$POLL"; continue
    fi
    log "idle ${idle}s SYS ${sys}% < ${SYS_THRESH}% no busy agent -> suspend"
    systemctl suspend
    # after resume, reset DPMS
    sleep 5
    hyprctl dispatch 'hl.dsp.dpms({action = "on"})' 2>/dev/null || true
    DPMS_OFF=0
  fi

  sleep "$POLL"
done
