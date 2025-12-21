import SwiftUI

// MARK: - Liquid Glass Effects

/// A view modifier that applies a liquid glass background effect
struct LiquidGlassBackground: ViewModifier {
    let cornerRadius: CGFloat
    let intensity: Double
    
    func body(content: Content) -> some View {
        content
            .background(glassBackground)
    }
    
    private var glassBackground: some View {
        ZStack {
            // Base glass layer
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            
            // Subtle gradient overlay
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(gradientOverlay)
            
            // Border highlight
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(borderGradient, lineWidth: 0.5)
        }
    }
    
    private var gradientOverlay: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.15 * intensity),
                Color.white.opacity(0.05 * intensity),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.3),
                Color.white.opacity(0.1),
                Color.clear,
                Color.white.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// A button style that creates liquid glass buttons with optional prominence and circular shape
struct LiquidGlassButton: ButtonStyle {
    let prominent: Bool
    let circular: Bool
    
    init(prominent: Bool = false, circular: Bool = false) {
        self.prominent = prominent
        self.circular = circular
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? .white : .primary)
            .padding(.horizontal, circular ? 0 : 16)
            .padding(.vertical, circular ? 0 : 8)
            .frame(width: circular ? 36 : nil, height: circular ? 36 : nil)
            .background(buttonBackground)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private var buttonBackground: some View {
        ZStack {
            // Background - solid purple for prominent, translucent for others
            baseBackground
            
            // Border
            borderOverlay
        }
    }
    
    private var baseBackground: some View {
        Group {
            if circular {
                if prominent {
                    Circle().fill(Color.imaPurple)
                } else {
                    Circle().fill(.ultraThinMaterial)
                }
            } else {
                if prominent {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.imaPurple)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
        }
    }
    
    private var borderOverlay: some View {
        Group {
            if circular {
                Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Applies a liquid glass background effect
    func liquidGlass(cornerRadius: CGFloat = 16, intensity: Double = 1.0) -> some View {
        modifier(LiquidGlassBackground(cornerRadius: cornerRadius, intensity: intensity))
    }
    
    /// Applies a liquid glass button style
    func liquidGlassButton(prominent: Bool = false, circular: Bool = false) -> some View {
        buttonStyle(LiquidGlassButton(prominent: prominent, circular: circular))
    }
}