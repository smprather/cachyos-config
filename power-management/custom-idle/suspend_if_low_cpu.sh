#!/bin/bash
# Suspend only if system idle AND no agent actively working (1s precise samples)
# Rate-limited/idle agents (low CPU) = ok to suspend
SYS_THRESH=4
AGENT_CPU_THRESH=4.0
CLK_TCK=$(getconf CLK_TCK 2>/dev/null || echo 100)

log() { echo "$(date): $*" | systemd-cat -t suspend_check; echo "$*"; }

# Collect agent pids + descendants first
AGENT_PATTERNS=("opencode" "claude" "codex" "pi")
declare -A proc_start
pids_all=()
for pat in "${AGENT_PATTERNS[@]}"; do
  pids=$(pgrep -f "$pat" 2>/dev/null || true)
  [ -z "$pids" ] && continue
  for pid in $pids; do
    [ ! -d "/proc/$pid" ] && continue
    # get all descendants via pstree
    all=$(pstree -p "$pid" 2>/dev/null | grep -o '([0-9]\+)' | tr -d '()' || echo "$pid")
    [ -z "$all" ] && all="$pid"
    for apid in $all; do
      [ ! -d "/proc/$apid" ] && continue
      # deduplicate
      if [[ ! " ${pids_all[*]} " =~ " $apid " ]]; then
        pids_all+=("$apid")
        # store start ticks (utime+stime+cutime+cstime) fields 14-17
        stat=$(cat /proc/$apid/stat 2>/dev/null || true)
        [ -z "$stat" ] && continue
        # stat fields space-separated, but comm may contain spaces: handle by taking last fields? Use awk
        # field 14 is utime, but comm is field 2 with parentheses. Safer to awk with last fields:
        ticks=$(awk '{for(i=1;i<=NF;i++) if($i ~ /^\)$/){print $(i+12),$(i+13),$(i+14),$(i+15)}}' /proc/$apid/stat 2>/dev/null | awk '{print $1+$2+$3+$4}')
        # fallback simple:
        if [ -z "$ticks" ] || [ "$ticks" = "+" ]; then
          ticks=$(awk '{print $14+$15+$16+$17}' /proc/$apid/stat 2>/dev/null || echo 0)
        fi
        proc_start[$apid]=$ticks
      fi
    done
  done
done

# System start
read -r cpu a b c idle1 rest < <(grep '^cpu ' /proc/stat); total1=$((a+b+c+idle1))

sleep 1

# System end
read -r cpu a b c idle2 rest < <(grep '^cpu ' /proc/stat); total2=$((a+b+c+idle2))
idle_diff=$((idle2-idle1)); total_diff=$((total2-total1))
if [ "$total_diff" -eq 0 ]; then log "total_diff 0 skip"; exit 0; fi
sys_usage=$((100*(total_diff-idle_diff)/total_diff))
if [ "$sys_usage" -ge "$SYS_THRESH" ]; then
  log "SYS CPU ${sys_usage}% >= ${SYS_THRESH}% (1s sample) -> skip suspend"
  exit 0
fi
log "SYS CPU ${sys_usage}% < ${SYS_THRESH}% (1s sample) -> check agents 1s"

# Agent end + compute
is_busy=0
for apid in "${pids_all[@]}"; do
  [ ! -d "/proc/$apid" ] && continue
  stat=$(cat /proc/$apid/stat 2>/dev/null || true)
  [ -z "$stat" ] && continue
  ticks2=$(awk '{for(i=1;i<=NF;i++) if($i ~ /^\)$/){print $(i+12),$(i+13),$(i+14),$(i+15)}}' /proc/$apid/stat 2>/dev/null | awk '{print $1+$2+$3+$4}')
  if [ -z "$ticks2" ] || [ "$ticks2" = "+" ]; then
    ticks2=$(awk '{print $14+$15+$16+$17}' /proc/$apid/stat 2>/dev/null || echo 0)
  fi
  ticks1=${proc_start[$apid]:-0}
  diff=$((ticks2 - ticks1))
  # handle wrap/negative
  if [ "$diff" -lt 0 ]; then diff=0; fi
  # usage = diff / CLK_TCK *100 (percent of one core per 1s)
  usage=$(awk -v d="$diff" -v clk="$CLK_TCK" 'BEGIN{printf "%.1f", (d/clk*100)}')
  busy=$(awk -v u="$usage" -v t="$AGENT_CPU_THRESH" 'BEGIN{print (u+0 > t+0)}')
  if [ "$busy" = "1" ]; then
    comm=$(ps -o comm= -p "$apid" 2>/dev/null | tr -d '\n' | xargs)
    # also find parent pattern for logging
    log "AGENT BUSY: pid $apid ($comm) 1s CPU ${usage}% > ${AGENT_CPU_THRESH}% -> skip suspend"
    is_busy=1
    break
  fi
done

if [ "$is_busy" = "1" ]; then
  exit 0
fi

# Optional: log idle agents if any
if [ ${#pids_all[@]} -gt 0 ]; then
  log "No busy agents (checked ${#pids_all[@]} pids, all <${AGENT_CPU_THRESH}% 1s) -> suspending"
else
  log "No agent pids found, SYS idle -> suspending"
fi
systemctl suspend
