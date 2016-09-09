## 1.5.2

- Further clarity in error messaging.
- Freeze the cache list after start.

## 1.5.1

- Add back in alerting if you attempt to load a cache before the refresher has run.
- Improve documentation on error handling.

## 1.5.0

- Support for multiple cache stores, like: `Caddy[:foo][:baz]` instead of just `Caddy[:baz]`
- Additional tests.
- Additional documentation for the new feature.

## 1.0.1

- More tests.
- Stop caching nil values returned after refreshers timeout or throw an exception (fall back on the last cached value).
- Additional documentation.

## 1.0.0

- First draft of tests.
- More clean & refactoring.
- Style guide.
- Documentation.

## 0.0.2

- Code cleanup, refactoring.

## 0.0.1

- First release.
