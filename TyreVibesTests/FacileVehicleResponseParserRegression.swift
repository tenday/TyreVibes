import Foundation

private enum RegressionFailure: Error, CustomStringConvertible {
    case expected(String, Any, Any)

    var description: String {
        switch self {
        case let .expected(label, expected, actual):
            return "\(label): expected \(expected), got \(actual)"
        }
    }
}

private func expect<T: Equatable>(_ actual: T, _ expected: T, _ label: String) throws {
    guard actual == expected else {
        throw RegressionFailure.expected(label, expected, actual)
    }
}

@main
private enum FacileVehicleResponseParserRegression {
    static func main() throws {
        try parsesCompleteValidatePlateResponse()
        try rejectsResponseWithoutVehicle()
        try buildsInvisibleBrowserFlow()
        print("Facile vehicle response parser regression tests passed")
    }

    private static func parsesCompleteValidatePlateResponse() throws {
        let json = #"""
        {
          "right": {
            "vehicle": {
              "type": "A",
              "registration": { "date": "2018-04-19T00:00:00.000Z" },
              "car": {
                "make": { "name": "FIAT" },
                "model": { "name": "500X" },
                "equipment": {
                  "name": "1.6 MultiJet 120 CV Lounge",
                  "value": 13900,
                  "powerKw": 88,
                  "powerHp": 120,
                  "displacement": 1598,
                  "fiscalPower": 17,
                  "fuelType": "diesel"
                }
              }
            }
          }
        }
        """#

        let vehicle = try FacileVehicleResponseParser.parse(data: Data(json.utf8))
        try expect(vehicle.make, "FIAT", "make")
        try expect(vehicle.model, "500X", "model")
        try expect(vehicle.modelDetails, "1.6 MultiJet 120 CV Lounge", "model details")
        try expect(vehicle.registrationDate, "2018-04-19", "registration date")
        try expect(vehicle.powerKW, "88", "power kW")
        try expect(vehicle.powerCV, "120", "power CV")
        try expect(vehicle.displacementCC, "1598", "displacement")
        try expect(vehicle.fuelType, "Diesel", "fuel")
    }

    private static func rejectsResponseWithoutVehicle() throws {
        do {
            _ = try FacileVehicleResponseParser.parse(data: Data(#"{"right":{}}"#.utf8))
            throw RegressionFailure.expected("missing vehicle", "error", "success")
        } catch FacileVehicleResponseParserError.missingVehicle {
            return
        }
    }

    private static func buildsInvisibleBrowserFlow() throws {
        let script = try FacileWebFlow.interceptionScript(plate: "FN841WA")
        try expect(script.contains("FN841WA"), true, "serialized plate")
        try expect(script.contains("validate-plate"), true, "plate response interception")
        try expect(script.contains("vehicle-equipments"), true, "equipment response interception")
        try expect(script.contains("facileVehicleNative"), true, "native message bridge")
        try expect(script.contains("AA123BB"), true, "plate input selector")
        try expect(script.contains("allianz"), false, "no Allianz token flow")
        try expect(script.contains("targascan.it"), false, "no Targa Scan backend")
    }
}
