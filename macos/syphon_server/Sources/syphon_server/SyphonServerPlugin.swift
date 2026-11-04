import Cocoa
import FlutterMacOS
import Metal
import Syphon

public class SyphonServerPlugin: NSObject, FlutterPlugin {
  /// 必須與 Dart 端 `SyphonServerController.channelName` 相同。
  public static let channelName = "syphon_server"

  private var device: MTLDevice?
  private var commandQueue: MTLCommandQueue?
  private var server: SyphonMetalServer?
  private var texture: MTLTexture?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger
    )
    let instance = SyphonServerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      start(call: call, result: result)
    case "stop":
      stop(result: result)
    case "isRunning":
      result(server != nil)
    case "publish":
      publish(call: call, result: result)
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(call: FlutterMethodCall, result: @escaping FlutterResult) {
    if server != nil {
      result(nil)
      return
    }

    let args = call.arguments as? [String: Any]
    let name = args?["name"] as? String ?? "Syphon Server"

    guard let device = MTLCreateSystemDefaultDevice(),
          let commandQueue = device.makeCommandQueue() else {
      result(
        FlutterError(
          code: "NO_METAL",
          message: "Metal is not available on this Mac",
          details: nil
        )
      )
      return
    }

    let server = SyphonMetalServer(name: name, device: device, options: nil)

    self.device = device
    self.commandQueue = commandQueue
    self.server = server
    result(nil)
  }

  private func stop(result: @escaping FlutterResult) {
    server?.stop()
    server = nil
    texture = nil
    commandQueue = nil
    device = nil
    result(nil)
  }

  private func publish(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let server = server,
          let device = device,
          let commandQueue = commandQueue else {
      result(
        FlutterError(
          code: "NOT_RUNNING",
          message: "Syphon server is not running",
          details: nil
        )
      )
      return
    }

    guard let args = call.arguments as? [String: Any],
          let width = (args["width"] as? NSNumber)?.intValue,
          let height = (args["height"] as? NSNumber)?.intValue,
          let pixels = args["pixels"] as? FlutterStandardTypedData else {
      result(
        FlutterError(
          code: "BAD_ARGS",
          message: "Expected width, height, and pixels",
          details: nil
        )
      )
      return
    }

    guard width > 0, height > 0 else {
      result(
        FlutterError(
          code: "BAD_SIZE",
          message: "Width and height must be positive",
          details: nil
        )
      )
      return
    }

    let data = pixels.data
    let expectedBytes = width * height * 4
    guard data.count >= expectedBytes else {
      result(
        FlutterError(
          code: "BAD_SIZE",
          message: "Pixel buffer is smaller than width * height * 4",
          details: nil
        )
      )
      return
    }

    if texture == nil || texture?.width != width || texture?.height != height {
      let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm,
        width: width,
        height: height,
        mipmapped: false
      )
      descriptor.usage = [.shaderRead]
      guard let newTexture = device.makeTexture(descriptor: descriptor) else {
        result(
          FlutterError(
            code: "TEXTURE",
            message: "Failed to create MTLTexture",
            details: nil
          )
        )
        return
      }
      texture = newTexture
    }

    guard let texture = texture else {
      result(
        FlutterError(
          code: "TEXTURE",
          message: "MTLTexture is unavailable",
          details: nil
        )
      )
      return
    }

    data.withUnsafeBytes { rawBuffer in
      guard let baseAddress = rawBuffer.baseAddress else { return }
      texture.replace(
        region: MTLRegionMake2D(0, 0, width, height),
        mipmapLevel: 0,
        withBytes: baseAddress,
        bytesPerRow: width * 4
      )
    }

    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
      result(
        FlutterError(
          code: "COMMAND_BUFFER",
          message: "Failed to create MTLCommandBuffer",
          details: nil
        )
      )
      return
    }

    let region = NSRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
    // Flutter rawRgba 是 top-down；告知 Syphon 需要垂直翻轉。
    server.publishFrameTexture(
      texture,
      on: commandBuffer,
      imageRegion: region,
      flipped: true
    )
    commandBuffer.commit()
    result(nil)
  }
}
