import SwiftUI

struct MainView: View {
    var body: some View {
        VStack {
            Text("test")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.blue)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
