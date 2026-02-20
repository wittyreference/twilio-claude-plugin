#!/bin/bash
# ABOUTME: Idempotent dependency installer for the Twilio Claude Plugin.
# ABOUTME: Checks and installs Homebrew, Node.js 20+, Twilio CLI, and Serverless plugin.

set -euo pipefail

# --- Colors and formatting ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

PASS="${GREEN}✓${NC}"
FAIL="${RED}✗${NC}"
SKIP="${YELLOW}→${NC}"
INFO="${BLUE}ℹ${NC}"

# --- State tracking ---
declare -a RESULTS=()

log_result() {
  local name="$1"
  local status="$2"  # installed, skipped, failed
  local detail="${3:-}"
  RESULTS+=("${name}|${status}|${detail}")
}

print_step() {
  echo -e "\n${BOLD}[$1/$TOTAL_STEPS]${NC} $2"
}

# --- OS detection ---
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
elif [[ "$OSTYPE" == "linux"* ]]; then
  OS="linux"
  if command -v apt-get &>/dev/null; then
    LINUX_PKG="apt"
  elif command -v dnf &>/dev/null; then
    LINUX_PKG="dnf"
  elif command -v yum &>/dev/null; then
    LINUX_PKG="yum"
  else
    LINUX_PKG="unknown"
  fi
fi

TOTAL_STEPS=6

echo -e "${BOLD}Twilio Claude Plugin — Dependency Installer${NC}"
echo -e "OS detected: ${BOLD}${OS}${NC}"
echo ""

# --- Step 1: Homebrew (macOS only) ---
check_homebrew() {
  print_step 1 "Homebrew"

  if [[ "$OS" != "macos" ]]; then
    echo -e "  ${SKIP} Skipped (not macOS)"
    log_result "Homebrew" "skipped" "not macOS"
    return 0
  fi

  if command -v brew &>/dev/null; then
    local brew_version
    brew_version=$(brew --version | head -1)
    echo -e "  ${PASS} Already installed (${brew_version})"
    log_result "Homebrew" "skipped" "already installed"
    return 0
  fi

  echo -e "  ${INFO} Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if command -v brew &>/dev/null; then
    echo -e "  ${PASS} Installed successfully"
    log_result "Homebrew" "installed" ""
  else
    echo -e "  ${FAIL} Installation failed"
    echo -e "  ${INFO} Install manually: https://brew.sh"
    log_result "Homebrew" "failed" "install script failed"
    return 1
  fi
}

# --- Step 2: Node.js 20+ ---
check_node() {
  print_step 2 "Node.js 20+"

  if command -v node &>/dev/null; then
    local node_version
    node_version=$(node --version | sed 's/v//')
    local major_version
    major_version=$(echo "$node_version" | cut -d. -f1)

    if [[ "$major_version" -ge 20 ]]; then
      echo -e "  ${PASS} Already installed (v${node_version})"
      log_result "Node.js" "skipped" "v${node_version} already installed"
      return 0
    else
      echo -e "  ${YELLOW}⚠${NC}  Found v${node_version} but need 20+."
      echo -e "  ${INFO} Will not upgrade existing install. Please upgrade manually:"
      if [[ "$OS" == "macos" ]]; then
        echo "       brew upgrade node"
      else
        echo "       https://nodejs.org/en/download/"
      fi
      log_result "Node.js" "failed" "v${node_version} too old, needs 20+"
      return 1
    fi
  fi

  echo -e "  ${INFO} Installing Node.js..."

  if [[ "$OS" == "macos" ]]; then
    if command -v brew &>/dev/null; then
      brew install node
    else
      echo -e "  ${FAIL} Homebrew not available. Install Node.js manually:"
      echo "       https://nodejs.org/en/download/"
      log_result "Node.js" "failed" "no package manager"
      return 1
    fi
  elif [[ "$OS" == "linux" ]]; then
    # Use NodeSource for Node.js 20
    if [[ "$LINUX_PKG" == "apt" ]]; then
      echo -e "  ${INFO} Adding NodeSource repository..."
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
      sudo apt-get install -y nodejs
    elif [[ "$LINUX_PKG" == "dnf" || "$LINUX_PKG" == "yum" ]]; then
      curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
      sudo "$LINUX_PKG" install -y nodejs
    else
      echo -e "  ${FAIL} Unknown package manager. Install Node.js manually:"
      echo "       https://nodejs.org/en/download/"
      log_result "Node.js" "failed" "unknown package manager"
      return 1
    fi
  fi

  if command -v node &>/dev/null; then
    local installed_version
    installed_version=$(node --version)
    echo -e "  ${PASS} Installed (${installed_version})"
    log_result "Node.js" "installed" "${installed_version}"
  else
    echo -e "  ${FAIL} Installation failed"
    log_result "Node.js" "failed" ""
    return 1
  fi
}

# --- Step 3: npm ---
check_npm() {
  print_step 3 "npm"

  if command -v npm &>/dev/null; then
    local npm_version
    npm_version=$(npm --version)
    echo -e "  ${PASS} Already installed (v${npm_version})"
    log_result "npm" "skipped" "v${npm_version} (bundled with Node)"
    return 0
  fi

  echo -e "  ${FAIL} npm not found. This usually comes with Node.js."
  echo -e "  ${INFO} Reinstall Node.js to get npm."
  log_result "npm" "failed" "missing despite Node.js"
  return 1
}

# --- Step 4: Twilio CLI ---
check_twilio_cli() {
  print_step 4 "Twilio CLI"

  if command -v twilio &>/dev/null; then
    local twilio_version
    twilio_version=$(twilio --version 2>/dev/null | head -1)
    echo -e "  ${PASS} Already installed (${twilio_version})"
    log_result "Twilio CLI" "skipped" "already installed"
    return 0
  fi

  echo -e "  ${INFO} Installing Twilio CLI..."
  npm install -g twilio-cli

  if command -v twilio &>/dev/null; then
    local installed_version
    installed_version=$(twilio --version 2>/dev/null | head -1)
    echo -e "  ${PASS} Installed (${installed_version})"
    log_result "Twilio CLI" "installed" ""
  else
    echo -e "  ${FAIL} Installation failed"
    echo -e "  ${INFO} Try: npm install -g twilio-cli"
    log_result "Twilio CLI" "failed" ""
    return 1
  fi
}

# --- Step 5: Serverless Plugin ---
check_serverless_plugin() {
  print_step 5 "Serverless Plugin"

  if ! command -v twilio &>/dev/null; then
    echo -e "  ${SKIP} Skipped (Twilio CLI not installed)"
    log_result "Serverless Plugin" "skipped" "Twilio CLI missing"
    return 0
  fi

  if twilio plugins 2>/dev/null | grep -q "@twilio-labs/plugin-serverless"; then
    echo -e "  ${PASS} Already installed"
    log_result "Serverless Plugin" "skipped" "already installed"
    return 0
  fi

  echo -e "  ${INFO} Installing @twilio-labs/plugin-serverless..."
  twilio plugins:install @twilio-labs/plugin-serverless

  if twilio plugins 2>/dev/null | grep -q "@twilio-labs/plugin-serverless"; then
    echo -e "  ${PASS} Installed"
    log_result "Serverless Plugin" "installed" ""
  else
    echo -e "  ${FAIL} Installation failed"
    echo -e "  ${INFO} Try: twilio plugins:install @twilio-labs/plugin-serverless"
    log_result "Serverless Plugin" "failed" ""
    return 1
  fi
}

# --- Step 6: Claude Code ---
check_claude_code() {
  print_step 6 "Claude Code"

  if command -v claude &>/dev/null; then
    local claude_version
    claude_version=$(claude --version 2>/dev/null || echo "unknown version")
    echo -e "  ${PASS} Installed (${claude_version})"
    log_result "Claude Code" "skipped" "already installed"
    return 0
  fi

  echo -e "  ${YELLOW}⚠${NC}  Not found. Claude Code cannot be auto-installed."
  echo -e "  ${INFO} Install from: https://claude.ai/download"
  echo -e "  ${INFO} Or via npm:   npm install -g @anthropic-ai/claude-code"
  log_result "Claude Code" "failed" "not installed — manual install required"
  return 0  # Don't fail the script for this
}

# --- Print summary ---
print_summary() {
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}Summary${NC}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  printf "  %-22s %-12s %s\n" "Component" "Status" "Detail"
  echo "  ─────────────────────────────────────────────"

  local has_failures=0
  for result in "${RESULTS[@]}"; do
    IFS='|' read -r name status detail <<< "$result"
    case "$status" in
      installed) printf "  %-22s ${GREEN}%-12s${NC} %s\n" "$name" "installed" "$detail" ;;
      skipped)   printf "  %-22s ${YELLOW}%-12s${NC} %s\n" "$name" "skipped" "$detail" ;;
      failed)    printf "  %-22s ${RED}%-12s${NC} %s\n" "$name" "FAILED" "$detail"; has_failures=1 ;;
    esac
  done

  echo ""
  if [[ "$has_failures" -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All dependencies satisfied.${NC} You're ready to build with Twilio!"
    echo ""
    echo "Next steps:"
    echo "  1. Configure Twilio CLI:  twilio login"
    echo "  2. Install the plugin:    claude plugin add github:wittyreference/twilio-claude-plugin"
    echo "  3. Start building:        claude"
  else
    echo -e "${YELLOW}${BOLD}Some dependencies need attention.${NC} See details above."
  fi
  echo ""
}

# --- Main ---
check_homebrew || true
check_node || true
check_npm || true
check_twilio_cli || true
check_serverless_plugin || true
check_claude_code || true
print_summary
