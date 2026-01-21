@preconcurrency import Dispatch
import Foundation

protocol ControllerDeviceProtocol: AnyObject, Sendable {
  var id: DeviceId { get }
  var info: ControllerInfo { get }
  var isActive: Bool { get async }
  var onInputEvent: ((InputEvent) -> Void)? { get set }

  func start() async throws
  func stop() async throws
  func setRumble(left: Float, right: Float) async throws
}

final class ControllerDevice: ControllerDeviceProtocol, Sendable {
  private actor StateActor {
    var isActive = false
    var readingTask: Task<Void, Never>?
    var keepaliveTask: Task<Void, Never>?

    func setActive(_ value: Bool) { isActive = value }
    func setReadingTask(_ task: Task<Void, Never>?) { readingTask = task }
    func setKeepaliveTask(_ task: Task<Void, Never>?) { keepaliveTask = task }
  }

  let id: DeviceId
  let info: ControllerInfo
  private let transport: TransportProtocol
  private let protocolHandler: ProtocolHandlerProtocol
  private let config: ControllerConfig

  private let stateActor = StateActor()

  private final class CallbackStorage: @unchecked Sendable {
    var onInputEvent: ((InputEvent) -> Void)?
  }
  private let callbackStorage = CallbackStorage()

  init(
    candidate: DeviceCandidate,
    transport: TransportProtocol,
    protocolHandler: ProtocolHandlerProtocol,
    config: ControllerConfig
  ) {
    self.id = candidate.id
    self.info = ControllerInfo(
      id: candidate.id,
      name: candidate.name,
      vendorId: candidate.vendorId,
      productId: candidate.productId,
      protocolType: candidate.protocolType,
      connectionType: .usb,
      capabilities: ControllerCapabilities(
        buttonCount: 14,
        analogStickCount: 2,
        triggerCount: 2,
        hasTouchpad: false,
        hasGyro: false,
        hasRumble: config.features?.vibration ?? false,
        hasRGB: config.features?.rgb ?? false
      )
    )
    self.transport = transport
    self.protocolHandler = protocolHandler
    self.config = config
  }

  var isActive: Bool {
    get async { await stateActor.isActive }
  }

  var onInputEvent: ((InputEvent) -> Void)? {
    get { callbackStorage.onInputEvent }
    set { callbackStorage.onInputEvent = newValue }
  }

  func start() async throws {
    let wasActive = await stateActor.isActive
    guard !wasActive else { return }

    NSLog("[ControllerDevice] Starting controller: \(config.name)...")
    await stateActor.setActive(true)

    if config.protocolType == .gip, let initSequence = config.initSequence {
      NSLog("[ControllerDevice] Running GIP init sequence (\(initSequence.count) steps)...")
      try await runInitSequence(initSequence)
    }

    let task = Task<Void, Never> { [weak self] in
      await self?.readLoop()
    }
    await stateActor.setReadingTask(task)

    if config.protocolType == .gip {
      let keepaliveTask = Task<Void, Never> { [weak self] in
        await self?.keepaliveLoop()
      }
      await stateActor.setKeepaliveTask(keepaliveTask)
    }
  }

  func stop() async throws {
    await stateActor.setActive(false)

    let task = await stateActor.readingTask
    task?.cancel()
    await stateActor.setReadingTask(nil)

    let keepaliveTask = await stateActor.keepaliveTask
    keepaliveTask?.cancel()
    await stateActor.setKeepaliveTask(nil)
  }

  func setRumble(left: Float, right: Float) async throws {
    guard config.features?.vibration == true else {
      throw ControllerError.featureNotSupported(feature: "Rumble")
    }

    guard config.protocolType == .gip else {
      return
    }

    var command = [UInt8](repeating: 0, count: 36)
    command[0] = Constants.ReportType.gipRumble
    command[1] = UInt8(left * 255.0)
    command[2] = UInt8(right * 255.0)

    try await transport.write(
      deviceId: id,
      endpoint: config.endpoints?.out ?? Constants.ProtocolConfig.gipEndpointOut,
      data: Data(command)
    )
  }

  private func runInitSequence(_ steps: [InitializationStep]) async throws {
    for step in steps {
      switch step.type {
      case .write:
        guard let data = step.data else { continue }
        try await transport.write(
          deviceId: id,
          endpoint: config.endpoints?.out ?? Constants.ProtocolConfig.gipEndpointOut,
          data: Data(data)
        )

      case .read:
        let _ = try await transport.read(
          deviceId: id,
          endpoint: config.endpoints?.in ?? Constants.ProtocolConfig.gipEndpointIn,
          length: config.reportSize
        )

      case .delay:
        if let delayMs = step.delayMs {
          try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
        }

      case .waitForAck:
        if let expected = step.expectedResponse {
          let response = try await transport.read(
            deviceId: id,
            endpoint: config.endpoints?.in ?? Constants.ProtocolConfig.gipEndpointIn,
            length: expected.count
          )

          guard response.count >= expected.count else {
            throw ProtocolError.invalidResponse
          }

          for (i, byte) in expected.enumerated() {
            guard response[i] == byte else {
              throw ProtocolError.invalidResponse
            }
          }
        }
      }
    }
  }

  private func keepaliveLoop() async {
    let keepaliveCommand: [UInt8] = [0x05, 0x20, 0x00, 0x01, 0x00]

    while await stateActor.isActive && !Task.isCancelled {
      do {
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        try await transport.write(
          deviceId: id,
          endpoint: config.endpoints?.out ?? Constants.ProtocolConfig.gipEndpointOut,
          data: Data(keepaliveCommand)
        )
      } catch {
        if await !stateActor.isActive {
          break
        }
      }
    }
  }

  private func readLoop() async {
    while await stateActor.isActive && !Task.isCancelled {
      do {
        let data = try await transport.read(
          deviceId: id,
          endpoint: config.endpoints?.in ?? Constants.ProtocolConfig.gipEndpointIn,
          length: config.reportSize
        )

        let event = try protocolHandler.parse(data)

        let callback = callbackStorage.onInputEvent
        if let callback = callback {
          await MainActor.run { callback(event) }
        }
      } catch {
        if await stateActor.isActive {
          continue
        }
      }
    }
  }
}
