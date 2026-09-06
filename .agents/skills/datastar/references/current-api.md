# Datastar current API reference

Reviewed: 2026-09-05  
Frontend release used for review: `v1.0.2`

This file is a compact snapshot, not a replacement for `https://data-star.dev/reference/`.

## Installation

The official Datastar repository currently identifies `v1.0.2` as the stable release.

For a new project, copy the current installation snippet from the official Getting Started page or official repository rather than relying on an old unversioned CDN example. Prefer self-hosting when appropriate for the application.

## Core attributes

The current free/core attribute reference includes:

- `data-attr`
- `data-bind`
- `data-class`
- `data-computed`
- `data-effect`
- `data-ignore`
- `data-ignore-morph`
- `data-indicator`
- `data-init`
- `data-json-signals`
- `data-on`
- `data-on-intersect`
- `data-on-interval`
- `data-on-signal-patch`
- `data-on-signal-patch-filter`
- `data-preserve-attr`
- `data-ref`
- `data-show`
- `data-signals`
- `data-style`
- `data-text`

Always check the live reference before claiming this list is exhaustive in a future version.

## Frequently used syntax

```html
<div data-signals:foo="1"></div>
<div data-signals="{foo: {bar: 1}}"></div>

<input data-bind:foo>
<input data-bind="foo">

<div data-computed:total="$price * $quantity"></div>

<div data-text="$message"></div>
<div data-show="$isVisible"></div>
<div data-class:active="$isActive"></div>
<button data-attr:disabled="$loading"></button>

<button data-on:click="@post('/endpoint')"></button>

<div
  data-indicator:_loading
  data-init="@get('/endpoint')"
></div>
```

Signal-definition keys are normally camel-cased by Datastar. For example:

```html
<div data-signals:my-signal="1" data-text="$mySignal"></div>
```

Signal names cannot begin with or contain double underscore `__` because it is used as a modifier delimiter.

## `data-bind`

`data-bind` creates a signal if necessary and performs two-way binding for compatible inputs/components.

```html
<input data-bind:query>
<select data-bind:choice>...</select>
```

Predefining a signal preserves its type during binding:

```html
<div data-signals:count="0">
  <input data-bind:count>
</div>
```

For custom elements, check the current `__prop` and `__event` modifiers instead of assuming native binding behavior.

## `data-on`

`data-on` can listen to normal and custom events.

```html
<button data-on:click="$open = !$open"></button>
<div data-on:my-event="$value = evt.detail"></div>
```

Current modifiers include concepts such as:

- `__once`
- `__passive`
- `__capture`
- `__case`
- `__delay`
- `__debounce`
- `__throttle`
- `__viewtransition`
- `__window`
- `__document`
- `__outside`
- `__prevent`
- `__stop`

Verify exact modifier/tag syntax in the current attribute reference when using anything nontrivial.

`data-on:submit` prevents default submission automatically.

## Backend actions

Current backend actions:

```text
@get()
@post()
@put()
@patch()
@delete()
```

Common options currently include:

- `contentType`
- `filterSignals`
- `selector`
- `headers`
- `openWhenHidden`
- `payload`
- retry controls
- `requestCancellation`

Do not memorize all option spellings across releases. Verify them when editing request behavior.

Default signal transmission:

- excludes paths beginning with `_`;
- `GET` sends the signals in a `datastar` query parameter;
- non-GET JSON-mode requests send signals in the request payload according to the action semantics.

## Response handling

Backend actions currently handle:

| Content type | Effect |
|---|---|
| `text/event-stream` | Process Datastar SSE events |
| `text/html` | Patch elements |
| `application/json` | Patch signals |
| `text/javascript` | Execute JavaScript |

The Tao of Datastar recommends SSE responses as the general-purpose choice because one stream can emit zero to many updates.

## SSE events

Current fundamental SSE event types:

### Patch elements

```text
event: datastar-patch-elements
data: elements <div id="foo">Hello</div>

```

Options/data lines can include:

- `selector`
- `mode`
- `namespace`
- `useViewTransition`
- `viewTransitionSelector`
- `elements`

Patch modes:

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

Default mode: `outer`.

### Patch signals

```text
event: datastar-patch-signals
data: signals {foo: 1, bar: 2}

```

Signals can be removed by patching them to `null`.

Use the backend SDK to generate these events when available.

## Pro attributes

At the review date, the official reference places these under Datastar Pro:

- `data-animate`
- `data-custom-validity`
- `data-match-media`
- `data-on-raf`
- `data-on-resize`
- `data-persist`
- `data-query-string`
- `data-replace-url`
- `data-scroll-into-view`
- `data-view-transition`

This classification may change. Check the live reference before using one.

## Official references

- https://data-star.dev/guide/getting_started
- https://data-star.dev/guide/reactive_signals
- https://data-star.dev/guide/datastar_expressions
- https://data-star.dev/guide/backend_requests
- https://data-star.dev/guide/the_tao_of_datastar
- https://data-star.dev/reference/attributes
- https://data-star.dev/reference/actions
- https://data-star.dev/reference/sse_events
- https://data-star.dev/reference/sdks
- https://data-star.dev/reference/security
- https://github.com/starfederation/datastar
