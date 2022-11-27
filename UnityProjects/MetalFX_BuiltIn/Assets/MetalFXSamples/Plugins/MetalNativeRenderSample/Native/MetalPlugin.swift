import Foundation

enum EventId: Int32 {
    case extraDrawCall = 0
    case captureRT = 1
}

final class MetalPlugin {

    static func onRenderEvent(eventId: Int32) {
        switch EventId(rawValue: eventId)! {
        case .extraDrawCall:
            // TODO: DoExtraDrawCall();
            break
            // TODO: DoCaptureRT();
        case .captureRT:
            break
        }
    }

    // copy of render surface to a texture
    static func setRTCopyTargets(_ src: UnsafeRawPointer?, _ dst: UnsafeRawPointer?) {
        //g_CopySrcRB = src, g_CopyDstRB = dst;
    }
}