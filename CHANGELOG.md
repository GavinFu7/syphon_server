## 0.0.1

* macOS Syphon Metal server support: `start`, `stop`, `isRunning`, and `publish`.
* Adds `SyphonServer` and `SyphonServerController` to capture an offscreen widget and publish frames to Syphon clients.
* `start()` mounts the offscreen view and automatically publishes the first frame.
* Example app demonstrates start, stop, and republishing after content updates.
