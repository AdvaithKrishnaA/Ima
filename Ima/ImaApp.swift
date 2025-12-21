//
//  ImaApp.swift
//  Ima
//
//  Created by Advaith Krishna A on 21/12/25.
//

import SwiftUI

@main
struct ImaApp: App {
    @StateObject private var store = TaskStore()
    @StateObject private var settings = ImaSettings()

    @State private var showingSettings = false

    init() {
        // Configure app for menu bar only operation
        #if os(macOS)
        // Set activation policy early to prevent dock icon
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
            
            // Disable automatic window restoration
            UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
            
            // Prevent app from appearing in Force Quit dialog
            NSApp.disableRelaunchOnLogin()
        }
        #endif
    }

    var body: some Scene {
        MenuBarExtra("Ima", image: "MenuBarIcon") {
            VStack(spacing: 0) {
                Group {
                    if showingSettings {
                        VStack(spacing: 0) {
                            // Settings header
                            HStack {
                                Button {
                                    showingSettings = false
                                } label: {
                                    Label("Back", systemImage: "chevron.left")
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Text("Settings")
                                    .font(.headline)

                                Spacer()

                                // Spacer to balance the Back button space on the right
                                Color.clear.frame(width: 24, height: 1)
                            }
                            .padding([.horizontal, .top], 12)
                            .padding(.bottom, 8)
                            
                            PreferencesView()
                                .environmentObject(settings)
                                .environmentObject(store)
                        }
                    } else {
                        ContentView()
                            .environmentObject(store)
                            .environmentObject(settings)
                    }
                }
                .frame(width: 420, height: 500)
            }
            .frame(width: 420, height: 500)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSettings"))) { _ in
                showingSettings = true
            }
            .onAppear {
                // Set up the settings reference in the store
                store.setSettings(settings)
                
                #if os(macOS)
                // Additional configuration to prevent ViewBridge issues
                DispatchQueue.main.async {
                    // Ensure we're properly configured as accessory app
                    if NSApp.activationPolicy() != .accessory {
                        NSApp.setActivationPolicy(.accessory)
                    }
                    
                    // Hide from window menu
                    NSApp.windows.forEach { window in
                        window.isExcludedFromWindowsMenu = true
                    }
                }
                #endif
            }
        }
        .menuBarExtraStyle(.window)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit Ima") {
                    #if os(macOS)
                    NSApp.terminate(nil)
                    #endif
                }
                .keyboardShortcut("q")
            }
            
            // Remove other command groups that might cause issues
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .saveItem) { }
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) { }
            CommandGroup(replacing: .windowSize) { }
            CommandGroup(replacing: .windowArrangement) { }
        }
    }
}

// MARK: - Preferences View
struct PreferencesView: View {
    @EnvironmentObject private var settings: ImaSettings
    @EnvironmentObject private var store: TaskStore
    @State private var nextResetDate: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Max Time Setting
                VStack(alignment: .leading, spacing: 12) {
                    Text("Maximum Task Duration")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Text("How long can a task last before it fades away? (1-7 days)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        TextField("Days", value: $settings.maxAllowedDays, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .onChange(of: settings.maxAllowedDays) { _, newValue in
                                // Clamp to 1-7 range
                                settings.maxAllowedDays = max(1, min(newValue, 7))
                            }
                        
                        Text("day\(settings.maxAllowedDays == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("= \(formatRemaining(settings.maxAllowedDuration))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Default Duration Setting
                VStack(alignment: .leading, spacing: 12) {
                    Text("Default Task Duration")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Text("Default duration when creating new tasks (1-24 hours)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        TextField("Hours", value: $settings.defaultDurationHours, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .onChange(of: settings.defaultDurationHours) { _, newValue in
                                // Clamp to 1-24 range
                                settings.defaultDurationHours = max(1, min(newValue, 24))
                            }
                        
                        Text("hour\(settings.defaultDurationHours == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("= \(formatRemaining(settings.defaultDuration))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Reset Statistics Setting
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reset Statistics")
                            .font(.headline.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        Text("Automatically clear completed and faded task counts. Active tasks are not affected.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Frequency Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Frequency")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        VStack(spacing: 8) {
                            ForEach(ResetFrequency.allCases, id: \.self) { frequency in
                                Button(action: {
                                    settings.resetFrequency = frequency
                                }) {
                                    HStack {
                                        Text(frequency.displayName)
                                            .font(.subheadline)
                                        Spacer()
                                        if settings.resetFrequency == frequency {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(Color.imaPurple)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                }
                                .liquidGlassButton(prominent: settings.resetFrequency == frequency)
                            }
                        }
                    }
                    
                    // Specific Days Selection (only show if specificDays is selected)
                    if settings.resetFrequency == .specificDays {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Days")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                                ForEach(weekdayOptions, id: \.value) { weekday in
                                    Button(action: {
                                        if settings.selectedWeekdays.contains(weekday.value) {
                                            // Don't allow removing the last selected day
                                            if settings.selectedWeekdays.count > 1 {
                                                settings.selectedWeekdays.remove(weekday.value)
                                            }
                                        } else {
                                            settings.selectedWeekdays.insert(weekday.value)
                                        }
                                    }) {
                                        Text(weekday.short)
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                    }
                                    .liquidGlassButton(prominent: settings.selectedWeekdays.contains(weekday.value))
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Time Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reset Time")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        DatePicker("", selection: $settings.resetTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    
                    // Time Zone Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Time Zone")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        Menu {
                            // Current timezone section
                            Section("Current") {
                                Button(action: {
                                    settings.timeZone = TimeZone.current
                                }) {
                                    HStack {
                                        Text(timeZoneDisplayName(TimeZone.current))
                                        if settings.timeZone.identifier == TimeZone.current.identifier {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                            
                            // Group time zones by region
                            let groupedZones = Dictionary(grouping: commonTimeZones.filter { $0.identifier != TimeZone.current.identifier }) { timeZone in
                                timeZone.identifier.components(separatedBy: "/").first ?? "Other"
                            }
                            
                            ForEach(["America", "Europe", "Asia", "Australia", "Africa", "Pacific"].filter { groupedZones[$0] != nil }, id: \.self) { region in
                                Section(region) {
                                    ForEach(groupedZones[region] ?? [], id: \.identifier) { timeZone in
                                        Button(action: {
                                            settings.timeZone = timeZone
                                        }) {
                                            HStack {
                                                Text(timeZoneDisplayName(timeZone))
                                                if settings.timeZone.identifier == timeZone.identifier {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Other regions
                            let otherRegions = groupedZones.keys.filter { !["America", "Europe", "Asia", "Australia", "Africa", "Pacific"].contains($0) }.sorted()
                            ForEach(otherRegions, id: \.self) { region in
                                Section(region) {
                                    ForEach(groupedZones[region] ?? [], id: \.identifier) { timeZone in
                                        Button(action: {
                                            settings.timeZone = timeZone
                                        }) {
                                            HStack {
                                                Text(timeZoneDisplayName(timeZone))
                                                if settings.timeZone.identifier == timeZone.identifier {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(timeZoneDisplayName(settings.timeZone))
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .liquidGlassButton()
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Manual Reset Button
                VStack(alignment: .leading, spacing: 12) {
                    Text("Manual Reset")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Text("Immediately clear all completed and faded task statistics.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Show next scheduled reset
                    if let nextReset = nextResetDate {
                        Text("Next automatic reset: \(nextReset, style: .date) at \(nextReset, style: .time)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)
                    }
                    
                    Button(action: {
                        store.resetStatistics()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .medium))
                            Text("Reset Now")
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .liquidGlassButton()
                }
                
                Spacer().frame(height: 20)
            }
            .padding(20)
        }
        .onAppear {
            updateNextResetDate()
        }
        .onDisappear {
            settings.saveSettings()
        }
        .onChange(of: settings.resetFrequency) { _, _ in
            store.setSettings(settings)
            updateNextResetDate()
        }
        .onChange(of: settings.resetTime) { _, _ in
            store.setSettings(settings)
            updateNextResetDate()
        }
        .onChange(of: settings.selectedWeekdays) { _, _ in
            store.setSettings(settings)
            updateNextResetDate()
        }
        .onChange(of: settings.timeZone) { _, _ in
            store.setSettings(settings)
            updateNextResetDate()
        }
    }
    
    private var weekdayOptions: [(name: String, short: String, value: Int)] {
        [
            ("Sunday", "Sun", 1),
            ("Monday", "Mon", 2),
            ("Tuesday", "Tue", 3),
            ("Wednesday", "Wed", 4),
            ("Thursday", "Thu", 5),
            ("Friday", "Fri", 6),
            ("Saturday", "Sat", 7)
        ]
    }
    
    private var commonTimeZones: [TimeZone] {
        // Get all available time zones from Apple's API
        let allIdentifiers = TimeZone.knownTimeZoneIdentifiers.sorted()
        let allTimeZones = allIdentifiers.compactMap { TimeZone(identifier: $0) }
        
        // Filter out deprecated or unusual time zones for better UX
        let filteredZones = allTimeZones.filter { timeZone in
            let identifier = timeZone.identifier
            // Keep major cities and regions, filter out military/deprecated zones
            return !identifier.contains("Etc/") && 
                   !identifier.hasPrefix("US/") && 
                   !identifier.contains("SystemV/") &&
                   !identifier.contains("Zulu")
        }
        
        // Group by region for better organization
        var groupedZones: [String: [TimeZone]] = [:]
        
        for timeZone in filteredZones {
            let components = timeZone.identifier.components(separatedBy: "/")
            let region = components.first ?? "Other"
            
            if groupedZones[region] == nil {
                groupedZones[region] = []
            }
            groupedZones[region]?.append(timeZone)
        }
        
        // Sort zones within each group
        for region in groupedZones.keys {
            groupedZones[region]?.sort { $0.identifier < $1.identifier }
        }
        
        // Prioritize current timezone and common regions
        var result: [TimeZone] = []
        
        // Add current timezone first if not already included
        if !result.contains(where: { $0.identifier == TimeZone.current.identifier }) {
            result.append(TimeZone.current)
        }
        
        // Add common regions in order
        let priorityRegions = ["America", "Europe", "Asia", "Australia", "Africa", "Pacific"]
        
        for region in priorityRegions {
            if let zones = groupedZones[region] {
                result.append(contentsOf: zones.filter { $0.identifier != TimeZone.current.identifier })
            }
        }
        
        // Add remaining regions
        for (region, zones) in groupedZones.sorted(by: { $0.key < $1.key }) {
            if !priorityRegions.contains(region) {
                result.append(contentsOf: zones.filter { $0.identifier != TimeZone.current.identifier })
            }
        }
        
        return result
    }
    
    private func timeZoneDisplayName(_ timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "zzz"
        let abbreviation = formatter.string(from: Date())
        
        // Get the city/region name from identifier
        let components = timeZone.identifier.components(separatedBy: "/")
        let cityName = components.last?.replacingOccurrences(of: "_", with: " ") ?? timeZone.identifier
        
        // Calculate offset
        let offsetSeconds = timeZone.secondsFromGMT()
        let offsetHours = offsetSeconds / 3600
        let offsetMinutes = abs(offsetSeconds % 3600) / 60
        let offsetString = String(format: "%+03d:%02d", offsetHours, offsetMinutes)
        
        if timeZone.identifier == TimeZone.current.identifier {
            return "\(cityName) (\(abbreviation) \(offsetString)) - Current"
        }
        
        return "\(cityName) (\(abbreviation) \(offsetString))"
    }
    
    private func updateNextResetDate() {
        nextResetDate = calculateNextResetDate()
    }
    
    private func calculateNextResetDate() -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        
        // Create date components for the reset time
        let resetTimeComponents = calendar.dateComponents([.hour, .minute], from: settings.resetTime)
        
        switch settings.resetFrequency {
        case .daily:
            // Find next occurrence of the reset time
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
            
        case .specificDays:
            // Ensure we have selected weekdays
            guard !settings.selectedWeekdays.isEmpty else { return nil }
            
            // Find next occurrence of any selected weekday at reset time
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
        
        return nil
    }
}
