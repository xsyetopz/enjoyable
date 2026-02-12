import SwiftUI

struct ErrorAlert: View {
  let error: String
  let message: String
  var retryAction: (() -> Void)?
  var dismissAction: (() -> Void)?

  @State private var _showDetails = false

  init(
    error: String,
    message: String,
    retryAction: (() -> Void)? = nil,
    dismissAction: (() -> Void)? = nil
  ) {
    self.error = error
    self.message = message
    self.retryAction = retryAction
    self.dismissAction = dismissAction
  }

  var body: some View {
    ZStack {
      Color.black.opacity(0.4)
        .ignoresSafeArea()
        .onTapGesture {
          dismissAction?()
        }

      VStack(spacing: 0) {
        _headerView
        _contentView
        _actionsView
      }
      .frame(width: 400)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color(nsColor: .windowBackgroundColor))
          .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
      )
    }
  }

  private var _headerView: some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 24, weight: .semibold))
        .foregroundColor(.orange)

      VStack(alignment: .leading, spacing: 2) {
        Text(error)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)
      }

      Spacer()

      Button(action: { dismissAction?() }) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 20))
          .foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(16)
    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
  }

  private var _contentView: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(message)
        .font(.system(size: 14))
        .foregroundColor(.primary)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)

      Button(action: { withAnimation { _showDetails.toggle() } }) {
        HStack(spacing: 6) {
          Image(systemName: _showDetails ? "chevron.up" : "chevron.down")
            .font(.system(size: 12, weight: .medium))
          Text(_showDetails ? "Hide Details" : "Show Details")
            .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(16)
  }

  private var _actionsView: some View {
    HStack(spacing: 12) {
      Spacer()

      Button(action: { dismissAction?() }) {
        Text("Dismiss")
          .font(.system(size: 14, weight: .medium))
      }
      .buttonStyle(.bordered)
      .controlSize(.regular)

      if retryAction != nil {
        Button(action: { retryAction?() }) {
          Text("Retry")
            .font(.system(size: 14, weight: .semibold))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
      }
    }
    .padding(16)
    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
  }
}

extension View {
  func errorAlert(
    isPresented: Binding<Bool>,
    error: Binding<String>,
    message: Binding<String>,
    retryAction: (() -> Void)? = nil
  ) -> some View {
    self.overlay(
      Group {
        if isPresented.wrappedValue {
          ErrorAlert(
            error: error.wrappedValue,
            message: message.wrappedValue,
            retryAction: retryAction,
            dismissAction: {
              isPresented.wrappedValue = false
            }
          )
        }
      }
    )
  }
}

struct ErrorAlert_Previews: PreviewProvider {
  static var previews: some View {
    ErrorAlert(
      error: "Connection Failed",
      message: "Unable to connect to the device. Please check your USB connection and try again.",
      retryAction: { print("Retry clicked") },
      dismissAction: { print("Dismiss clicked") }
    )
    .frame(width: 600, height: 400)
  }
}
