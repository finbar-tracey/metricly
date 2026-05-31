import XCTest
@testable import tracker

final class PlateCalculatorEngineTests: XCTestCase {

    func testPlatesPerSideGreedy() {
        let plates = PlateCalculatorEngine.platesPerSide(targetKg: 100, barWeightKg: 20)
        XCTAssertEqual(plates.reduce(0, +) * 2 + 20, 100, accuracy: 0.01)
    }

    func testActualWeightKg() {
        let perSide = [25.0, 10.0]
        XCTAssertEqual(PlateCalculatorEngine.actualWeightKg(barWeightKg: 20, platesPerSide: perSide), 90, accuracy: 0.01)
    }
}
