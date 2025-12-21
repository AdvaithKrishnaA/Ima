import Foundation
import SwiftUI
import Combine

// MARK: - Task Model
struct TaskItem: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var createdAt: Date
    var expiresAt: Date
    var location: String?
    var link: URL?
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, duration: TimeInterval, location: String? = nil, link: URL? = nil) {
        self.id = id
        self.title = title
        let now = Date()
        self.createdAt = now
        self.expiresAt = now.addingTimeInterval(duration)
        self.location = location
        self.link = link
        self.isCompleted = false
    }
}

// MARK: - Task Item Extensions
extension TaskItem {
    var timeRemaining: TimeInterval { 
        max(0, expiresAt.timeIntervalSinceNow) 
    }
    
    var isExpired: Bool { 
        Date() >= expiresAt 
    }
    
    var urgencyLevel: UrgencyLevel {
        let remaining = timeRemaining
        if remaining <= 0 { return .expired }
        if remaining <= 3600 { return .critical }  // 1 hour
        if remaining <= 21600 { return .urgent }   // 6 hours
        return .normal
    }
}

enum UrgencyLevel {
    case normal, urgent, critical, expired
}

// MARK: - Settings Model
enum ResetFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case specificDays = "specificDays"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .specificDays: return "Specific Day(s) of Week"
        }
    }
}

@MainActor
final class ImaSettings: ObservableObject {
    static let hardUpperBound: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    @Published var maxAllowedDays: Int = 3 // 1-5 days
    @Published var defaultDurationHours: Int = 1 // Default task duration in hours
    @Published var resetFrequency: ResetFrequency = .daily
    @Published var resetTime: Date = Calendar.current.date(from: DateComponents(hour: 0, minute: 0)) ?? Date()
    @Published var selectedWeekdays: Set<Int> = [1] // Sunday = 1, Monday = 2, etc.
    @Published var timeZone: TimeZone = TimeZone.current
    
    var maxAllowedDuration: TimeInterval {
        TimeInterval(maxAllowedDays * 24 * 60 * 60)
    }
    
    var defaultDuration: TimeInterval {
        TimeInterval(defaultDurationHours * 3600)
    }
    
    init() {
        loadSettings()
    }
}

// MARK: - Settings Persistence
extension ImaSettings {
    func saveSettings() {
        UserDefaults.standard.set(maxAllowedDays, forKey: "ImaMaxDays")
        UserDefaults.standard.set(defaultDurationHours, forKey: "ImaDefaultDurationHours")
        UserDefaults.standard.set(resetFrequency.rawValue, forKey: "ImaResetFrequency")
        
        if let resetTimeData = try? JSONEncoder().encode(resetTime) {
            UserDefaults.standard.set(resetTimeData, forKey: "ImaResetTime")
        }
        
        if let weekdaysData = try? JSONEncoder().encode(selectedWeekdays) {
            UserDefaults.standard.set(weekdaysData, forKey: "ImaSelectedWeekdays")
        }
        
        UserDefaults.standard.set(timeZone.identifier, forKey: "ImaTimeZone")
    }
    
    private func loadSettings() {
        maxAllowedDays = UserDefaults.standard.object(forKey: "ImaMaxDays") as? Int ?? 3
        maxAllowedDays = max(1, min(maxAllowedDays, 5)) // Ensure 1-5 range
        
        defaultDurationHours = UserDefaults.standard.object(forKey: "ImaDefaultDurationHours") as? Int ?? 1
        defaultDurationHours = max(1, min(defaultDurationHours, 24)) // Ensure 1-24 range
        
        if let resetFreqString = UserDefaults.standard.string(forKey: "ImaResetFrequency"),
           let resetFreq = ResetFrequency(rawValue: resetFreqString) {
            resetFrequency = resetFreq
        }
        
        if let resetTimeData = UserDefaults.standard.data(forKey: "ImaResetTime"),
           let savedResetTime = try? JSONDecoder().decode(Date.self, from: resetTimeData) {
            resetTime = savedResetTime
        }
        
        if let weekdaysData = UserDefaults.standard.data(forKey: "ImaSelectedWeekdays"),
           let savedWeekdays = try? JSONDecoder().decode(Set<Int>.self, from: weekdaysData) {
            selectedWeekdays = savedWeekdays
        }
        
        if let timeZoneId = UserDefaults.standard.string(forKey: "ImaTimeZone"),
           let savedTimeZone = TimeZone(identifier: timeZoneId) {
            timeZone = savedTimeZone
        }
    }
}

// MARK: - Task Store
@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var completedCount: Int = 0
    @Published private(set) var expiredCount: Int = 0
    
    private var timer: Timer?
    private var resetTimer: Timer?
    private var fireIntensity: Double = 0.7
    private var settings: ImaSettings?
    
    init() {
        loadTasks()
        startTimer()
    }
    
    deinit {
        timer?.invalidate()
        resetTimer?.invalidate()
    }
}

// MARK: - Task Store Public Interface
extension TaskStore {
    func setSettings(_ settings: ImaSettings) {
        self.settings = settings
        scheduleNextReset()
    }
    
    var activeTasks: [TaskItem] {
        tasks.filter { !$0.isExpired && !$0.isCompleted }
    }
    
    var sortedByExpiry: [TaskItem] {
        activeTasks.sorted { $0.expiresAt < $1.expiresAt }
    }
    
    var currentFireIntensity: Double {
        let active = activeTasks.count
        let total = completedCount + expiredCount + active
        
        guard total > 0 else { return 0.5 }
        
        let completionRatio = Double(completedCount) / Double(total)
        let targetIntensity = max(0.1, min(1.0, completionRatio))
        
        // Smooth transition
        let alpha = 0.02
        fireIntensity = fireIntensity * (1 - alpha) + targetIntensity * alpha
        
        return fireIntensity
    }
    
    func add(title: String, duration: TimeInterval, location: String? = nil, link: URL? = nil) {
        let cappedDuration = min(duration, ImaSettings.hardUpperBound)
        let task = TaskItem(title: title, duration: cappedDuration, location: location, link: link)
        tasks.append(task)
        saveTasks()
    }
    
    func complete(task: TaskItem) {
        // Ensure we don't complete the same task multiple times
        guard let index = tasks.firstIndex(where: { $0.id == task.id && !$0.isCompleted }) else { return }
        
        tasks[index].isCompleted = true
        completedCount += 1
        saveTasks()
        
        // Trigger UI update immediately
        objectWillChange.send()
        
        // Remove completed task after animation completes (longer delay for smoother transition)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.purgeCompleted()
        }
    }
    
    func purgeExpired() {
        let expiredTasks = tasks.filter { $0.isExpired && !$0.isCompleted }
        expiredCount += expiredTasks.count
        tasks.removeAll { $0.isExpired || $0.isCompleted }
        
        if !expiredTasks.isEmpty {
            saveTasks()
        }
    }
    
    func resetStatistics() {
        completedCount = 0
        expiredCount = 0
        saveTasks()
    }
}

// MARK: - Task Store Private Implementation
private extension TaskStore {
    func scheduleNextReset() {
        resetTimer?.invalidate()
        
        guard let settings = settings else { return }
        
        let nextResetDate = calculateNextResetDate(settings: settings)
        
        if let nextDate = nextResetDate {
            let timeInterval = nextDate.timeIntervalSinceNow
            if timeInterval > 0 {
                resetTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.resetStatistics()
                        self?.scheduleNextReset() // Schedule the next reset
                    }
                }
            }
        }
    }
    
    func calculateNextResetDate(settings: ImaSettings) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        
        // Create date components for the reset time
        let resetTimeComponents = calendar.dateComponents([.hour, .minute], from: settings.resetTime)
        
        switch settings.resetFrequency {
        case .daily:
            return calculateDailyResetDate(calendar: calendar, now: now, resetTimeComponents: resetTimeComponents, settings: settings)
            
        case .specificDays:
            return calculateSpecificDaysResetDate(calendar: calendar, now: now, resetTimeComponents: resetTimeComponents, settings: settings)
        }
    }
    
    func calculateDailyResetDate(calendar: Calendar, now: Date, resetTimeComponents: DateComponents, settings: ImaSettings) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = resetTimeComponents.hour
        components.minute = resetTimeComponents.minute
        components.second = 0
        components.timeZone = settings.timeZone
        
        if let todayReset = calendar.date(from: components) {
            if todayReset > now {
                return todayReset
            } else {
                // If today's reset time has passed, schedule for tomorrow
                return calendar.date(byAdding: .day, value: 1, to: todayReset)
            }
        }
        return nil
    }
    
    func calculateSpecificDaysResetDate(calendar: Calendar, now: Date, resetTimeComponents: DateComponents, settings: ImaSettings) -> Date? {
        // Ensure we have selected weekdays
        guard !settings.selectedWeekdays.isEmpty else { return nil }
        
        var nextDate: Date?
        
        // Check today first if it's a selected weekday
        let todayWeekday = calendar.component(.weekday, from: now)
        if settings.selectedWeekdays.contains(todayWeekday) {
            var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
            todayComponents.hour = resetTimeComponents.hour
            todayComponents.minute = resetTimeComponents.minute
            todayComponents.second = 0
            todayComponents.timeZone = settings.timeZone
            
            if let todayReset = calendar.date(from: todayComponents), todayReset > now {
                nextDate = todayReset
            }
        }
        
        // If no reset today or time has passed, find next selected weekday
        if nextDate == nil {
            for weekday in settings.selectedWeekdays.sorted() {
                // Find next occurrence of this weekday
                var searchDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
                
                // Search up to 7 days ahead
                for _ in 0..<7 {
                    let searchWeekday = calendar.component(.weekday, from: searchDate)
                    if searchWeekday == weekday {
                        var components = calendar.dateComponents([.year, .month, .day], from: searchDate)
                        components.hour = resetTimeComponents.hour
                        components.minute = resetTimeComponents.minute
                        components.second = 0
                        components.timeZone = settings.timeZone
                        
                        if let candidateDate = calendar.date(from: components) {
                            if nextDate == nil || candidateDate < nextDate! {
                                nextDate = candidateDate
                            }
                            break
                        }
                    }
                    searchDate = calendar.date(byAdding: .day, value: 1, to: searchDate) ?? searchDate
                }
            }
        }
        
        return nextDate
    }
    
    func purgeCompleted() {
        tasks.removeAll { $0.isCompleted }
        saveTasks()
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.purgeExpired()
                self?.objectWillChange.send()
            }
        }
    }
    
    func loadTasks() {
        guard let data = UserDefaults.standard.data(forKey: "ImaTasks"),
              let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) else { return }
        tasks = decoded
        
        completedCount = UserDefaults.standard.integer(forKey: "ImaCompletedCount")
        expiredCount = UserDefaults.standard.integer(forKey: "ImaExpiredCount")
    }
    
    func saveTasks() {
        guard let encoded = try? JSONEncoder().encode(tasks) else { return }
        UserDefaults.standard.set(encoded, forKey: "ImaTasks")
        UserDefaults.standard.set(completedCount, forKey: "ImaCompletedCount")
        UserDefaults.standard.set(expiredCount, forKey: "ImaExpiredCount")
    }
}