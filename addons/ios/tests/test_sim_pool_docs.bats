#!/usr/bin/env bats

# AC6: sim-pool documentation includes Device Set isolation info.

SIM_POOL="skills/sim-pool/SKILL.md"

# --- AC6.1: English doc mentions SIM_GOLDEN_SET ---

@test "AC6.1: sim-pool SKILL.md documents SIM_GOLDEN_SET environment variable" {
  grep -q 'SIM_GOLDEN_SET' "$SIM_POOL"
}

# --- AC6.2: English doc mentions SIM_DEFAULT_SET ---

@test "AC6.2: sim-pool SKILL.md documents SIM_DEFAULT_SET environment variable" {
  grep -q 'SIM_DEFAULT_SET' "$SIM_POOL"
}

# --- AC6.3: English doc explains Device Set isolation ---

@test "AC6.3: sim-pool SKILL.md explains Device Set isolation" {
  grep -qi 'Device Set' "$SIM_POOL"
}

# --- AC6.4: English doc explains cross-set clone ---

@test "AC6.4: sim-pool SKILL.md mentions cross-set clone" {
  grep -qi 'cross.set.*clone\|clone.*destination\|--set.*clone' "$SIM_POOL"
}
