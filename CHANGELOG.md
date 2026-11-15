## 0.0.3

* Rename `onStatusListener` to `addStatusListener`.
* Recommend placing `SyphonServer` above routes (for example in `MaterialApp.builder`) so the offscreen view is not constrained by page layout.
* Update example and docs to match.

## 0.0.2

* Add `onStatusListener` / `removeStatusListener` to observe server start and stop.
* Notify `true` after a successful `start()`, and `false` on `stop()`.
* On `start()` failure, clean up resources, notify `false`, then rethrow.
* Add `isStarted` for the controller's current started state.

## 0.0.1

* Initial release.
* macOS Syphon Metal server support: `start`, `stop`, `isRunning`, and `publish`.
* Adds `SyphonServer` and `SyphonServerController` to capture an offscreen widget and publish frames to Syphon clients.
* `start()` mounts the offscreen view and automatically publishes the first frame.
* Example app demonstrates start, stop, and republishing after content updates.
