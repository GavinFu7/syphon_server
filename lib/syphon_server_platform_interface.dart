import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'syphon_server_method_channel.dart';

abstract class SyphonServerPlatform extends PlatformInterface {
  /// Constructs a SyphonServerPlatform.
  SyphonServerPlatform() : super(token: _token);

  static final Object _token = Object();

  static SyphonServerPlatform _instance = MethodChannelSyphonServer();

  /// The default instance of [SyphonServerPlatform] to use.
  ///
  /// Defaults to [MethodChannelSyphonServer].
  static SyphonServerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SyphonServerPlatform] when
  /// they register themselves.
  static set instance(SyphonServerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
