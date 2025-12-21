import SwiftUI
import Combine

// MARK: - Task Card View
struct TaskCardView: View {
    let task: TaskItem
    let isDominant: Bool
    let onComplete: () -> Void
    
    @Environment(\.openURL) private var openURL
    @State private var isCompleting = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: isDominant ? 16 : 12) {
            // Header with title and complete button
            HStack(alignment: .center, spacing: 12) {
                // Title on the left
                Text(task.title)
                    .font(dynamicTitleFont)
                    .lineLimit(isDominant ? 3 : 2)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Timer and complete button on the right
                HStack(spacing: 12) {
                    TimeRemainingView(task: task, isDominant: isDominant)
                    
                    Button(action: handleComplete) {
                        Image(systemName: (isCompleting || task.isCompleted) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: isDominant ? 20 : 18, weight: .medium))
                            .foregroundStyle((isCompleting || task.isCompleted) ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isCompleting || task.isCompleted)
                }
            }
            
            // Optional metadata - location and link on same line
            if (task.location != nil && !task.location!.isEmpty) || task.link != nil {
                HStack(spacing: 16) {
                    if let location = task.location, !location.isEmpty {
                        Label(location, systemImage: "location")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let link = task.link {
                        Button(action: { openURL(link) }) {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                Text(link.host ?? link.absoluteString)
                                    .lineLimit(1)
                            }
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(isDominant ? 24 : 18)
        .background(
            RoundedRectangle(cornerRadius: isDominant ? 24 : 18, style: .continuous)
                .fill(taskBackgroundColor)
        )
        .scaleEffect(isCompleting ? 0.92 : 1.0)
        .opacity(isCompleting ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.4), value: isCompleting)
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity).combined(with: .move(edge: .trailing))
        ))
        .onChange(of: task.id) { _, _ in
            // Reset completion state when task changes
            isCompleting = false
        }
        .onChange(of: task.isCompleted) { _, newValue in
            // Reset completion state if task completion status changes
            if newValue {
                isCompleting = false
            }
        }
    }
    
    private var taskBackgroundColor: Color {
        if isDominant {
            return Color.imaPurple.opacity(0.4)
        } else {
            return Color.black.opacity(0.25)
        }
    }
    
    private var dynamicTitleFont: Font {
        let titleLength = task.title.count
        if isDominant {
            if titleLength > 50 {
                return .system(size: 20, weight: .medium, design: .rounded)
            } else if titleLength > 30 {
                return .system(size: 22, weight: .medium, design: .rounded)
            } else {
                return .system(size: 24, weight: .medium, design: .rounded)
            }
        } else {
            if titleLength > 40 {
                return .system(size: 16, weight: .medium, design: .rounded)
            } else {
                return .system(size: 18, weight: .medium, design: .rounded)
            }
        }
    }
    
    private var urgencyIntensity: Double {
        switch task.urgencyLevel {
        case .normal: return 0.8
        case .urgent: return 1.0
        case .critical: return 1.2
        case .expired: return 0.4
        }
    }
    
    private func handleComplete() {
        // Prevent multiple completions
        guard !isCompleting && !task.isCompleted else { return }
        
        withAnimation(.easeInOut(duration: 0.4)) {
            isCompleting = true
        }
        
        // Slightly longer delay for smoother animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onComplete()
        }
    }
}

// MARK: - Time Remaining View
struct TimeRemainingView: View {
    let task: TaskItem
    let isDominant: Bool
    
    @State private var currentTime = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        // Just the circular progress indicator - smaller circle, larger text
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
            
            // Progress circle with gradient
            Circle()
                .trim(from: 0, to: progressValue)
                .stroke(
                    progressGradient,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progressValue)
            
            // Time text in center - slightly smaller font, center aligned
            Text(formatCompactTime(task.timeRemaining))
                .font(.system(size: isDominant ? 14 : 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(progressColor)
                .multilineTextAlignment(.center)
        }
        .frame(width: isDominant ? 50 : 40, height: isDominant ? 50 : 40)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    private var progressValue: Double {
        let totalDuration = task.expiresAt.timeIntervalSince(task.createdAt)
        let elapsed = Date().timeIntervalSince(task.createdAt)
        let remaining = max(0, totalDuration - elapsed)
        return max(0, min(1, remaining / totalDuration))
    }
    
    private var progressGradient: AngularGradient {
        let progress = progressValue
        if progress > 0.6 {
            // Green when plenty of time
            return AngularGradient(
                colors: [.green, .green.opacity(0.8)],
                center: .center
            )
        } else if progress > 0.3 {
            // Yellow when moderate time
            return AngularGradient(
                colors: [.yellow, .yellow.opacity(0.8)],
                center: .center
            )
        } else {
            // Orange when low time
            return AngularGradient(
                colors: [.orange, .orange.opacity(0.8)],
                center: .center
            )
        }
    }
    
    private var progressColor: Color {
        let progress = progressValue
        if progress > 0.6 {
            return .green
        } else if progress > 0.3 {
            return .yellow
        } else {
            return .orange
        }
    }
}

// MARK: - Status Bar View (replaces Fire Indicator)
struct StatusBarView: View {
    @EnvironmentObject private var store: TaskStore
    
    var body: some View {
        HStack(spacing: 16) {
                    // Custom icon with intensity glow
                    ZStack {
                        // Glow effect based on fire intensity
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        flameColor.opacity(0.5 * store.currentFireIntensity),
                                        flameColor.opacity(0.3 * store.currentFireIntensity),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 25
                                )
                            )
                            .frame(width: 50, height: 50)
                            .blur(radius: 6)
                        
                        // Custom icon
                        Image("AppSVGIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(flameColor)
                    }
            
            Spacer()
            
            // Task counters
            HStack(spacing: 20) {
                // Active tasks
                VStack(spacing: 2) {
                    Text("\(store.activeTasks.count)")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text("Active")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                // Completed tasks
                VStack(spacing: 2) {
                    Text("\(store.completedCount)")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.green)
                    Text("Done")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                // Expired tasks
                VStack(spacing: 2) {
                    Text("\(store.expiredCount)")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.orange)
                    Text("Faded")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // Base material
                Capsule()
                    .fill(.ultraThinMaterial)
                
                // Purple + Pink gradient overlay
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.imaPurple.opacity(0.08),
                                Color.pink.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Border with purple/pink tint
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.imaPurple.opacity(0.25),
                                Color.pink.opacity(0.15),
                                Color.clear,
                                Color.imaPurple.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
        )
    }
    
    private var flameColor: Color {
        let intensity = store.currentFireIntensity
        if intensity > 0.7 {
            return Color.imaPurple
        } else if intensity > 0.4 {
            return Color.pink
        } else {
            return Color.imaPurple.opacity(0.7)
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.green)
            
            VStack(spacing: 8) {
                Text("No Active Tasks")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.primary)
                
                Text("Ready for your next challenge?")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
        .background(Color.clear)
    }
}