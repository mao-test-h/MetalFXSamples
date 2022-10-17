import SwiftUI

struct AAPLContents: View {
    @ObservedObject private var state: AAPLContentsState

    init(with state: AAPLContentsState) {
        self.state = state
    }

    var body: some View {
        GeometryReader { geometry in
            HStack() {
                Details(state: state)
                    .frame(width: geometry.size.width / 4.5, height: geometry.size.height / 2.4, alignment: .top)
                    .padding()
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topTrailing)
        }
    }
}

private struct Details: View {
    @ObservedObject var state: AAPLContentsState

    var body: some View {
        VStack {
            Picker("", selection: $state.selectedScalingModeIndex) {
                Text("Default").tag(0)
                Text("Spatial").tag(1)
                Text("Temporal").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())

            Spacer()

            Toggle(isOn: $state.resetHistorySwitch) {
                Text("Reset History")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Toggle(isOn: $state.animationSwitch) {
                Text("Animation")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Toggle(isOn: $state.proceduralTextureSwitch) {
                Text("Procedural Texture")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Spacer()
            SliderView(
                title: "Render Scale",
                label: $state.renderScaleLabel,
                value: $state.renderScaleSlider,
                range: 0.5...1.0)

            if !state.proceduralTextureSwitch {
                Spacer()
                SliderView(
                    title: "MIP Bias",
                    label: $state.mipBiasLabel,
                    value: $state.mipBiasSlider,
                    range: -2.0...0.0)
            } else {
                Spacer()
            }
        }
    }
}

private struct SliderView: View {
    let title: String
    @Binding var label: String
    @Binding var value: Float
    let range: ClosedRange<Float>

    var body: some View {
        VStack {
            Text("\(title): \(label)")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Slider(value: $value, in: range)
        }
    }
}


struct AAPLContents_Previews: PreviewProvider {
    static var previews: some View {
        AAPLContents(with: AAPLContentsState())
    }
}
