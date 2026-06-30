import Foundation

/// Which sensor axis it's detected from.
enum ExerciseAxis {
    case flexion   // pitch — looking up/down (drift-free)
    case roll      // tilting sideways (drift-free)
    case yaw       // turning the head (relative baseline, drifty)
    case chinTuck  // NOT MEASURABLE via orientation — guided timer + motion gate
}

/// The exercise's goal.
enum ExerciseGoal {
    /// Reach |signal| ≥ target + return to neutral = 1 rep; if bidirectional, both directions count.
    case reps(target: Double, perDirection: Int, bidirectional: Bool)
    /// Guided hold: hold for `seconds` seconds, `count` times (chin tuck).
    case guidedHold(seconds: Double, count: Int)
}

struct Exercise: Identifiable {
    let id: String
    let name: String
    let instruction: String
    let axis: ExerciseAxis
    let goal: ExerciseGoal
    let neutralBand: Double   // degrees — |signal| below this = returned to neutral
    let hysteresis: Double    // degrees
    let restSeconds: Double

    var totalReps: Int {
        switch goal {
        case let .reps(_, per, bidir): return bidir ? per * 2 : per
        case let .guidedHold(_, count): return count
        }
    }

    var targetDeg: Double {
        switch goal {
        case let .reps(target, _, _): return target
        case .guidedHold: return 0
        }
    }
}

enum SessionPhase: Equatable { case ready, active, resting, done }

/// Default recipe for the 4 exercises (tunable).
enum ExerciseLibrary {
    static let flexionExtension = Exercise(
        id: "flexion", name: "Yukarı aşağı",
        instruction: "Başını yavaşça göğsüne indir, sonra yukarı kaldır.",
        axis: .flexion,
        goal: .reps(target: 20, perDirection: 5, bidirectional: true),
        neutralBand: 8, hysteresis: 4, restSeconds: 10)

    static let sideTilt = Exercise(
        id: "roll", name: "Yan esneme",
        instruction: "Sol ve sağ omzuna doğru yavaşça eğil.",
        axis: .roll,
        goal: .reps(target: 30, perDirection: 5, bidirectional: true),
        neutralBand: 6, hysteresis: 3, restSeconds: 10)

    static let chinTuck = Exercise(
        id: "chintuck", name: "Çene geriye",
        instruction: "Çeneni düz şekilde geriye al ve tut.",
        axis: .chinTuck,
        goal: .guidedHold(seconds: 5, count: 5),
        neutralBand: 0, hysteresis: 0, restSeconds: 8)

    static let rotation = Exercise(
        id: "yaw", name: "Sağa sola bak",
        instruction: "Omuzunun üzerinden bakacak kadar yavaşça dön.",
        axis: .yaw,
        goal: .reps(target: 45, perDirection: 5, bidirectional: true),
        neutralBand: 10, hysteresis: 5, restSeconds: 10)

    static let all: [Exercise] = [flexionExtension, sideTilt, chinTuck, rotation]

    /// Headless test (UPPOD_EX_AUTOSTART): low reps / short holds / short rest.
    static let testPlan: [Exercise] = [
        Exercise(id: "flexion", name: "Look up & down", instruction: "test",
                 axis: .flexion, goal: .reps(target: 20, perDirection: 1, bidirectional: true),
                 neutralBand: 8, hysteresis: 4, restSeconds: 2),
        Exercise(id: "roll", name: "Side tilt", instruction: "test",
                 axis: .roll, goal: .reps(target: 30, perDirection: 1, bidirectional: true),
                 neutralBand: 6, hysteresis: 3, restSeconds: 2),
        Exercise(id: "chintuck", name: "Chin tuck", instruction: "test",
                 axis: .chinTuck, goal: .guidedHold(seconds: 2, count: 1),
                 neutralBand: 0, hysteresis: 0, restSeconds: 2),
        Exercise(id: "yaw", name: "Look left & right", instruction: "test",
                 axis: .yaw, goal: .reps(target: 45, perDirection: 1, bidirectional: true),
                 neutralBand: 10, hysteresis: 5, restSeconds: 2),
    ]
}
