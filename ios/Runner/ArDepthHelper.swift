import ARKit
import UIKit

class ArDepthHelper {
    func isSupported() -> Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    func measureDepth() -> Double? {
        let config = ARWorldTrackingConfiguration()
        config.frameSemantics = [.sceneDepth]
        let session = ARSession()
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        defer { session.pause() }

        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            guard let frame = session.currentFrame,
                  let depthMap = frame.sceneDepth?.depthMap else {
                Thread.sleep(forTimeInterval: 0.1)
                continue
            }
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

            let w = CVPixelBufferGetWidth(depthMap)
            let h = CVPixelBufferGetHeight(depthMap)
            guard let base = CVPixelBufferGetBaseAddress(depthMap) else {
                Thread.sleep(forTimeInterval: 0.1)
                continue
            }
            let cx = w / 2
            let cy = h / 2
            let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
            let offset = cy * bytesPerRow + cx * MemoryLayout<Float32>.size
            let pixel = base.load(fromByteOffset: offset, as: Float32.self)
            if pixel > 0.01 && pixel < 10.0 {
                return Double(pixel)
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return nil
    }
}
