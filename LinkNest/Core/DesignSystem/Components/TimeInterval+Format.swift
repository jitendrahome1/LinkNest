//
//  TimeInterval+Format.swift
//  mm:ss / h:mm:ss formatting shared by the video and PDF viewers.
//

import Foundation

extension Double {
    /// "4:32" or "1:04:32" for hour-plus durations. Negative/NaN clamp to "0:00".
    var mmss: String {
        guard isFinite, self > 0 else { return "0:00" }
        let total = Int(self.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}
