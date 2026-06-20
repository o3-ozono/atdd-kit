# Acceptance Test Feasibility — Pre-Planning Probe Doctrine

> **Loaded by:** writing-plan-and-tests (Step 3), running-atdd-cycle (Step 4)

Before any Acceptance Test can be marked `[planned]`, its **feasibility must be verified by an actual probe** — a live system exercise that confirms the test route exists, can be driven by automation, and yields a deterministic pass/fail signal. This document is the canonical doctrine for how that probe is designed, where it fits in the 6-step flow, and how it integrates with the autopilot loop.

---

## Core Doctrine

The feasibility probe is not optional analysis — it is a **pre-planning gate**. No AT transitions from `[planned]`-candidate to `[planned]` without evidence that an executable route exists.

This doctrine distributes to every project that adopts atdd-kit. It is a methodology artifact, not project-specific configuration.

---

## Universal Rules

These rules are technology-stack-independent. They apply to every Issue regardless of platform, language, or framework.

### GUI vs Non-GUI Bifurcation

| Signal | Category | Probe form | Criteria for "feasible" |
|--------|----------|-----------|------------------------|
| AC targets a visible UI element, screen flow, or user gesture | **GUI** | Real operation — drive the actual UI (tap, click, swipe, fill, navigate) | UI element is reachable, automation can interact with it, a stable assertion can be captured |
| AC targets an API response, background job, file I/O, data transformation, service call | **Non-GUI** | Real API call — invoke the actual endpoint/process/function with real or realistic inputs | Response has a deterministic contract, error conditions are handleable, mocking boundary is clear |

**Decision rule:** if the AC's "When" step names a UI interaction (screen name, button, gesture), it is **GUI**. If the "When" step names a data operation, service call, or background event, it is **Non-GUI**. When ambiguous, classify as GUI (higher fidelity probe required).

### Probe Scope

- Each probe targets **one AC** — the scope of a probe matches the scope of the AT it gates.
- A probe is a **read-only or reversible** operation whenever possible. Side effects are acceptable only if the test environment is isolated.
- Probe failure before `[planned]` is **expected and informative** — it surfaces route problems at planning time, not mid-implementation.

---

## Flow Integration Point

The feasibility probe belongs at **Step 3 (`writing-plan-and-tests`)**, before any AT is committed as `[planned]`.

```
Step 1: defining-requirements   → ACs produced (Given/When/Then)
Step 2: extracting-user-stories → User Stories confirmed
Step 3: writing-plan-and-tests  ← PROBE GATE: run feasibility probe here
                                   • [planned] only after probe passes
                                   • escalate to User Gate if probe fails
Step 4: running-atdd-cycle      → AT [draft] → [green]
Step 5: reviewing-deliverables
Step 6: merging-and-deploying
```

### Invariant

An AT that skips the feasibility probe and is marked `[planned]` without evidence is **invalid**. `writing-plan-and-tests` must not produce a `[planned]` AT if the probe has not been executed or if the route is unresolvable.

The probe must be executed before confirming `[planned]` status. Any AT authored as `[planned]` carries the implicit assertion that a feasibility probe was run and passed.

---

## User Escalation Gate

When no feasible route is found — or when the only available route is unstable (flaky, environment-dependent, requires unresolvable dependencies) — **do not mark the AT `[planned]`**. Instead:

1. **Document the blocker** in the plan: which probe was attempted, what failure was observed, and what route would be needed.
2. **Escalate to the user** at the Step 3 gate (before any `[planned]` commitment):
   - Describe the route-absent or unstable condition.
   - Present alternatives: skip the AT (with documented rationale), redesign the AC to target a testable behavior, or defer the AT to a later phase when infrastructure is available.
3. **Await user judgment** before proceeding. The user decides whether to:
   - Accept the AT with a deferred-feasibility note,
   - Revise the AC to make it testable,
   - Or drop the AC from scope.

This gate prevents the ATDD loop from starting on an untestable AT, which would waste implementation effort and produce a permanently-red test.

---

## Tool Abstraction

The probe concept is abstract — atdd-kit does not couple to any specific automation tool. Concrete tool choices are **supplied by addons**.

### Probe Abstraction

| Probe type | Abstract operation | Concrete implementation (addon-supplied) |
|------------|-------------------|------------------------------------------|
| GUI — web | Drive a browser session, interact with UI elements, assert visible state | Playwright CLI (`playwright-cli` addon or skill) |
| GUI — iOS | Drive a simulator, tap UI elements, assert visible state | Xcode MCP / iOS Simulator MCP (`ios` addon) |
| Non-GUI — HTTP API | Send a real HTTP request, assert response contract | `curl` / `fetch` / project test runner |
| Non-GUI — function/unit | Call the function with real inputs, assert return value | project unit test runner (bats, jest, pytest, etc.) |

**Non-tight-coupling invariant:** `writing-plan-and-tests` and `running-atdd-cycle` invoke the **probe abstraction**. They do not depend on Playwright, Xcode, or any specific tool directly. The addon supplies the concrete executor. This keeps the core skills decoupled from platform-specific tooling.

When no addon is installed, the probe falls back to a documented manual step: the user performs the probe operation manually and provides a binary pass/fail confirmation before the AT is marked `[planned]`.

---

## Autopilot Alignment

In the `autopilot` loop, the feasibility probe executes during the **design phase** (between Gate ① requirements approval and Gate ② design approval).

```
Gate ①: Requirements approval
  ↓
Design phase: writing-plan-and-tests runs
  → Feasibility probes executed per AC
  → Results folded into the design document / plan
Gate ②: Design approval (設計承認)
  ↓
ATDD phase: running-atdd-cycle
```

The feasibility probe output **informs Gate ②**: if any AC has no feasible route, the design is not approved until the user makes a judgment call on it. The design approval is meaningful only when all ATs are grounded in verified, executable routes.

See [autopilot-design-gate.md](autopilot-design-gate.md) for the Gate ② presentation and approval protocol.

---

## External Research Basis

This section summarises the external evidence that grounds the probe-before-plan principle. Three domains are covered: agentic E2E test planning, browser/mobile UI agents, and API contract verification. Each entry cites a primary source.

### Domain 1 — Agentic E2E Test Planning

**Playwright Test Agents — live selector and assertion verification during generation**
Playwright v1.56 (2025) introduced a three-agent system (Planner → Generator → Healer). The Generator agent "verifies selectors and assertions live as it performs the scenarios" — it probes the running application before writing any test code, confirming that element references and assertions are reachable before the test file is committed. This is the closest publicly documented instance of a "probe before plan" pattern in a mainstream test framework.

- Source: <https://playwright.dev/docs/test-agents>
- Adoption signal: Playwright is the most widely used web automation framework (npm weekly downloads > 10 M as of 2025); v1.56 live-verification is now the default for agent-generated tests.
- Pitfall: The Generator still writes tests for the current application state; if the application changes after generation, the Healer must re-probe — route feasibility is not a one-time gate but must be re-confirmed on each significant change.

**Industry pattern — high failure rate on complex flows without pre-probed routes**
A recurring finding across agentic E2E case studies is that AI-generated tests achieve low failure rates on simple flows but degrade sharply on complex workflows involving multi-step navigation, authentication, and session state. The root cause identified consistently is that test routes were assumed feasible at authoring time without prior probing — authentication handling, navigation timing, and session instability cause systematic failures at runtime. The Playwright team's own post-release analysis of the three-agent system documents the Healer agent specifically as the countermeasure for route failures on complex flows, implicitly acknowledging that complex flow feasibility cannot be assumed without live re-probing.

- Source: <https://playwright.dev/docs/test-agents#healer-agent> — Playwright Healer Agent documentation (2025): describes how the Healer re-probes selectors and navigation paths that failed at runtime, with explicit motivation that complex flows fail when routes are not re-confirmed after application changes.
- Adoption signal: The Healer agent is enabled by default in Playwright's agent mode as of v1.56, indicating the maintainers treat route re-probing as a production necessity rather than an edge-case feature.
- Pitfall: Skipping route feasibility verification at planning time transfers the cost to runtime — complex flows that appear automatable fail in practice due to session state, timing, and environmental dependencies. Agentic testing is most effective as an exploratory/debugging layer complementing deterministic scripted tests, not as a replacement that assumes all routes are reachable.

### Domain 2 — Browser / Mobile UI Agents

**Playwright MCP — structured accessibility snapshots as the feasibility probe substrate**
Playwright MCP exposes Playwright as an MCP server where an LLM operates on structured accessibility snapshots (not screenshots) with deterministic element refs. This architecture decouples route probing from pixel-based recognition: the agent queries what is actionable on the page before committing to any interaction, enabling a feasibility assessment that feeds into maintainable CI tests. The verify-then-commit approach — confirm reachability via accessibility snapshot, then promote to a test — is the recommended pattern for agentic browser workflows.

- Source: <https://medium.com/@adnanmasood/playwright-and-playwright-mcp-a-field-guide-for-agentic-browser-automation-f11b9daa3627>
- Adoption signal: Playwright MCP is the reference implementation for Claude Code's browser automation and is used in atdd-kit's `playwright-cli` addon.
- Pitfall: Even with accessibility-snapshot probing, bot detection (third-party auth providers, payment processors, analytics SDKs) can block automation in production that succeeds in staging — environment-specific route infeasibility must be flagged during planning, not discovered mid-implementation. This pitfall is documented in multiple practitioner posts on agentic browser automation (see also the Playwright MCP field guide cited above).

### Domain 3 — API Exploration and Contract Verification

**OpenAPI contract-first verification — probe the API contract before writing integration tests**
Contract testing sits between unit testing and integration testing. It verifies that a consumer can create requests with specific data and correctly handle the provider's expected responses, using the OpenAPI spec as the feasibility proof before integration tests are authored. A practical pipeline: lint the spec with Spectral → generate and execute contract tests against staging (Portman / Pact) → only then commit integration test suites. When a provider changes a field type (e.g. integer → string), the consumer's contract test fails early — without this probe layer, breaking changes reach production.

- Source: <https://www.speakeasy.com/blog/contract-testing-with-openapi>
- Adoption signal: According to a 2024 Postman survey, API issues account for > 60 % of integration failures in microservices architectures — the majority preventable with upfront contract verification. PactFlow supports generating Pact tests from OpenAPI definitions as of 2026.
- Pitfall: Bi-directional contract testing requires both the consumer and provider to publish artifacts; teams that skip this mutual verification discover incompatibilities only during end-to-end test runs, replicating the same late-discovery problem this doctrine addresses for GUI tests.

---

## Cross-References

| Document | Relationship |
|----------|-------------|
| [atdd-guide.md](atdd-guide.md) | Double-Loop TDD (Outer Loop / Inner Loop) — the ATDD process that feasible ATs feed into |
| [test-mapping.md](test-mapping.md) | AC-to-test-layer mapping — informs which probe type (GUI vs Non-GUI) to select |
| [definition-of-ready.md](definition-of-ready.md) | DoR criteria R3 / R4 — AC completeness and no open questions; probe feasibility is the bridge between DoR and `[planned]` |
| [test-execution-policy.md](test-execution-policy.md) | Phase-based test execution scope — probes run at Step 3 (planning), not during each ATDD iteration |
