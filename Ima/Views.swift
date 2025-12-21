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
        VStack(alignment: .leading, spacing: 16) {
            // Header with title and complete button
            HStack(alignment: .center, spacing: 12) {
                // Title on the left
                Text(task.title)
                    .font(dynamicTitleFont)
                    .lineLimit(isDominant ? 3 : 2)
                    .foregroundStyle(isDominant ? .white : .primary)
                    .padding(.leading, isDominant ? 0 : 8)
                Spacer()
                
                // Timer and complete button on the right
                HStack(spacing: 12) {
                    TimeRemainingView(task: task, isDominant: isDominant)
                    .padding(.horizontal, isDominant ? 0 : 4)
                    Button(action: handleComplete) {
                        Image(systemName: (isCompleting || task.isCompleted) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: isDominant ? 20 : 18, weight: .medium))
                            .foregroundStyle((isCompleting || task.isCompleted) ? .green : (isDominant ? .white : .secondary))
                    }
                    .buttonStyle(.plain)
                    .disabled(isCompleting || task.isCompleted)
                    .padding(.trailing, isDominant ? 0 : 8)
                }
            }
            
            // Optional metadata - location and link on same line
            if (task.location != nil && !task.location!.isEmpty) || task.link != nil {
                HStack(spacing: 16) {
                    if let location = task.location, !location.isEmpty {
                        Label(location, systemImage: "location")
                            .font(.subheadline)
                            .foregroundStyle(isDominant ? .white.opacity(0.8) : .secondary)
                            .padding(.leading, isDominant ? 0 : 8)
                    }
                    
                    if let link = task.link {
                        Button(action: { openURL(link) }) {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                Text(link.host ?? link.absoluteString)
                                    .lineLimit(1)
                            }
                            .font(.footnote)
                            .foregroundStyle(isDominant ? Color.white.opacity(0.6) : Color.secondary)
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
                .fill(isDominant ? AnyShapeStyle(Color.imaPurple) : AnyShapeStyle(.ultraThickMaterial))
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
                .stroke(isDominant ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 2)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progressValue)
                .stroke(
                    indicatorColor,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progressValue)
            
            // Time text in center - slightly smaller font, center aligned
            Text(formatCompactTime(task.timeRemaining))
                .font(.system(size: isDominant ? 14 : 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(indicatorColor)
                .multilineTextAlignment(.center)
                .padding(4)
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
    
    private var indicatorColor: Color {
        let isLowTime = progressValue < 0.3
        if isDominant {
            // Use explicit yellow that doesn't adapt to color scheme
            return isLowTime ? Color(red: 1.0, green: 0.9, blue: 0.2) : .white
        } else {
            return isLowTime ? .orange : .primary
        }
    }
}

// MARK: - Status Bar View
struct StatusBarView: View {
    @EnvironmentObject private var store: TaskStore
    
    var body: some View {
        HStack(spacing: 16) {
                    // Custom icon with intensity glow
                    ZStack {
                        Image("AppSVGIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.primary)
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
                // Border with purple/pink tint
                Capsule()
                    .fill(.ultraThinMaterial)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.imaPurple.opacity(0.25),
                                Color.clear,
                                Color.imaPurple.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
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
