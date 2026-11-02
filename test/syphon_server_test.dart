import 'package:flutter_test/flutter_test.dart';
import 'package:syphon_server/syphon_server.dart';
import 'package:syphon_server/syphon_server_platform_interface.dart';
import 'package:syphon_server/syphon_server_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSyphonServerPlatform
    with MockPlatformInterfaceMixin
    implements SyphonServerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final SyphonServerPlatform initialPlatform = SyphonServerPlatform.instance;

  test('$MethodChannelSyphonServer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSyphonServer>());
  });

  test('getPlatformVersion', () async {
    SyphonServer syphonServerPlugin = SyphonServer();
    MockSyphonServerPlatform fakePlatform = MockSyphonServerPlatform();
    SyphonServerPlatform.instance = fakePlatform;

    expect(await syphonServerPlugin.getPlatformVersion(), '42');
  });
}
