import Foundation
import CoreMotion

/// A single sample entering the pipeline. The full gravity vector is carried for the absolute (drift-free) angle.
struct MotionSample {
    let t: TimeInterval        // monotonic (systemUptime)
    let pitch: Double          // radians, attitude (for direction/roll separation)
    let roll: Double
    let yaw: Double            // does NOT enter the score; debug only
    let gx, gy, gz: Double     // gravity unit vector (head frame) — ABSOLUTE tilt
    let accelMag: Double       // |userAcceleration| (g)
    let rotMag: Double         // |rotationRate| (rad/s)
}

/// Motion permission / hardware state, surfaced to the UI so a denied prompt isn't a silent dead end.
enum MotionAuthorization {
    case notDetermined   // prompt not answered yet (or never shown)
    case authorized      // samples flowing
    case denied          // user said No → needs System Settings
    case restricted      // blocked by policy (MDM/parental) → needs System Settings
    case unavailable     // this Mac/headphones can't provide head motion at all
}

/// Motion source abstraction — isolates real AirPods or mock behind it.
protocol MotionProviding: AnyObject {
    var onSample: ((MotionSample) -> Void)? { get set }
    var onConnection: ((Bool) -> Void)? { get set }
    var onAuthorization: ((MotionAuthorization) -> Void)? { get set }
    func start()
    func stop()
}

/// Real AirPods source — CMHeadphoneMotionManager validated in Phase 0a.
final class HeadphoneMotionService: NSObject, MotionProviding, CMHeadphoneMotionManagerDelegate {
    var onSample: ((MotionSample) -> Void)?
    var onConnection: ((Bool) -> Void)?
    var onAuthorization: ((MotionAuthorization) -> Void)?

    private let manager = CMHeadphoneMotionManager()
    private let queue = OperationQueue()
    private var sawSample = false   // first valid sample ⇒ authorized (clears a stale denied state)

    override init() {
        super.init()
        queue.name = "uppod.motion"
        queue.maxConcurrentOperationCount = 1
        manager.delegate = self
    }

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    private static func map(_ s: CMAuthorizationStatus) -> MotionAuthorization {
        switch s {
        case .authorized:    return .authorized
        case .denied:        return .denied
        case .restricted:    return .restricted
        case .notDetermined: return .notDetermined
        @unknown default:    return .notDetermined
        }
    }

    func start() {
        guard manager.isDeviceMotionAvailable else {
            onConnection?(false)
            onAuthorization?(.unavailable)
            return
        }
        sawSample = false
        // Report the current status up front (.notDetermined before the first prompt is answered).
        onAuthorization?(Self.map(CMHeadphoneMotionManager.authorizationStatus()))
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let self else { return }
            if error != nil {
                // Denied/restricted/other → surface the resolved status instead of failing silently.
                self.onAuthorization?(Self.map(CMHeadphoneMotionManager.authorizationStatus()))
                return
            }
            guard let m = motion else { return }
            if !self.sawSample { self.sawSample = true; self.onAuthorization?(.authorized) }
            let g = m.gravity, a = m.userAcceleration, r = m.rotationRate
            self.onSample?(MotionSample(
                t: ProcessInfo.processInfo.systemUptime,
                pitch: m.attitude.pitch, roll: m.attitude.roll, yaw: m.attitude.yaw,
                gx: g.x, gy: g.y, gz: g.z,
                accelMag: (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot(),
                rotMag: (r.x * r.x + r.y * r.y + r.z * r.z).squareRoot()))
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) { onConnection?(true) }
    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) { onConnection?(false) }
}

/// Test/demo without AirPods: produces a pitch+roll oscillation and gravity CONSISTENT with it. UPPOD_MOCK=1.
final class MockMotionService: MotionProviding {
    var onSample: ((MotionSample) -> Void)?
    var onConnection: ((Bool) -> Void)?
    var onAuthorization: ((MotionAuthorization) -> Void)?
    private var timer: Timer?
    private var phase = 0.0
    // Exercise test mode: also sweep yaw, widen roll, occasional rotMag peak (chin tuck gate)
    private let exMode = RuntimeFlags.enabled("UPPOD_MOCK_EXERCISE")

    func start() {
        onAuthorization?(.authorized)
        onConnection?(true)
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.phase += 0.02
            let phi = sin(self.phase * 0.25) * 0.6                       // pitch ~±34°
            let rho = sin(self.phase * 0.17) * (self.exMode ? 0.60 : 0.15)  // roll ±34° (ex) / ±8.6°
            let yaw = self.exMode ? sin(self.phase * 0.3) * 0.9 : 0.0    // yaw ±51° (ex) / 0
            let rot = self.exMode && abs(sin(self.phase * 0.7)) > 0.985 ? 0.5 : 0.02  // occasional peak
            // rotate the up vector by pitch(x axis) then roll(y axis) → consistent gravity
            let gx = -cos(phi) * sin(rho)
            let gy = sin(phi)
            let gz = -cos(phi) * cos(rho)
            self.onSample?(MotionSample(
                t: ProcessInfo.processInfo.systemUptime,
                pitch: phi, roll: rho, yaw: yaw,
                gx: gx, gy: gy, gz: gz,
                accelMag: 0.01, rotMag: rot))
        }
    }

    func stop() { timer?.invalidate(); timer = nil; onConnection?(false) }
}
