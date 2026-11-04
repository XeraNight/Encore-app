import UIKit

// MARK: - Zero-Allocation Pre-Warmed Haptic Feedback Manager
// Reuses pre-allocated CoreHaptics / UIImpactFeedbackGenerator instances
// Eliminates memory churn during 80-200 BPM metronome ticks and rapid user interactions.
public enum HapticFeedback {
    private static let lightGenerator: UIImpactFeedbackGenerator = {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        return gen
    }()
    
    private static let mediumGenerator: UIImpactFeedbackGenerator = {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.prepare()
        return gen
    }()
    
    private static let heavyGenerator: UIImpactFeedbackGenerator = {
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.prepare()
        return gen
    }()
    
    private static let notificationGenerator: UINotificationFeedbackGenerator = {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        return gen
    }()
    
    public static func light() {
        lightGenerator.impactOccurred()
        lightGenerator.prepare()
    }
    
    public static func medium() {
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }
    
    public static func heavy() {
        heavyGenerator.impactOccurred()
        heavyGenerator.prepare()
    }
    
    public static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
        notificationGenerator.prepare()
    }
    
    public static func success() {
        notify(.success)
    }
    
    public static func warning() {
        notify(.warning)
    }
    
    public static func error() {
        notify(.error)
    }
}
