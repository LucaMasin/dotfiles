# Datastar implementation patterns

Use this file when designing or reviewing interactions, not for exact SDK signatures.

## Pattern: server-rendered search

Frontend:

```html
<section data-signals:query="''">
  <label>
    Search
    <input
      data-bind:query
      data-on:input__debounce.300ms="@get('/search')"
    >
  </label>

  <div id="results"></div>
</section>
```

Backend:

1. Read the current `query` signal using the project's Datastar SDK/request helpers.
2. Validate/normalize it.
3. Query the backend data source.
4. Render the results HTML on the server.
5. Patch `<div id="results">...</div>`.

Do not send JSON search results merely to loop over them in ad hoc client JavaScript unless the application has a specific reason.

## Pattern: confirmed mutation

Frontend:

```html
<button
  data-indicator:_saving
  data-on:click="@post('/items/42/archive')"
  data-attr:disabled="$_saving"
>
  Archive
</button>
```

Backend:

1. Authenticate and authorize.
2. Perform the mutation.
3. Render the authoritative updated region.
4. Patch it back.
5. Return a useful error-state patch if the operation fails.

Prefer confirmed backend state over optimistic DOM manipulation.

## Pattern: form state

```html
<form data-on:submit="@post('/profile')">
  <label>
    Display name
    <input data-bind:profile.name required>
  </label>

  <button
    data-indicator:_saving
    data-attr:disabled="$_saving"
  >
    Save
  </button>
</form>
```

Use nested signals when they make the backend payload easier to decode.

If using `contentType: 'form'`, remember this changes the request semantics; consult the current action reference.

## Pattern: long-lived read stream / short-lived writes

Datastar's Tao presents a CQRS-style pattern for real-time applications:

```html
<div id="main" data-init="@get('/updates')">
  <button data-on:click="@post('/commands/do-something')">
    Do something
  </button>
</div>
```

Conceptually:

- one long-lived GET/SSE connection streams authoritative read-model/UI updates;
- short-lived command requests perform writes;
- backend publishes resulting state through the read stream.

Use this when real-time collaboration or live dashboards justify it. Do not force it onto simple CRUD pages.

## Pattern: poll only when polling is appropriate

```html
<div
  id="status"
  data-on-interval__duration.5s="@get('/status')"
>
  ...
</div>
```

If the server already knows when updates occur, a long-lived SSE stream may be cleaner than repeated polling.

## Pattern: infinite/lazy loading

Use `data-on-intersect` with `__once` for viewport-triggered loading.

The backend can append a new server-rendered fragment and replace/remove the sentinel as needed. Keep pagination/cursors authoritative on the backend where practical.

## Pattern: local-only UI state

Use `_`-prefixed signals for state that should not normally be sent:

```html
<div data-signals:_open="false">
  <button
    data-on:click="$_open = !$_open"
    data-attr:aria-expanded="$_open ? 'true' : 'false'"
  >
    Menu
  </button>

  <nav data-show="$_open">
    ...
  </nav>
</div>
```

This is appropriate client state: transient and purely presentational.

## Pattern: error rendering

Prefer returning an HTML fragment that contains the error in context:

```html
<form id="profile-form">
  ...
  <p role="alert">Display name is required.</p>
</form>
```

Then morph that region. This keeps validation logic on the backend and the rendered state coherent.

## Pattern: redirect

For ordinary user navigation, use `<a>`.

For a backend-triggered redirect after an action, use the mechanism documented by the current Datastar SDK/reference. Current SDKs commonly provide redirect helpers built on script execution.

Do not implement a client-side router just to avoid normal navigation.

## Pattern: browser-specific enhancement

When browser-only functionality is too complex for a short Datastar expression:

- isolate it in an external module or web component;
- pass values in;
- return values or dispatch custom events out;
- let Datastar react to those events/signals;
- do not create a second application state layer.

## Review smell: too many signals

A large object graph of server data in signals often indicates an SPA architecture recreated inside Datastar.

Ask whether the backend can instead render the HTML and morph the relevant region.

## Review smell: microscopic patches everywhere

A forest of selector-specific `inner`, `append`, and signal patches may create unnecessary coordination.

Ask whether one larger backend-rendered fragment can be morphed safely.

## Review smell: stale syntax

Datastar had meaningful syntax/API changes before 1.0 and continues to evolve.

When encountering examples from old repositories, blog posts, or AI output:

- identify the Datastar version;
- compare against current official docs;
- update syntax deliberately rather than mixing generations.
