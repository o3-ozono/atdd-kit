> **Loaded by:** web addon (Playwright), ios addon (XCUITest), discord addon guidance; injected before Claude generates UI/E2E test code

# UI/E2E Test Foundations

Platform-independent principles for UI/E2E testing, shared by every addon (`addons/web`, `addons/ios`,
`addons/discord`). This is the single source for these principles — addon docs reference this file and
add platform-specific detail; they do not restate the principles below (#371, CS-1).

## 4 Principles

### Principle 1 — Waiting

- **[hard rule]** Never use fixed-time waits (`sleep`, `wait(N ms)`, `page.waitForTimeout()`). Wait for a
  condition instead: Playwright auto-waiting or Cypress retry-ability.
- Non-DOM state (API completion, store updates, WebSocket messages) has no visible/enabled/stable signal —
  write an explicit wait condition for it instead of assuming the DOM state implies it.
- Assertions must be retry-able (web-first assertions / Cypress `should` chains), not one-shot checks
  against a snapshot taken before the UI settles.
- Source: Playwright Best Practices — Auto-waiting[^1] / Cypress Best Practices — Flake Avoidance[^2].

### Principle 2 — Locators

- **Priority order**: role + accessible name → label / placeholder / text → `data-testid`.
- **[hard rule]** Forbidden: CSS `id` / `class` / tag selectors / `nth-child` / XPath / auto-generated
  class names / layout-dependent selectors. These couple tests to implementation detail and break on
  refactors that don't change user-visible behavior.
- **School divide**: Testing Library's school grabs elements the way a user perceives them — `role` is the
  top priority and `data-testid` is a last resort, because tests should resemble how users interact with
  the app[^3]. Cypress Best Practices' school instead recommends a dedicated `data-cy` attribute as the
  top priority, treating it as a stable contract decoupled from both DOM structure and CSS/JS
  changes[^4]. **Trade-off**: Testing Library's approach favors tests that fail when the app becomes less
  accessible (accessibility as a forcing function) but is more verbose to target ambiguous elements;
  Cypress's `data-cy` approach is simpler to target precisely but does not double as an accessibility
  check and requires markup changes to add the attribute. This doc does not recommend one school over the
  other — each addon declares which school it follows.
- **[hard rule]** Mixing schools within one addon is forbidden. An addon must pick one locator school
  (Testing Library's role/label-first, or Cypress's `data-cy`-first) and use it consistently; mixing
  `role` and `data-cy` selectors within the same addon's test suite produces an inconsistent, harder to
  maintain codebase.
- Source: Testing Library Queries — Priority[^3] / Cypress Best Practices — Selecting Elements[^4].

### Principle 3 — Structure

- Per-screen knowledge (URLs, selectors, navigation actions) is encapsulated in a Page Object (or Screen
  Object).
- **[hard rule]** Page Objects hold no assertions. Assertions belong in the test, not the Page Object —
  this keeps the Page Object a pure interaction layer and the test the single place that states the
  pass/fail criteria[^5][^6]. Selenium's Page Object Model[^6] states the same discipline.
- For state-heavy UIs, a Page Object may not scale cleanly — the Screenplay Pattern (Serenity/JS)[^7] or a
  State Object (van Deursen)[^8] are the documented next step when interactions need to be composed
  around actor/state abstractions rather than one object per screen.
- **[hard rule]** Every test is independent and does not depend on execution order or on state left behind
  by another test.
- Source: Fowler PageObject[^5] / Selenium POM[^6] / Serenity/JS Screenplay Pattern[^7] / van Deursen State
  Object[^8].

### Principle 4 — Granularity

- Follow the Test Pyramid (Fowler[^5] / Vocke[^9]) or the Testing Trophy (Kent C. Dodds[^10]): E2E tests
  are few and cover only critical paths.
- E2E verifies a full flow a real user performs end to end. Individual component behavior is verified by
  Unit and Integration tests, not by adding more E2E cases.
- Source: Fowler TestPyramid[^5] / Vocke Practical Test Pyramid[^9] / Kent C. Dodds Testing Trophy[^10].

### Supplementary Principle `[独自]`

- `[独自]` One test asserts only the observable outcome of its one Acceptance Criterion. Both
  over-assertion (asserting unrelated state in the same test) and under-assertion (not asserting the
  actual AC outcome) are forbidden — this keeps each test's failure diagnostic and its intent traceable to
  one AC.

## LLM Rule Set

Imperative do/don't rules for Claude to apply before generating UI/E2E test code. Each rule traces to one
of the 4 principles above.

- **[hard rule]** (Principle 1) Do not use `page.waitForTimeout()` / `sleep(N)` / fixed-duration waits.
  Use `expect(locator).toBeVisible()` or an equivalent auto-waiting / retry-able assertion.
- **[hard rule]** (Principle 1) When waiting on non-DOM state (API call, store, WebSocket), write an
  explicit wait for that condition. Do not assume a DOM-visible signal implies the non-DOM state is ready.
- **[hard rule]** (Principle 2) Do not select elements by CSS `id`, `class`, tag, `nth-child`, XPath, or
  auto-generated class names. Use role/accessible-name, label/placeholder/text, or `data-testid`
  (Testing Library school) — or `data-cy` exclusively (Cypress school) — per the addon's declared school.
- **[hard rule]** (Principle 2) Do not mix locator schools (role/`data-testid` and `data-cy`) within one
  addon's test suite. Use the single school that addon has declared.
- **[hard rule]** (Principle 3) Do not put assertions inside a Page Object / Screen Object. Put assertions
  in the test; keep the Page Object as an interaction-only layer.
- **[hard rule]** (Principle 3) Do not write a test that depends on another test's leftover state or on
  execution order. Make every test independently runnable.
- **[hard rule]** (Principle 4) Do not add an E2E test for behavior a Unit/Integration test already
  verifies. Reserve E2E for critical-path, full-flow coverage only.

## Footnotes

[^1]: Playwright — [Best Practices: Auto-waiting](https://playwright.dev/docs/best-practices)
[^2]: Cypress — [Best Practices: Flake Avoidance / Web Servers](https://docs.cypress.io/guides/references/best-practices)
[^3]: Testing Library — [Guiding Principles / Priority](https://testing-library.com/docs/queries/about/#priority)
[^4]: Cypress — [Best Practices: Selecting Elements](https://docs.cypress.io/guides/references/best-practices#Selecting-Elements)
[^5]: Martin Fowler — [PageObject](https://martinfowler.com/bliki/PageObject.html) / [TestPyramid](https://martinfowler.com/bliki/TestPyramid.html)
[^6]: Selenium — [Page Object Models](https://www.selenium.dev/documentation/test_practices/encouraged/page_object_models/)
[^7]: Serenity/JS — [The Screenplay Pattern](https://serenity-js.org/handbook/design/screenplay-pattern/)
[^8]: Arie van Deursen — [Testing at the Digital Wholesale Bank: Enter the State Object](https://avandeursen.com/2019/07/31/state-objects-refactoring-page-objects/)
[^9]: Ham Vocke — [The Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)
[^10]: Kent C. Dodds — [The Testing Trophy and Testing Classifications](https://kentcdodds.com/blog/the-testing-trophy-and-testing-classifications)
