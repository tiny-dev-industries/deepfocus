import Foundation

struct Preset: Identifiable, Equatable {
    let id: UUID
    let name: String
    let durationSeconds: Int

    var durationFormatted: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes) min"
    }

    static let builtIns: [Preset] = [
        Preset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Pomodoro",
            durationSeconds: 25 * 60
        ),
        Preset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Long Focus",
            durationSeconds: 50 * 60
        ),
        Preset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "Deep Work",
            durationSeconds: 90 * 60
        ),
    ]
}
