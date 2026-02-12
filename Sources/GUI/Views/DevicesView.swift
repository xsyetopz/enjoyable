import Core
import SwiftUI

struct DevicesView: View {
  @EnvironmentObject var viewModel: DevicesViewModel

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        _headerView

        if viewModel.devices.isEmpty {
          _emptyStateView
        } else {
          _devicesListView
        }
      }
      .padding(24)
    }
  }

  private var _headerView: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("Connected Devices")
          .font(.title2.bold())

        Text(
          "\(viewModel.devices.count) device\(viewModel.devices.count == 1 ? "" : "s")"
        )
        .font(.subheadline)
        .foregroundColor(.secondary)
      }

      Spacer()

      Button(action: {
        Task {
          await viewModel.refreshDevices()
        }
      }) {
        Image(systemName: "arrow.clockwise")
          .font(.body)
      }
      .buttonStyle(.borderless)
      .help("Refresh devices")
    }
    .padding(.bottom, 8)
  }

  private var _emptyStateView: some View {
    VStack(spacing: 16) {
      Image(systemName: "gamecontroller")
        .font(.system(size: 56))
        .foregroundColor(.secondary)

      Text("No Devices Connected")
        .font(.title3.bold())

      Text("Connect a gamepad to get started")
        .font(.body)
        .foregroundColor(.secondary)

      Button(action: {
        Task {
          await viewModel.refreshDevices()
        }
      }) {
        Label("Scan for Devices", systemImage: "magnifyingglass")
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    }
    .padding(40)
    .frame(maxWidth: .infinity)
    .background(Color(nsColor: .controlBackgroundColor))
    .cornerRadius(12)
  }

  private var _devicesListView: some View {
    LazyVStack(spacing: 12) {
      ForEach(viewModel.devices) { device in
        DeviceRowView(
          device: device,
          isSelected: viewModel.selectedDevice?.id == device.id,
          onConfigure: {
            Task { @MainActor in
              viewModel.configureDevice(device)
            }
          }
        )
        .onTapGesture {
          viewModel.selectDevice(device)
        }
      }
    }
  }
}

struct DeviceRowView: View {
  let device: GamepadDevice
  let isSelected: Bool
  let onConfigure: () -> Void

  var body: some View {
    HStack(spacing: 16) {
      _deviceIcon

      VStack(alignment: .leading, spacing: 4) {
        Text(device.deviceName)
          .font(.headline)

        HStack(spacing: 8) {
          _connectionStatusIndicator
          Text(_deviceIDText)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      _deviceTypeBadge

      Button(action: onConfigure) {
        Label("Configure", systemImage: "gearshape")
          .font(.subheadline)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(LayoutConstants.Padding.standard)
    .background(
      isSelected ? ThemeConstants.Accent.opacity08 : ThemeConstants.Colors.controlBackground
    )
    .cornerRadius(LayoutConstants.CornerRadius.standard)
    .overlay(
      RoundedRectangle(cornerRadius: LayoutConstants.CornerRadius.standard)
        .stroke(
          isSelected ? Color.accentColor : ThemeConstants.Selection.grayStroke,
          lineWidth: isSelected
            ? ThemeConstants.Selection.strokeWidth : ThemeConstants.Selection.strokeWidthSmall
        )
    )
  }

  private var _deviceIcon: some View {
    ZStack {
      Circle()
        .fill(ThemeConstants.Accent.opacity12)
        .frame(width: 48, height: 48)

      Image(systemName: "gamecontroller.fill")
        .font(.title3)
        .foregroundColor(.accentColor)
    }
  }

  private var _connectionStatusIndicator: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(_connectionStateColor)
        .frame(width: 8, height: 8)

      Text(_connectionStateText)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(.secondary)
    }
  }

  private var _connectionStateColor: Color {
    switch device.connectionState {
    case .connected: return .green
    case .connecting: return .yellow
    case .disconnected: return .gray
    case .error: return .red
    }
  }

  private var _connectionStateText: String {
    switch device.connectionState {
    case .connected: return "Connected"
    case .connecting: return "Connecting"
    case .disconnected: return "Disconnected"
    case .error: return "Error"
    }
  }

  private var _deviceIDText: String {
    String(format: "0x%04X:0x%04X", device.vendorID, device.productID)
  }

  private var _deviceTypeBadge: some View {
    HStack(spacing: 4) {
      if device.isXbox {
        Image(systemName: "xbox.logo")
          .foregroundColor(.green)
      } else if device.isPlayStation {
        Image(systemName: "playstation.logo")
          .foregroundColor(.blue)
      } else if device.isNintendo {
        Image(systemName: "nintendo.switch")
          .foregroundColor(.red)
      }

      Text(_deviceTypeText)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(.secondary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(ThemeConstants.Secondary.opacity10)
    .cornerRadius(8)
  }

  private var _deviceTypeText: String {
    if device.isXbox {
      return "Xbox"
    } else if device.isPlayStation {
      return "PlayStation"
    } else if device.isNintendo {
      return "Nintendo"
    }
    return "Generic"
  }
}
