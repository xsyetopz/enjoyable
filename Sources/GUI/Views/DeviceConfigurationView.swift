import Core
import SwiftUI

struct DeviceConfigurationView: View {
  let device: GamepadDevice
  let onDismiss: () -> Void

  @State private var _deviceName: String
  @State private var _autoConnectEnabled: Bool = true
  @State private var _selectedProfile: String = "Default"

  init(device: GamepadDevice, onDismiss: @escaping () -> Void) {
    self.device = device
    self.onDismiss = onDismiss
    _deviceName = device.deviceName
    _autoConnectEnabled = true
    _selectedProfile = "Default"
  }

  var body: some View {
    VStack(spacing: 0) {
      _header

      Divider()

      _content
    }
    .background(Color(nsColor: .controlBackgroundColor))
    .cornerRadius(12)
    .frame(width: 400, height: 350)
    .padding(24)
  }

  private var _header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("Configure Device")
          .font(.title2.bold())

        Text(device.deviceName)
          .font(.subheadline)
          .foregroundColor(.secondary)
      }

      Spacer()

      Button(action: onDismiss) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 20))
          .foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(.bottom, 8)
  }

  private var _content: some View {
    VStack(spacing: 20) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Device Name")
          .font(.headline)

        TextField("Device Name", text: $_deviceName)
          .textFieldStyle(.roundedBorder)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Profile")
          .font(.headline)

        Picker("Profile", selection: $_selectedProfile) {
          Text("Default").tag("Default")
          Text("Gaming").tag("Gaming")
          Text("Productivity").tag("Productivity")
        }
        .pickerStyle(.menu)
        .textFieldStyle(.roundedBorder)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Connection")
          .font(.headline)

        Toggle("Auto-connect", isOn: $_autoConnectEnabled)
          .toggleStyle(.switch)
      }

      Spacer()

      HStack(spacing: 12) {
        Button(action: onDismiss) {
          Text("Cancel")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        Button(action: {
          onDismiss()
        }) {
          Text("Save")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(.top, 20)
  }
}

struct DeviceConfigurationView_Previews: PreviewProvider {
  static var previews: some View {
    DeviceConfigurationView(
      device: GamepadDevice(
        vendorID: 0x045E,
        productID: 0x02FF,
        deviceName: "Xbox Controller",
        connectionState: .connected
      ),
      onDismiss: {}
    )
    .frame(width: 400, height: 350)
  }
}