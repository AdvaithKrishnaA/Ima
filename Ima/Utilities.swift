// Shared utilities for Ima
import Foundation
import SwiftUI

// MARK: - URL Utilities
extension URL {
    /// Creates a valid URL from a string, adding https:// if needed
    static func validURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // If it already has a scheme, try to create URL directly
        if trimmed.contains("://") {
            return URL(string: trimmed)
        }
        
        // If it looks like a domain (contains a dot), add https://
        if trimmed.contains(".") && !trimmed.hasPrefix("http") {
            return URL(string: "https://\(trimmed)")
        }
        
        // Try as-is first
        if let url = URL(string: trimmed) {
            return url
        }
        
        // Last resort: add https://
        return URL(string: "https://\(trimmed)")
    }
    
    /// Validates if a string matches a proper URL format
    static func isValidURLFormat(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        // Check for basic URL patterns
        let urlPattern = #"^(https?://)?[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*(/.*)?$"#
        
        do {
            let regex = try NSRegularExpression(pattern: urlPattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            return regex.firstMatch(in: trimmed, options: [], range: range) != nil
        } catch {
            // Fallback to simple check
            return trimmed.contains(".") && trimmed.count > 3
        }
    }
}

// MARK: - Color Extensions
extension Color {
    static let imaPurple = Color(hex: "CB1B45")
    
    /// Initialize Color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Time Formatting
/// Formats time interval for countdown display (e.g., "2d 14h", "3h 45m")
func formatRemaining(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    guard s > 0 else { return "0s" }
    
    let d = s / 86_400
    let h = (s % 86_400) / 3_600
    let m = (s % 3_600) / 60
    let sec = s % 60
    
    if d > 0 { return String(format: "%dd %02dh", d, h) }
    if h > 0 { return String(format: "%dh %02dm", h, m) }
    if m > 0 { return String(format: "%dm %02ds", m, sec) }
    return String(format: "%ds", sec)
}

/// Formats time interval for compact display in circular indicators
func formatCompactTime(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    guard s > 0 else { return "0s" }
    
    let d = s / 86_400
    let h = (s % 86_400) / 3_600
    let m = (s % 3_600) / 60
    
    if d > 0 {
        return h > 0 ? "\(d)d \(h)h" : "\(d)d"
    }
    if h > 0 {
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
    if m > 0 {
        return "\(m)m"
    }
    return "\(s)s"
}
