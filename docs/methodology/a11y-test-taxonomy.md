> **Loaded by:** (none yet — foundational reference)

# a11y Test Taxonomy

This document defines how atdd-kit divides accessibility (a11y) testing **by verification method**. It is a platform-independent (web / iOS / Android) methodology foundation; each setup skill references this taxonomy when defining its own platform-specific implementation steps.

## 3-Way Split of Test Methods

a11y testing splits into three categories by verification method. This is **not** an official WCAG or JIS classification — it is an **[independent / original]** atdd-kit taxonomy.

| Category | Coverage | Granularity | Execution Timing |
|----------|----------|-------------|-------------------|
| **Automated / Static** (自動・静的) | Rule-based inspection of DOM / markup structure — contrast ratio, missing `alt` attributes, malformed ARIA syntax, and other mechanically-judgeable violations | Per component | unit tests, CI gate |
| **Automated / Interactive** (自動・操作) | Scripted simulation of keyboard navigation, focus order, and screen-reader traversal, with post-action state inspection | Per screen / flow | E2E |
| **Manual** (手動) | Judgments that cannot be reduced to mechanical rules — information-architecture validity, semantic naturalness of reading order, overall usability of the interaction | Per screen / feature | design review |

The three categories are designed not to overlap: Automated/Static and Automated/Interactive are separated by "mechanically judgeable or not," and Manual covers whatever neither automated category can determine.

## Automated Green ≠ a11y Achieved

All automated tests (Automated/Static + Automated/Interactive) passing **does not mean a11y work is complete**.

- Playwright's official documentation states that automated accessibility testing can only catch a subset of WCAG issues that are mechanically verifiable. Reference: [Playwright — Accessibility testing](https://playwright.dev/docs/accessibility-testing)
- Deque's (maker of axe-core) analysis found automated testing alone identifies about 57% of issues (prior industry estimates put this at 20-30%), and even combined with semi-automated testing (Intelligent Guided Tests) coverage reaches only about 80%. In other words, roughly 20% of issues remain undetectable by automated (+ semi-automated) testing and require manual review. Reference: [Deque — Automated Testing Identifies 57% of Digital Accessibility Issues](https://www.deque.com/blog/automated-testing-study-identifies-57-percent-of-digital-accessibility-issues/), [Deque — The Automated Accessibility Coverage Report](https://www.deque.com/automated-accessibility-coverage-report/)

Because automated tools detect only a **subset** of WCAG violations, green automated tests alone cannot be treated as "a11y achieved" — manual review is required before that claim holds. On this basis, atdd-kit treats **manual review as a mandatory design review gate**: design review is not a substitute for automated tests, but an independent step that covers what automated tests cannot structurally detect.

## Applicability Criteria

- **WCAG 2.2 AA** is the primary candidate applicability criterion. WCAG 2.2 is the latest W3C recommendation as of this writing, encompassing all success criteria through 2.1 while adding new ones, giving it the widest coverage for new documents/implementations.
- **JIS X 8341-3:2016** is frequently referenced as Japan's official public-sector standard, but its content is equivalent to **WCAG 2.0**. It differs from WCAG 2.2 by the success criteria added since 2.0. When referencing JIS X 8341-3:2016 as a baseline, be mindful of this version gap (WCAG 2.0 vs. 2.2) — the success criteria added in 2.2 do not exist on the JIS side.

## Separate Axis (テスト手段 vs. SC triage)

The **test-method split** defined in this document (Automated/Static / Automated/Interactive / Manual) and **WCAG SC (Success Criterion) level triage** (deciding which success criteria to target, and to what level — A / AA / AAA) are **independent design-judgment axes**.

- The test-method split decides "in which step, and how, do we verify."
- SC-level triage decides "what, and to what extent, must be satisfied."

These two axes must not be confused. For example, "verify all WCAG AA criteria via Automated/Static testing" is a category error: what Automated/Static testing can verify is bounded by the constraints of the method (this document's subject), while which SC to target is decided by triage (a separate axis, out of scope for this Issue). Defining the SC-level triage policy itself is out of scope here and belongs to a separate Issue.
