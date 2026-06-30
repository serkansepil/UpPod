import XCTest
@testable import uppod

final class ExerciseLibraryTests: XCTestCase {
    func testDefaultExerciseTargets() {
        XCTAssertEqual(ExerciseLibrary.sideTilt.targetDeg, 30, accuracy: 1e-9)
        XCTAssertEqual(ExerciseLibrary.rotation.targetDeg, 45, accuracy: 1e-9)
    }

    func testHeadlessExerciseTargetsMatchDefaults() {
        let sideTilt = ExerciseLibrary.testPlan.first { $0.id == "roll" }
        let rotation = ExerciseLibrary.testPlan.first { $0.id == "yaw" }

        XCTAssertEqual(sideTilt?.targetDeg, ExerciseLibrary.sideTilt.targetDeg)
        XCTAssertEqual(rotation?.targetDeg, ExerciseLibrary.rotation.targetDeg)
    }
}
