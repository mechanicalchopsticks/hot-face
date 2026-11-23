import CryptoKit
import Foundation

extension EquipmentDescription {
    package static func genericOptions(in gymID: UUID) -> [Self] {
        Kind.allCases.map { kind in
            let name: String
            switch kind {
            case .dumbbell: name = "Dumbbells"
            case .barbell: name = "Barbell with plates"
            case .fixedBar: name = "Fixed-weight bars"
            case .selectorizedMachine: name = "Selectorized machine"
            case .plateLoadedMachine: name = "Plate-loaded machine"
            case .bodyweight: name = "Bodyweight"
            case .band: name = "Resistance bands"
            case .cardio: name = "Cardio"
            }
            let usesPlates = kind == .barbell || kind == .plateLoadedMachine
            var option = Self(
                id: genericID(in: gymID, kind: kind), name: name, kind: kind, unit: usesPlates ? .lb : .kg)
            if kind == .barbell { option.baseWeight = 45 }
            return option
        }
    }

    private static func genericID(in gymID: UUID, kind: Kind) -> UUID {
        // Stable per-gym references let old catalogs offer the built-ins without rewriting stored equipment.
        let key = "HotFace.genericEquipment.\(gymID.uuidString).\(kind.rawValue)"
        var bytes = Array(SHA256.hash(data: Data(key.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x80
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
            ))
    }
}
