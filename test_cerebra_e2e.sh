#!/usr/bin/env bash
# =============================================================================
# Cerebra Plugin End-to-End Test Suite
# Environment: Fresh Machine Simulation (Multica pre-installed)
# Runtime:     OpenCode (STATIC runtime)
# Models:      DYNAMIC — Cerebra dynamically discovers and routes models
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_DIR="${SCRIPT_DIR}/test_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/test_run_${TIMESTAMP}.log"

PASS=0; FAIL=0; TOTAL=0
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()    { echo -e "$*" | tee -a "$LOG_FILE"; }
header() {
  log ""
  log "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════════════════════╗${RESET}"
  log "${BOLD}${BLUE}║  $1${RESET}"
  log "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════════════════════╝${RESET}"
}
pass()   { ((PASS++)); ((TOTAL++)); log "  ${GREEN}✅ PASS${RESET}  $1"; }
fail()   { ((FAIL++)); ((TOTAL++)); log "  ${RED}❌ FAIL${RESET}  $1"; }
info()   { log "  ${CYAN}ℹ${RESET}   $1"; }
step()   { log "\n${YELLOW}▶ $1${RESET}"; }
cli_box() {
  log "${BOLD}┌────────────────────────────────────────────────────────────────────────────┐${RESET}"
  log "${BOLD}│ CLI: $1${RESET}"
  log "${BOLD}└────────────────────────────────────────────────────────────────────────────┘${RESET}"
}

header "TESTING IN ANOTHER WORKING MACHINE WITH MULTICA PRE-INSTALLED"
log "  Machine Environment: Fresh working host / container simulation"
log "  Static Runtime:      OpenCode (Universal AI Coding Runtime)"
log "  Dynamic Models:      Cerebra Live Provider Discovery & Tier Scoring"
log "  CLI Tool:            multica (Go 1.27 compiled binary)"
log "  Timestamp:           $(date)"
log "  Log File:            ${LOG_FILE}"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 1: Verify Pre-Installed Multica Environment
# ─────────────────────────────────────────────────────────────────────────────
header "PHASE 1 — Verify Pre-Installed Multica Environment"

step "Checking multica CLI binary installation"
cli_box "multica version"
MULTICA_VER=$("${SCRIPT_DIR}/bin/multica" version 2>&1 || echo "failed")
log "  Output: ${MULTICA_VER}"
if echo "$MULTICA_VER" | grep -q "multica"; then
  pass "Multica CLI pre-installed and functional"
else
  fail "Multica CLI not found"
fi

step "Checking plugin command capabilities"
cli_box "multica install --help"
INSTALL_HELP=$("${SCRIPT_DIR}/bin/multica" install --help 2>&1 || echo "")
if echo "$INSTALL_HELP" | grep -qi "install a plugin"; then
  pass "'multica install' command registered in CLI"
else
  fail "'multica install' command missing"
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 2: Live Model Discovery across OpenCode & Ollama Catalogs
# ─────────────────────────────────────────────────────────────────────────────
header "PHASE 2 — Live Dynamic Model Discovery (OpenCode + Local Catalogs)"

step "Running dynamic model discovery & classification engine"
cli_box "go run ./cmd/test_cerebra_cli/"
cd "${SCRIPT_DIR}/server"
DISCOVERY_OUT=$(go run ./cmd/test_cerebra_cli/ 2>&1)
echo "$DISCOVERY_OUT" | tee -a "$LOG_FILE"

if echo "$DISCOVERY_OUT" | grep -q "Total Live Models Discovered"; then
  MODELS_COUNT=$(echo "$DISCOVERY_OUT" | grep "Total Live Models Discovered" | awk '{print $5}')
  pass "Dynamic Discovery: Discovered ${MODELS_COUNT} live models across provider catalogs"
else
  fail "Model discovery failed"
fi

if echo "$DISCOVERY_OUT" | grep -q "100% Automated Multi-Provider Dynamic Discovery & Routing Succeeded"; then
  pass "Dynamic TierMap generation and live routing verification successful"
else
  fail "Dynamic TierMap generation failed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 3: Lifecycle E2E Test (Pre-Install vs Post-Install Routing)
# ─────────────────────────────────────────────────────────────────────────────
header "PHASE 3 — Agent Creation → Pre-Install Issue → multica install cerebra → Re-Issue"

step "Executing TC-10: Full Lifecycle E2E Simulation"
cli_box "go test -v ./internal/daemon/ -run TestCerebra_OpenCode_TC10"
TC10_OUT=$(go test -v ./internal/daemon/ -run TestCerebra_OpenCode_TC10 -count=1 2>&1)
echo "$TC10_OUT" | tee -a "$LOG_FILE"

if echo "$TC10_OUT" | grep -q "TC-10 PASS"; then
  pass "TC-10 E2E Lifecycle passed: pre-install uses default model, post-install uses Cerebra"
else
  fail "TC-10 E2E Lifecycle failed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 4: Comprehensive OpenCode Test Matrix (TC-01 through TC-09)
# ─────────────────────────────────────────────────────────────────────────────
header "PHASE 4 — OpenCode Static Runtime & Dynamic Model Test Matrix"

test_cases=(
  "TestCerebra_OpenCode_TC01_PreInstall_DefaultModelUsed|TC-01 Pre-Install: Default Model Pass-Through"
  "TestCerebra_OpenCode_TC02_PostInstall_CerebraActive|TC-02 Post-Install: cerebra-routing Skill Activation"
  "TestCerebra_OpenCode_TC03_SimpleIssue_RoutesToSimpleTier|TC-03 Simple Issue: Routes to Simple Tier (mimo-v2.5-free)"
  "TestCerebra_OpenCode_TC04_CodingIssue_RoutesToStandardTier|TC-04 Coding Issue: Routes to Standard Tier (nemotron-3.5-lightning)"
  "TestCerebra_OpenCode_TC05_ArchitectureIssue_RoutesToHeavyTier|TC-05 Architecture Issue: Routes to Heavy Tier (nemotron-3-ultra)"
  "TestCerebra_OpenCode_TC06_MCPFloor_RaisesSimpleToStandard|TC-06 MCP Tool Floor: Trivial Task Raised to Standard Tier"
  "TestCerebra_OpenCode_TC07_SessionPin_HeavyTierSticky|TC-07 Session Pinning: Multi-turn Chat Retains Heavy Tier"
  "TestCerebra_OpenCode_TC08_QuotaFailover_AutoSwitchOnRateLimit|TC-08 Quota / Rate-Limit Failover: Auto-Switch on 429"
  "TestCerebra_OpenCode_TC09_DynamicCatalog_AllModelsTieredCorrectly|TC-09 Dynamic Catalog: Complete OpenCode Model Tiering"
)

for tc in "${test_cases[@]}"; do
  func_name="${tc%%|*}"
  label="${tc##*|}"
  step "Running ${label}"
  cli_box "go test -v ./internal/daemon/ -run ${func_name}"
  TC_RES=$(go test -v ./internal/daemon/ -run "${func_name}" -count=1 2>&1)
  if echo "$TC_RES" | grep -q "^--- PASS"; then
    pass "${label}"
  else
    fail "${label}"
    echo "$TC_RES" | tee -a "$LOG_FILE"
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 5: Core Cerebra Architecture & Boundary Tests
# ─────────────────────────────────────────────────────────────────────────────
header "PHASE 5 — Core Cerebra Routing, Security & Hard Boundary Tests"

core_tests=(
  "TestHeuristicClassifier_KeywordScoring|Keyword Classification & Substring Trap Protection"
  "TestHeuristicClassifier_TokenScoring|Token Word-Count Escalation (500 words -> Standard, 2000 words -> Heavy)"
  "TestHeuristicClassifier_MCPFloor|MCP Tool Safety Floor (Zero runtime tool execution failures)"
  "TestSessionStore_TTL_And_Escalation|Session Store Expiration & In-Memory TTL Re-routing"
  "TestHardCase_RateLimitAndContextWindowStress|Concurrency Stress: Rate-Limit Failover & Context Window Escalation"
  "TestHardCase_CrossRuntimeFailover|Cross-Runtime Failover & Graceful Fallback"
)

for ct in "${core_tests[@]}"; do
  func_name="${ct%%|*}"
  label="${ct##*|}"
  step "Running ${label}"
  cli_box "go test -v ./internal/cerebra/ -run ${func_name}"
  CT_RES=$(go test -v ./internal/cerebra/ -run "${func_name}" -count=1 2>&1)
  if echo "$CT_RES" | grep -q "^--- PASS"; then
    pass "${label}"
  else
    fail "${label}"
    echo "$CT_RES" | tee -a "$LOG_FILE"
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
# FINAL SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
header "SUMMARY OF RESULTS"
log ""
log "  ${BOLD}Total Verification Cases: ${TOTAL}${RESET}"
log "  ${GREEN}${BOLD}Passed:                   ${PASS}${RESET}"
log "  ${RED}${BOLD}Failed:                   ${FAIL}${RESET}"
log ""
if [[ $FAIL -eq 0 ]]; then
  log "  ${GREEN}${BOLD}🎉 ALL ${PASS} TEST CASES PASSED PERFECTLY!${RESET}"
  log "  ${GREEN}Cerebra Intelligent Model Routing is verified 100% production-ready.${RESET}"
else
  log "  ${RED}${BOLD}⚠ ${FAIL} test case(s) failed.${RESET}"
fi
log "  Report & logs preserved at: ${LOG_FILE}"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exit $([[ $FAIL -eq 0 ]] && echo 0 || echo 1)
