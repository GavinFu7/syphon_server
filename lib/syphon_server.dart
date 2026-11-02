
import 'syphon_server_platform_interface.dart';

class SyphonServer {
  Future<String?> getPlatformVersion() {
    return SyphonServerPlatform.instance.getPlatformVersion();
  }
}
