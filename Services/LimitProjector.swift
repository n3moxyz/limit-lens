import Foundation

struct LimitProjection: Equatable {
    enum Outcome: Equatable {
        case onPace
        case overPace(deadTime: TimeInterval)
        case underPace(unusedFraction: Double, unusedTime: TimeInterval)
    }

    var paceRatio: Double
    var projectedUsedPercent: Double
    var outcome: Outcome
}

enum LimitProjector {
    static let onPaceBand: Double = 5

    static func project(window: LimitWindow, now: Date = Date()) -> LimitProjection? {
        guard let usedPercent = window.usedPercent, usedPercent > 0 else {
            return nil
        }

        guard let durationMinutes = window.durationMinutes, durationMinutes > 0 else {
            return nil
        }

        guard let resetsAt = window.resetsAt else {
            return nil
        }

        let secondsUntilReset = resetsAt.timeIntervalSince(now)
        guard secondsUntilReset > 0 else {
            return nil
        }

        let windowDuration = TimeInterval(durationMinutes * 60)
        let elapsed = windowDuration - secondsUntilReset
        guard elapsed > 0 else {
            return nil
        }

        let expectedUsedPercent = (elapsed / windowDuration) * 100
        guard expectedUsedPercent > 0 else {
            return nil
        }

        let paceRatio = usedPercent / expectedUsedPercent
        let burnRatePerSecond = usedPercent / elapsed
        let projectedUsedPercent = usedPercent + burnRatePerSecond * secondsUntilReset

        let outcome: LimitProjection.Outcome
        if abs(projectedUsedPercent - 100) < onPaceBand {
            outcome = .onPace
        } else if projectedUsedPercent >= 100 {
            let secondsUntilFull = max(0, (100 - usedPercent) / burnRatePerSecond)
            let deadTime = max(0, secondsUntilReset - secondsUntilFull)
            outcome = .overPace(deadTime: deadTime)
        } else {
            let unusedPercent = max(0, 100 - projectedUsedPercent)
            let unusedFraction = unusedPercent / 100
            let unusedTime = unusedPercent / burnRatePerSecond
            outcome = .underPace(unusedFraction: unusedFraction, unusedTime: unusedTime)
        }

        return LimitProjection(
            paceRatio: paceRatio,
            projectedUsedPercent: projectedUsedPercent,
            outcome: outcome
        )
    }
}
