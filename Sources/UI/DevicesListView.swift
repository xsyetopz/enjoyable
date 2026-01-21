import SwiftUI

struct DeviceInfo: Identifiable {
  let id: String
  let name: String
  let connectionType: String
}

@MainActor
final class DevicesViewModel: ObservableObject {
  @Published var devices: [DeviceInfo] = []
}

struct DevicesListView: View {
  @StateObject private var viewModel = DevicesViewModel()
  var body: some View {
    VStack(spacing: 20) {
      header

      deviceList
    }
    .frame(
      minWidth: Constants.WindowDimensions.devicesListWidth,
      minHeight: Constants.WindowDimensions.devicesListHeight
    )
    .padding()
  }

  private var header: some View {
    HStack {
      Image(systemName: Constants.SFSymbols.gameControllerFill)
        .font(.system(size: 32))
        .foregroundColor(.accentColor)

      VStack(alignment: .leading, spacing: 4) {
        Text(Constants.AppMetadata.name)
          .font(.title)
          .fontWeight(.bold)

        Text("Game Controller Mapper")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
    }
  }

  private var deviceList: some View {
    Group {
      if viewModel.devices.isEmpty {
        emptyState
      } else {
        List(viewModel.devices, id: \.id) { device in
          DeviceRow(device: device)
        }
        .listStyle(.sidebar)
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: Constants.SFSymbols.gameController)
        .font(.system(size: 48))
        .foregroundColor(.secondary.opacity(0.5))

      Text(Constants.UIStrings.EmptyStates.noControllersConnected)
        .font(.title3)
        .foregroundColor(.secondary)

      Text(Constants.UIStrings.EmptyStates.connectUSBController)
        .font(.body)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct DeviceRow: View {
  let device: DeviceInfo

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: Constants.SFSymbols.gameControllerFill)
        .foregroundColor(.green)
        .frame(width: 32)

      VStack(alignment: .leading, spacing: 4) {
        Text(device.name)
          .font(.body)

        Text(device.connectionType)
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()

      Circle()
        .fill(Color.green)
        .frame(width: 8, height: 8)
    }
    .padding(.vertical, 8)
    .contentShape(Rectangle())
  }
}
