import SwiftUI

struct SpacialScalingContents: View {
    var body: some View {
        VStack {
            Text("test")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.blue)
    }
}

struct SpacialScalingContents_Previews: PreviewProvider {
    static var previews: some View {
        SpacialScalingContents()
    }
}
