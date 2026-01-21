import SwiftUI

struct ContentView: View {
  @StateObject private var devicesViewModel = DevicesViewModel()

  var body: some View {
    DevicesListView()
  }
}
