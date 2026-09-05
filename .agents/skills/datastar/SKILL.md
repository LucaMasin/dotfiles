---
name: datastar
description: Build, review, debug, or refactor web applications using Datastar, the hypermedia framework from Star Federation. Use when a task mentions Datastar, data-star.dev, data-* Datastar attributes, signals, @get/@post/@put/@patch/@delete, Server-Sent Events (SSE), PatchElements, PatchSignals, backend-driven UI, HTML-over-the-wire, or a Datastar backend SDK. Prefer current official Datastar patterns over SPA-style client state. Verify version-sensitive syntax against official docs when network access is available.
metadata:
  version: "1.0.0"
  reviewed-against-datastar: "v1.0.2"
  last-reviewed: "2026-09-05"
---

# Datastar

Use Datastar as a **backend-driven hypermedia framework**, not as a miniature SPA framework.

This skill was reviewed against the official Datastar documentation and the stable `v1.0.2` release on 2026-09-05. Datastar evolves: for exact attribute modifiers, action options, SDK method signatures, installation URLs, or Pro/free status, prefer the current official documentation at `https://data-star.dev/` and the official Star Federation repositories.

## Source-of-truth policy

When exact API details matter:

1. Inspect the project's existing Datastar version and backend SDK first.
2. If network access is available, verify version-sensitive details using official sources only:
   - `https://data-star.dev/guide/`
   - `https://data-star.dev/reference/`
   - `https://github.com/starfederation/datastar`
   - the official SDK repository linked from Datastar's SDK reference.
3. Match examples to the version actually used by the project.
4. Do not copy syntax from old blog posts, pre-1.0 examples, or third-party skills without checking it.
5. Do not invent backend SDK methods. If an SDK signature is uncertain, inspect the installed dependency or official SDK docs/source.

For a compact current reference, read `references/current-api.md`.
For implementation patterns and review heuristics, read `references/patterns.md`.

## Core architecture

Apply these defaults unless the existing codebase clearly requires otherwise.

- The backend is the source of truth for application/business state.
- Render HTML on the backend and patch DOM elements from backend responses.
- Use signals primarily for transient user interaction state and values that must be sent to the backend.
- Prefer morphing existing elements, usually by stable IDs, over client-side component reconstruction.
- Prefer Server-Sent Events (`text/event-stream`) when a response may emit multiple updates, stream progress, or remain long-lived.
- For ordinary navigation, use normal `<a>` elements and backend redirects.
- Use backend templates/components/partials to keep rendered HTML DRY.
- Avoid optimistic UI when correctness matters; show an indicator and render confirmed state from the backend.
- Preserve accessibility: semantic HTML first, keyboard behavior, labels, focus behavior, and appropriate ARIA.

## Standard workflow

### 1. Inspect before editing

Determine:

- Datastar frontend version.
- Whether the project self-hosts Datastar or loads it externally.
- Backend language/framework.
- Datastar SDK package and version, if any.
- Existing server-side templating approach.
- Existing conventions for IDs, routes, SSE endpoints, errors, CSRF, authentication, and tests.

Follow local conventions unless they conflict with current Datastar behavior or create a concrete bug.

### 2. Decide where state belongs

Put durable or authoritative state on the backend: database state, permissions, workflow state, computed business state, search results, validation results, collaboration state.

Use frontend signals for things such as:

- form/input values;
- open/closed UI state;
- selected local UI options;
- loading/indicator state;
- small derived presentation values.

Signals are globally accessible on the page. A signal beginning with `_` is local-only by default and is excluded from backend requests.

Avoid mirroring large backend models into signals merely to render them client-side.

### 3. Choose the response shape

Datastar backend actions can consume:

- `text/event-stream`: Datastar SSE events; preferred for multi-update or streaming interactions.
- `text/html`: patch returned top-level elements into the DOM.
- `application/json`: patch signals.
- `text/javascript`: execute returned JavaScript.

Prefer HTML patches for UI. Prefer signal patches when the data truly represents frontend reactive state.

For SSE, the fundamental event types are:

- `datastar-patch-elements`
- `datastar-patch-signals`

Use the project's official backend SDK when available instead of manually formatting SSE.

### 4. Build the frontend declaratively

Current core patterns include:

```html
<div data-signals:count="0">
  <button data-on:click="$count++">Local increment</button>
  <span data-text="$count"></span>
</div>
```

Backend request:

```html
<button data-on:click="@post('/items')">Save</button>
```

Two-way input binding:

```html
<input data-bind:query>
```

Loading indicator:

```html
<button
  data-indicator:_saving
  data-on:click="@post('/save')"
  data-attr:disabled="$_saving"
>
  Save
  <span data-show="$_saving">Saving…</span>
</button>
```

Use `$signalName` inside Datastar expressions.

### 5. Render confirmed server state

Prefer a backend response that renders the authoritative HTML:

```html
<section id="cart">
  <!-- backend-rendered current cart -->
</section>
```

With default outer morphing, top-level elements should have stable IDs that match elements already in the DOM.

Do not automatically reach for tiny selector-based patches. Datastar's morphing model supports sending larger coherent fragments ("fat morphs"), which often keeps the backend simpler.

### 6. Validate the interaction

Check:

- request method and route;
- signals actually sent to the backend;
- local `_` signals are not accidentally relied on server-side;
- correct response `Content-Type`;
- stable IDs for outer morphs;
- SSE stream remains valid and flushes correctly;
- loading indicators settle correctly;
- errors are surfaced to the user;
- keyboard and screen-reader behavior remains correct;
- backend independently validates all user-controlled data.

## Signals and requests

Backend actions are:

```text
@get(uri, options)
@post(uri, options)
@put(uri, options)
@patch(uri, options)
@delete(uri, options)
```

By default, backend requests include current signals except signal paths beginning with `_`.

- `GET`: signals are sent in the `datastar` query parameter.
- Other JSON-mode requests: signals are sent as JSON according to the current action semantics.
- `filterSignals` can restrict what is sent.
- `contentType: 'form'` uses form submission semantics instead of the normal signal JSON payload.
- For multipart upload, use a form with `enctype="multipart/form-data"` and the current documented form request pattern.

Do not assume a hidden/local signal is a security boundary. The client is untrusted.

## Morphing and IDs

Default `datastar-patch-elements` mode is `outer` and is the normal choice.

Current patch modes include:

```text
outer
inner
replace
prepend
append
before
after
remove
```

For normal outer morphs, use stable IDs:

```html
<div id="results">...</div>
```

Patch back another top-level element with the same ID.

Use a selector when a non-default mode or explicit target requires it.

Use `data-ignore-morph` only when an element genuinely must not be morphed.

## Expressions

Datastar expressions are JavaScript-like and can access:

- `$foo` — signal value
- `el` — the element holding the attribute
- `evt` — event object in `data-on`
- documented actions such as `@get(...)`

Keep expressions small. If logic becomes substantial:

1. move business logic to the backend;
2. for genuinely browser-specific behavior, use an encapsulated external script or web component;
3. pass data in and emit events out rather than creating a parallel client state architecture.

## Forms

Prefer semantic HTML and native validation.

For a Datastar-bound form-like interaction:

```html
<form data-on:submit="@post('/profile')">
  <label>
    Name
    <input data-bind:name required>
  </label>
  <button
    data-indicator:_saving
    data-attr:disabled="$_saving"
  >
    Save
  </button>
</form>
```

`data-on:submit` prevents the default form submission behavior. Do not add modifiers merely by habit; verify current modifier semantics when needed.

Backend validation remains mandatory even when native browser validation is present.

## Security

Always apply these rules:

- Treat every signal and request value as user-controlled.
- Never put secrets, authorization decisions, or trusted state in frontend signals.
- Escape user-controlled text correctly for the output context.
- Never interpolate untrusted content into a Datastar expression.
- Sanitize intentionally user-authored HTML before patching it.
- Perform authorization and validation on the backend.
- Follow the project's CSRF strategy; Datastar does not make CSRF concerns disappear.
- If using Content Security Policy, use Datastar's documented CSP mode/nonce approach when appropriate and verify it against the installed version.

## Pro features

Do not silently use Datastar Pro features in an open-source-only project.

As of the review date, the official attribute reference labels features including `data-persist`, `data-query-string`, `data-replace-url`, and several others as **Pro**.

Before introducing a Pro-only attribute:

1. determine whether the project has Datastar Pro;
2. verify the current Pro/free classification in the official reference;
3. otherwise implement the behavior using core web/Datastar primitives.

## Common failure modes

Avoid these patterns:

- SPA-style duplicated backend state stored in a large client signal tree.
- Fetching JSON and rebuilding ordinary application HTML on the client.
- Inventing custom JavaScript stores when backend rendering is sufficient.
- Excessive tiny patches when one coherent morph is simpler.
- Depending on stale pre-1.0 attribute syntax.
- Assuming every third-party Datastar example matches the installed version.
- Hardcoding SDK calls copied from another language/version.
- Treating signals as trusted because they originated from server-rendered HTML.
- Using Pro attributes without checking licensing/availability.
- Replacing normal links with scripted navigation without a concrete reason.
- Returning an SSE stream without correct headers/stream flushing in the backend framework.
- Creating an indicator after an initiating `data-init` attribute; attribute evaluation order matters.

## Review checklist

When reviewing Datastar code, ask:

1. Is authoritative state on the backend?
2. Are signals limited to appropriate frontend state/input?
3. Could server-rendered HTML replace client-side rendering logic?
4. Are IDs stable for morphing?
5. Is the backend response type appropriate?
6. Is SSE used where multiple/streamed updates are useful?
7. Are request/action options valid for the installed version?
8. Is the backend SDK API verified rather than guessed?
9. Are user inputs escaped, validated, and authorized?
10. Are Pro-only features intentional?
11. Does the interaction remain accessible?
12. Is the solution simpler than the SPA equivalent?

## When debugging

Inspect in this order:

1. Browser console for Datastar expression/runtime errors.
2. Network request method, URL, request payload, and `Datastar-Request` header.
3. Response `Content-Type`.
4. For SSE: raw event stream, event separation, event names, selectors/modes, and emitted HTML.
5. DOM IDs and morph targets.
6. Signal values with the Datastar Inspector or `data-json-signals` during development.
7. Backend logs and SDK errors.
8. Version mismatch between frontend bundle, docs being followed, and backend SDK.

If syntax appears valid but behavior differs from memory, assume version drift first and verify the official docs/release notes.
