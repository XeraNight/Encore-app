import SwiftUI
import AudioToolbox
import Combine

// MARK: - Dynamic Island Recording View (1:1 Figma Community Prototype & Apple HIG)
public struct DynamicIslandRecordingView: View {
    // Session State
    @Binding public var isRecording: Bool
    @Binding public var durationSeconds: Int
    public var sessionTitle: String = "Dance Training Hall 4"
    public var liveAudioLevel: Float = 0.65 // 0.0 to 1.0
    
    // Callbacks
    public var onBookmarkTap: (() -> Void)? = nil
    public var onStopTap: (() -> Void)? = nil
    
    // Internal Animation & Presentation States
    @State private var isExpanded: Bool = false
    @State private var isPulsing: Bool = false
    @State private var bookmarkFeedbackTrigger: Bool = false
    
    public init(
        isRecording: Binding<Bool>,
        durationSeconds: Binding<Int>,
        sessionTitle: String = "Dance Training Hall 4",
        liveAudioLevel: Float = 0.65,
        onBookmarkTap: (() -> Void)? = nil,
        onStopTap: (() -> Void)? = nil
    ) {
        self._isRecording = isRecording
        self._durationSeconds = durationSeconds
        self.sessionTitle = sessionTitle
        self.liveAudioLevel = liveAudioLevel
        self.onBookmarkTap = onBookmarkTap
        self.onStopTap = onStopTap
    }
    
    public var body: some View {
        ZStack {
            if isExpanded {
                expandedIslandView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.85, anchor: .top).combined(with: .opacity)
                    ))
            } else {
                compactIslandView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.9, anchor: .top).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.78, blendDuration: 0), value: isExpanded)
        .onTapGesture {
            toggleExpandedState()
        }
        .onAppear {
            startBreathingAnimation()
        }
    }
    
    // MARK: - 1. Compact Island (Photo 1 `COMPACT STATE` - Snug & Compact)
    private var compactIslandView: some View {
        HStack(spacing: 12) {
            // Left: rec-indicator (dot + REC)
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(red: 1.0, green: 0.27, blue: 0.23))
                    .frame(width: 6, height: 6)
                
                Text("REC")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.27, blue: 0.23))
            }
            
            // Right: timer
            Text(formattedDuration(durationSeconds))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.6), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - 2. Expanded Island (Photo 1 `EXPANDED STATE`)
    private var expandedIslandView: some View {
        VStack(spacing: 14) {
            // Top Row: REC + Subtitle (Left) & Prominent Timer (Right)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.27, blue: 0.23))
                            .frame(width: 8, height: 8)
                        
                        Text("REC")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.27, blue: 0.23))
                    }
                    
                    Text(sessionTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Large Big Timer Readout
                Text(formattedDuration(durationSeconds))
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            // Middle Section: `HALL AMBIENT LEVEL` + `ACTIVE SYNC` + 11-Segment Bar
            VStack(spacing: 6) {
                HStack {
                    Text("HALL AMBIENT LEVEL")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(Color.textSecondary)
                        .tracking(0.5)
                    
                    Spacer()
                    
                    Text("ACTIVE SYNC")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.black)
                        .tracking(0.5)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.98, green: 0.88, blue: 0.20))
                        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                }
                
                // 11-Segment Capsule Bar (5 Green, 3 Yellow, 3 Red)
                HStack(spacing: 4) {
                    ForEach(0..<11, id: \.self) { index in
                        let threshold = Float(index + 1) / 11.0
                        let isActive = liveAudioLevel >= threshold
                        
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(segmentColor(for: index, isActive: isActive))
                            .frame(height: 8)
                            .frame(maxWidth: .infinity)
                            .animation(.easeOut(duration: 0.1), value: liveAudioLevel)
                    }
                }
            }
            
            // Bottom Controls Deck: Bookmark (Left) + Red Circle Stop (Right) - Scaled Elegantly
            HStack(spacing: 18) {
                // Bookmark / Tag Button
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .medium)
                    gen.impactOccurred()
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        bookmarkFeedbackTrigger = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        bookmarkFeedbackTrigger = false
                    }
                    onBookmarkTap?()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(white: 0.16))
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: bookmarkFeedbackTrigger ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(bookmarkFeedbackTrigger ? Color(red: 0.98, green: 0.88, blue: 0.20) : .white)
                            .scaleEffect(bookmarkFeedbackTrigger ? 1.2 : 1.0)
                    }
                }
                .buttonStyle(.plain)
                
                // Stop Recording Button
                Button {
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.warning)
                    onStopTap?()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded = false
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.94, green: 0.28, blue: 0.22))
                            .frame(width: 42, height: 42)
                            .shadow(color: Color(red: 0.94, green: 0.28, blue: 0.22).opacity(0.35), radius: 4, x: 0, y: 1)
                        
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 12, height: 12)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .frame(width: 330)
        .background(Color.black)
        .cornerRadius(34)
        .overlay(
            RoundedRectangle(cornerRadius: 38)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.85), radius: 24, x: 0, y: 12)
    }
    
    // MARK: - Helpers
    private func toggleExpandedState() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            isExpanded.toggle()
        }
    }
    
    private func startBreathingAnimation() {
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
    
    private func segmentColor(for index: Int, isActive: Bool) -> Color {
        guard isActive else {
            return Color(white: 0.2) // Inactive dark gray pill
        }
        
        if index < 6 {
            return Color(red: 0.19, green: 0.82, blue: 0.35) // Vibrant Green
        } else if index < 8 {
            return Color(red: 1.0, green: 0.84, blue: 0.04)  // Amber Gold
        } else {
            return Color(red: 0.95, green: 0.26, blue: 0.21) // Warning Red
        }
    }
    
    private func formattedDuration(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Preview Provider
#Preview {
    ZStack {
        Color(white: 0.1).ignoresSafeArea()
        
        VStack(spacing: 40) {
            Text("Figma Dynamic Island Prototype")
                .foregroundColor(.white)
                .font(.headline)
            
            DynamicIslandRecordingView(
                isRecording: .constant(true),
                durationSeconds: .constant(48),
                sessionTitle: "Dance Training Hall 4",
                liveAudioLevel: 0.72
            )
        }
    }
}
