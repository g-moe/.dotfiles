#!/usr/bin/env bash
set -euo pipefail

# Print guest CPU, GPU, and memory use for the Xfce Generic Monitor plugin.
# The plugin runs this script every two seconds and renders its XML output.

# /proc/stat contains cumulative CPU time. Compare two samples to calculate the
# percentage of non-idle time during a short interval.
read -r _ user nice system idle iowait irq softirq steal _ </proc/stat
first_total=$((user + nice + system + idle + iowait + irq + softirq + steal))
first_idle=$((idle + iowait))
sleep 0.1
read -r _ user nice system idle iowait irq softirq steal _ </proc/stat
second_total=$((user + nice + system + idle + iowait + irq + softirq + steal))
second_idle=$((idle + iowait))
total_delta=$((second_total - first_total))
idle_delta=$((second_idle - first_idle))
cpu=0
((total_delta > 0)) && cpu=$(((total_delta - idle_delta) * 100 / total_delta))

# MemAvailable includes memory that Linux can reclaim. It gives a more useful
# value than the unused-memory field alone.
read -r memory_total memory_available < <(
  awk '
    $1 == "MemTotal:" { total = $2 }
    $1 == "MemAvailable:" { available = $2 }
    END { print total, available }
  ' /proc/meminfo
)
memory=$(((memory_total - memory_available) * 100 / memory_total))

# Prefer the NVIDIA driver interface. If it is not available, check the AMD
# kernel interface. A Proxmox guest without GPU passthrough usually has neither.
gpu=''
if command -v nvidia-smi >/dev/null 2>&1; then
  gpu="$(timeout 1 nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null |
    awk 'NR == 1 { gsub(/ /, ""); print; exit }')"
fi
if [[ ! "$gpu" =~ ^[0-9]+$ ]]; then
  for busy_file in /sys/class/drm/card*/device/gpu_busy_percent; do
    [[ -r "$busy_file" ]] || continue
    read -r gpu <"$busy_file"
    break
  done
fi
[[ "$gpu" =~ ^[0-9]+$ ]] || gpu='N/A'

# Use fixed-width values so the two panel rows stay aligned as values change.
if [[ "$gpu" == 'N/A' ]]; then
  gpu_display=' N/A'
  gpu_tooltip='N/A'
else
  printf -v gpu_display '%3d%%' "$gpu"
  gpu_tooltip="${gpu}%"
fi
printf -v cpu_display '%3d%%' "$cpu"
printf -v memory_display '%3d%%' "$memory"

# The terminal prompt uses the same collected values without Genmon XML.
if [[ "${1:-}" == '--prompt' ]]; then
  if [[ "$gpu" == 'N/A' ]]; then
    printf 'CPU-%d%%%% | MEM %d%%%%\n' "$cpu" "$memory"
  else
    printf 'CPU-%d%%%% | GPU-%d%%%% | MEM %d%%%%\n' "$cpu" "$gpu" "$memory"
  fi
  exit 0
fi

# Generic Monitor reads these XML elements from standard output. The first
# element sets the panel text, the second sets its click action, and the last
# element sets the tooltip.
if [[ "$gpu" == 'N/A' ]]; then
  printf '<txt><span font_family="Inter" size="small"><b> CPU   MEM</b></span>\n<span font_family="Inter" size="medium">%s  %s</span></txt>\n' \
    "$cpu_display" "$memory_display"
else
  printf '<txt><span font_family="Inter" size="small"><b> CPU   GPU   MEM</b></span>\n<span font_family="Inter" size="medium">%s  %s  %s</span></txt>\n' \
    "$cpu_display" "$gpu_display" "$memory_display"
fi
printf '<txtclick>xfce4-taskmanager</txtclick>\n'
printf '<tool>CPU: %s%%\nGPU: %s\nMemory: %s%%</tool>\n' \
  "$cpu" "$gpu_tooltip" "$memory"
