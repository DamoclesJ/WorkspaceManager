#!/bin/bash
# ============================================================================
# U8 (R27U81) 输入源 DDC 切换验证脚本 (v3)
# 修复：
#   - v2 bug: "$subcmd" 双引号导致 "set input" 被当作单个参数 → 用 $subcmd 词拆分
#   - bash 3.2 (macOS) UTF-8 中文标签乱码 → 标签改用 ASCII
# ============================================================================

DISP=1
LOG="input-switch-test-$(date +%Y%m%d-%H%M%S).log"
MODE="${1:-}"

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

online() {
  m1ddc display "$DISP" get luminance >/dev/null 2>&1
  return $?
}

# 参数: label subcmd value
try_input() {
  label="$1"
  subcmd="$2"
  value="$3"

  if ! online; then
    log "SKIP $label=$value (display offline)"
    return 1
  fi

  lum_before=$(m1ddc display "$DISP" get luminance 2>/dev/null)
  log "TRY $label=$value [cmd: m1ddc display $DISP $subcmd $value]"

  # 注意: $subcmd 必须不带引号,让 shell 拆分 "set input" -> set input
  m1ddc display "$DISP" $subcmd "$value" >/dev/null 2>&1
  rc=$?
  if [ $rc -ne 0 ]; then
    log "  FAIL cmd exit=$rc"
    return 0
  fi
  log "  OK cmd accepted"

  sleep 4

  if online; then
    lum_after=$(m1ddc display "$DISP" get luminance 2>/dev/null)
    if [ "$lum_after" = "$lum_before" ]; then
      log "  RESULT no-switch (lum $lum_before -> $lum_after)"
    else
      log "  RESULT side-effect (lum $lum_before -> $lum_after)"
    fi
    return 0
  else
    log "  RESULT DISPLAY LOST - switched away! restore via Windows/OSD"
    return 2
  fi
}

echo "============================================================"
echo " U8 input-source DDC switch validation v3"
echo " Display: $(m1ddc display list 2>/dev/null | head -1)"
echo " Mode:    ${MODE:---run to execute}"
echo " Log:     $LOG"
echo "============================================================"

if [ "$MODE" != "--run" ]; then
  echo ""
  echo "Test plan (A safe -> D dangerous):"
  echo "  A: HDMI1=17, HDMI2=18 (VESA standard)"
  echo "  B: HDMI1-alt=144, HDMI2-alt=145 (LG addressing)"
  echo "  C: vendor 5 6 7 8 14 19 20 (VESA-reserved / vendor mapped)"
  echo "  D: DP1=15, DP2=16, DP1-alt=208, DP2-alt=209, USB-C=27, USB-C-alt=210"
  echo ""
  echo "Run: $0 --run"
  exit 0
fi

log "=== SNAPSHOT ==="
m1ddc display list detailed | tee -a "$LOG"
log "lum=$(m1ddc display "$DISP" get luminance 2>/dev/null)"
log "contrast=$(m1ddc display "$DISP" get contrast 2>/dev/null)"

if ! online; then
  log "ABORT: display offline"
  exit 1
fi

# A: HDMI standard (current input, expect no change)
try_input "A-HDMI1" "set input" 17
try_input "A-HDMI2" "set input" 18
# B: LG alt addressing
try_input "B-HDMI1-alt" "set input-alt" 144
try_input "B-HDMI2-alt" "set input-alt" 145
# C: vendor extended (v2ex report: input 5 works on U8! test siblings 6-8)
try_input "C-vendor5" "set input" 5
try_input "C-vendor6" "set input" 6
try_input "C-vendor7" "set input" 7
try_input "C-vendor8" "set input" 8
try_input "C-ext14" "set input" 14
try_input "C-ext19" "set input" 19
try_input "C-ext20" "set input" 20
# D: DP / USB-C (dangerous)
try_input "D-DP1" "set input" 15
try_input "D-DP2" "set input" 16
try_input "D-DP1-alt" "set input-alt" 208
try_input "D-DP2-alt" "set input-alt" 209
try_input "D-USB-C" "set input" 27
try_input "D-USB-C-alt" "set input-alt" 210

log "=== DONE ==="
log "final online=$(online && echo yes || echo no)"
echo ""
echo "Results in $LOG"
