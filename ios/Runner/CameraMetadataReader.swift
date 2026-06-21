import AVFoundation
import Flutter

class CameraMetadataReader {
    private var device: AVCaptureDevice?
    private var latestAperture: Double = -1
    private var latestExposureTime: Int64 = -1
    private var latestIso: Int = -1
    private var isRunning = false
    private var sessionType = "none"
    private var observers = [NSKeyValueObservation]()

    func start(cameraId: String) -> Bool {
        guard let d = AVCaptureDevice(uniqueID: cameraId) ?? AVCaptureDevice.default(for: .video) else {
            return false
        }
        device = d
        isRunning = true
        sessionType = "PREVIEW"
        readCurrentValues()
        observeChanges()
        return true
    }

    func getLatest() -> [String: Any] {
        readCurrentValues()
        return [
            "aperture": latestAperture,
            "exposureTime": latestExposureTime,
            "iso": latestIso,
            "focusDistance": -1.0,
            "isRunning": isRunning,
            "sessionType": sessionType,
        ]
    }

    func getStaticAperture(cameraId: String) -> Double {
        guard let d = AVCaptureDevice(uniqueID: cameraId) ?? AVCaptureDevice.default(for: .video) else {
            return -1
        }
        return Double(d.lensAperture)
    }

    func measureDistance(cameraId: String) -> Double {
        guard let d = AVCaptureDevice(uniqueID: cameraId) ?? AVCaptureDevice.default(for: .video) else {
            return -1
        }
        do {
            try d.lockForConfiguration()
            d.focusMode = .autoFocus
            d.unlockForConfiguration()
            let deadline = Date().addingTimeInterval(3)
            while Date() < deadline {
                if !d.isAdjustingFocus {
                    return Double(d.lensPosition)
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
        } catch {}
        return -1
    }

    func cleanup() {
        observers.removeAll()
        device = nil
        isRunning = false
        sessionType = "none"
    }

    private func readCurrentValues() {
        guard let d = device else { return }
        latestAperture = Double(d.lensAperture)
        latestExposureTime = Int64(d.exposureDuration.seconds * 1_000_000_000)
        latestIso = Int(d.iso)
    }

    private func observeChanges() {
        guard let d = device else { return }
        observers.removeAll()
        observers.append(d.observe(\.lensAperture) { [weak self] _, _ in
            self?.readCurrentValues()
        })
        observers.append(d.observe(\.exposureDuration) { [weak self] _, _ in
            self?.readCurrentValues()
        })
        observers.append(d.observe(\.iso) { [weak self] _, _ in
            self?.readCurrentValues()
        })
    }
}
