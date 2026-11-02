import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'syphon_server_platform_interface.dart';

/// An implementation of [SyphonServerPlatform] that uses method channels.
class MethodChannelSyphonServer extends SyphonServerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('syphon_server');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
