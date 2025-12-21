//
//  ContentView.swift
//  Ima
//
//  Created by Advaith Krishna A on 21/12/25.
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var settings: ImaSettings
    @State private var isPresentingCreate = false
    @State private var isMenuExpanded = false
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content below header
            VStack(spacing: 0) {
                Spacer().frame(height: 56) // space for integrated header
                if store.sortedByExpiry.isEmpty && !isPresentingCreate {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // New task creation form at the top of scroll view
                            if isPresentingCreate {
                                VStack(alignment: .leading, spacing: 12) {
                                    InlineCreateTaskView(
                                        onCancel: { withAnimation(.easeInOut) { isPresentingCreate = false } },
                                        onSave: { title, hours, minutes, location, link in
                                            createTask(title: title, hours: hours, minutes: minutes, location: location, link: link)
                                        }
                                    )
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                )
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                                .transition(.opacity)
                            }
                            
                            // Existing tasks
                            if let dominantTask = store.sortedByExpiry.first {
                                TaskCardView(
                                    task: dominantTask,
                                    isDominant: true,
                                    onComplete: { store.complete(task: dominantTask) }
                                )
                                .id("dominant-\(dominantTask.id)")
                                .padding(.horizontal, 20)
                                .padding(.top, isPresentingCreate ? 12 : 20)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity).combined(with: .move(edge: .trailing))
                                ))
                            }
                            let remainingTasks = Array(store.sortedByExpiry.dropFirst())
                            ForEach(remainingTasks, id: \.id) { task in
                                TaskCardView(
                                    task: task,
                                    isDominant: false,
                                    onComplete: { store.complete(task: task) }
                                )
                                .id("regular-\(task.id)")
                                .padding(.horizontal, 20)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity).combined(with: .move(edge: .trailing))
                                ))
                            }
                            Spacer().frame(height: 100)
                        }
                        .animation(.easeInOut(duration: 0.5), value: store.sortedByExpiry.map { $0.id })
                    }
                }
            }

            // Integrated header with app name, expandable menu, and create button
            HStack {
                // Left side - App name and expandable menu
                HStack(spacing: 12) {
                    Text("Ima")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    // Expandable menu
                    HStack(spacing: 8) {
                        // Expand/collapse button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isMenuExpanded.toggle()
                            }
                        }) {
                            Image(systemName: isMenuExpanded ? "chevron.left" : "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .liquidGlassButton(circular: true)
                        
                        // Settings and quit buttons (slide in/out)
                        if isMenuExpanded {
                            HStack(spacing: 8) {
                                Button(action: { 
                                    NotificationCenter.default.post(name: NSNotification.Name("ShowSettings"), object: nil)
                                }) {
                                    Image(systemName: "gearshape")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .liquidGlassButton(circular: true)
                                
                                Button(action: {
                                    #if os(macOS)
                                    NSApp.terminate(nil)
                                    #endif
                                }) {
                                    Image(systemName: "power")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .liquidGlassButton(circular: true)
                            }
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                }
                
                Spacer()
                
                // Right side - Create button
                Button(action: { isPresentingCreate = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                }
                .liquidGlassButton(prominent: true, circular: true)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Status bar at bottom (always visible)
            VStack {
                Spacer()
                StatusBarView()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            store.purgeExpired()
        }
        .preferredColorScheme(.dark)
    }
    
    private func createTask(title: String, hours: Int, minutes: Int, location: String, link: String) {
        let duration = max(0, (hours * 3600) + (min(max(minutes, 0), 59) * 60))
        let cappedDuration = min(TimeInterval(duration), settings.maxAllowedDuration)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, cappedDuration > 0 else { return }

        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let locationValue: String? = trimmedLocation.isEmpty ? nil : trimmedLocation

        let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkValue: URL? = URL.validURL(from: trimmedLink)

        withAnimation(.easeInOut) {
            store.add(title: trimmedTitle, duration: cappedDuration, location: locationValue, link: linkValue)
            isPresentingCreate = false
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TaskStore())
        .environmentObject(ImaSettings())
}
struct InlineCreateTaskView: View {
    var onCancel: () -> Void
    var onSave: (_ title: String, _ hours: Int, _ minutes: Int, _ location: String, _ link: String) -> Void

    @State private var title: String = ""
    @State private var hoursText: String = ""
    @State private var minutesText: String = ""
    @State private var location: String = ""
    @State private var link: String = ""
    @State private var timeSelectionMode: TimeSelectionMode = .relative
    @State private var selectedDate = Date().addingTimeInterval(3600) // 1 hour from now
    
    @EnvironmentObject private var settings: ImaSettings
    
    enum TimeSelectionMode: String, CaseIterable {
        case relative = "Duration"
        case absolute = "Date & Time"
    }
    
    private let presetDurations: [(String, TimeInterval)] = [
        ("1h", 3600),
        ("6h", 6 * 3600),
        ("1d", 24 * 3600),
        ("3d", 3 * 24 * 3600)
    ]

    private var hours: Int { Int(hoursText) ?? 0 }
    private var minutes: Int { min(max(Int(minutesText) ?? 0, 0), 59) }
    private var relativeDuration: TimeInterval { TimeInterval((hours * 3600) + (minutes * 60)) }
    private var absoluteDuration: TimeInterval { max(0, selectedDate.timeIntervalSinceNow) }
    
    private var totalDuration: TimeInterval {
        switch timeSelectionMode {
        case .relative:
            return relativeDuration
        case .absolute:
            return absoluteDuration
        }
    }
    
    private var maxAllowedDate: Date {
        Date().addingTimeInterval(settings.maxAllowedDuration)
    }
    
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        totalDuration > 0 && 
        totalDuration <= settings.maxAllowedDuration
    }
    private var exceedsLimit: Bool {
        totalDuration > settings.maxAllowedDuration
    }
    
    private func resetForm() {
        title = ""
        hoursText = ""
        minutesText = ""
        location = ""
        link = ""
        timeSelectionMode = .relative
        selectedDate = Date().addingTimeInterval(3600) // 1 hour from now
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("New Task")
                    .font(.headline)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            VStack(alignment: .leading, spacing: 12) {
                // Task name
                TextField("What is this about?", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)

                // Location and URL on same line
                HStack(spacing: 8) {
                    TextField("Location", text: $location)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack(spacing: 4) {
                        TextField("URL", text: $link)
                            .textFieldStyle(.roundedBorder)
                        
                        if !link.isEmpty {
                            if URL.isValidURLFormat(link) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.system(size: 12))
                            } else {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.system(size: 12))
                            }
                        }
                    }
                }

                // Time selection mode toggle with "Fades in" label
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Fades in ")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        ForEach(TimeSelectionMode.allCases, id: \.self) { mode in
                            Button(action: {
                                timeSelectionMode = mode
                                // Sync values when switching modes
                                if mode == .absolute && selectedDate <= Date() {
                                    selectedDate = Date().addingTimeInterval(max(1800, relativeDuration))
                                } else if mode == .relative && relativeDuration <= 0 {
                                    let duration = max(1800, absoluteDuration)
                                    hoursText = String(Int(duration) / 3600)
                                    minutesText = String((Int(duration) % 3600) / 60)
                                }
                            }) {
                                Text(mode.rawValue)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                            }
                            .liquidGlassButton(prominent: timeSelectionMode == mode, circular: false)
                        }
                        Spacer()
                    }
                    
                    // Duration input based on selected mode
                    if timeSelectionMode == .relative {
                        // Relative duration input
                        VStack(spacing: 8) {
                            // Time inputs and max warning on same line
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Hours").font(.caption).foregroundStyle(.secondary)
                                    TextField("0", text: $hoursText)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                        .onChange(of: hoursText) { _, newValue in
                                            hoursText = newValue.filter { $0.isNumber }
                                        }
                                }

                                Text(":")
                                    .font(.headline)
                                    .padding(.top, 18) // Align with text fields
                                    .padding(.horizontal, 4)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Minutes").font(.caption).foregroundStyle(.secondary)
                                    TextField("0", text: $minutesText)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                        .onChange(of: minutesText) { _, newValue in
                                            minutesText = newValue.filter { $0.isNumber }
                                        }
                                }
                                
                                Spacer()
                                
                                // Max duration warning
                                if exceedsLimit {
                                    Text("Max: \(formatRemaining(settings.maxAllowedDuration))")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                            
                            // Preset duration buttons on separate line
                            HStack(spacing: 6) {
                                ForEach(presetDurations, id: \.1) { label, duration in
                                    Button(action: {
                                        let cappedDuration = min(duration, settings.maxAllowedDuration)
                                        hoursText = String(Int(cappedDuration) / 3600)
                                        minutesText = String((Int(cappedDuration) % 3600) / 60)
                                    }) {
                                        Text(label)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                    }
                                    .liquidGlassButton(prominent: abs(relativeDuration - duration) < 1800, circular: false)
                                    .disabled(duration > settings.maxAllowedDuration)
                                }
                                Spacer()
                            }
                        }
                    } else {
                        // Absolute date/time picker
                        VStack(alignment: .leading, spacing: 6) {
                            DatePicker(
                                "Expires at",
                                selection: $selectedDate,
                                in: Date()...maxAllowedDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            
                            // Show calculated duration
                            HStack {
                                Text("Duration: \(formatRemaining(absoluteDuration))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if exceedsLimit {
                                    Text("Max: \(formatRemaining(settings.maxAllowedDuration))")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }

                // Save button
                HStack {
                    Spacer()
                    Button("Save") {
                        // Convert to hours/minutes for the callback
                        let duration = min(totalDuration, settings.maxAllowedDuration)
                        let finalHours = Int(duration) / 3600
                        let finalMinutes = (Int(duration) % 3600) / 60
                        onSave(title, finalHours, finalMinutes, location, link)
                    }
                    .liquidGlassButton(prominent: true)
                    .disabled(!canSave)
                }
            }
        }
        .onAppear {
            resetForm()
        }
    }
}
