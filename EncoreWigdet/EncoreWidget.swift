import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

@main
struct EncoreWidgetBundle: WidgetBundle {
    var body: some Widget {
        EncoreLiveActivity()
        RecordingLiveActivity()
        EncoreVideoControl()
        EncoreVoiceControl()
        EncoreTextControl()
        EncoreKSISControl()
    }
}

// MARK: - 1. Live Recording Activity (Dynamic Island & Lock Screen matching Photo 1)
struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            RecordingLockScreenView(context: context)
                .activityBackgroundTint(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Leading (Top Left of island)
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(red: 1.0, green: 0.27, blue: 0.23))
                                .frame(width: 8, height: 8)
                            Text("REC")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(Color(red: 1.0, green: 0.27, blue: 0.23))
                        }
                        
                        Text(context.state.sessionTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.60))
                            .lineLimit(1)
                    }
                    .padding(.leading, 6)
                    .padding(.top, 4)
                }

                // Expanded Trailing (Top Right of island)
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startDate...Date.distantFuture, countsDown: false)
                        .font(.system(size: 24, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .padding(.trailing, 6)
                        .padding(.top, 4)
                }

                // Expanded Bottom (Full width controls & 11-segment VU meter)
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        // Section: HALL AMBIENT LEVEL & ACTIVE SYNC
                        VStack(spacing: 6) {
                            HStack {
                                Text("HALL AMBIENT LEVEL")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(Color.white.opacity(0.55))
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
                                    let isActive = context.state.audioLevel >= threshold
                                    
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(segmentColor(for: index, isActive: isActive))
                                        .frame(height: 8)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(.horizontal, 6)

                        // Bottom Actions: Centered Bookmark (Left) + Red Circle Stop (Right) - Scaled Elegantly
                        HStack(spacing: 18) {
                            if #available(iOSApplicationExtension 17.0, *) {
                                Button(intent: BookmarkRecordingIntent()) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(white: 0.16))
                                            .frame(width: 38, height: 38)
                                        
                                        Image(systemName: "bookmark")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .buttonStyle(.plain)

                                Button(intent: StopRecordingIntent()) {
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
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 2)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.27, blue: 0.23))
                        .frame(width: 6, height: 6)
                    Text("REC")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 1.0, green: 0.27, blue: 0.23))
                }
            } compactTrailing: {
                Text(timerInterval: context.state.startDate...Date.distantFuture, countsDown: false)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .frame(width: 36)
            } minimal: {
                Circle()
                    .fill(Color(red: 1.0, green: 0.27, blue: 0.23))
                    .frame(width: 8, height: 8)
            }
            .keylineTint(Color(red: 1.0, green: 0.84, blue: 0.04))
        }
    }
}

private func segmentColor(for index: Int, isActive: Bool) -> Color {
    guard isActive else { return Color(white: 0.16) }
    if index < 5 {
        return Color(red: 0.19, green: 0.82, blue: 0.35) // 5 green
    } else if index < 8 {
        return Color(red: 1.0, green: 0.84, blue: 0.04)  // 3 yellow
    } else {
        return Color(red: 0.95, green: 0.26, blue: 0.21)  // 3 red
    }
}

// MARK: - Lock Screen Recording Banner
private struct RecordingLockScreenView: View {
    let context: ActivityViewContext<RecordingActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
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
                    Text(context.state.sessionTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer()

                Text(timerInterval: context.state.startDate...Date.distantFuture, countsDown: false)
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }

            // VU Meter
            VStack(spacing: 6) {
                HStack {
                    Text("HALL AMBIENT LEVEL")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(Color.white.opacity(0.55))
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

                HStack(spacing: 4) {
                    ForEach(0..<11, id: \.self) { index in
                        let threshold = Float(index + 1) / 11.0
                        let isActive = context.state.audioLevel >= threshold
                        
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(segmentColor(for: index, isActive: isActive))
                            .frame(height: 8)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            // Bottom Actions: Scaled Elegantly
            HStack(spacing: 18) {
                if #available(iOSApplicationExtension 17.0, *) {
                    Button(intent: BookmarkRecordingIntent()) {
                        ZStack {
                            Circle()
                                .fill(Color(white: 0.16))
                                .frame(width: 38, height: 38)
                            
                            Image(systemName: "bookmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    Button(intent: StopRecordingIntent()) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.94, green: 0.28, blue: 0.22))
                                .frame(width: 42, height: 42)
                            
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.black)
    }
}

// MARK: - 2. Live Routine Training Activity (Dynamic Island & Lock Screen)
struct EncoreLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EncoreAttributes.self) { context in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tréning: \(context.attributes.routineName)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.04))
                        .textCase(.uppercase)
                    
                    Text(context.state.currentFigureName)
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(.white)
                    
                    if !context.state.nextFigureName.isEmpty {
                        Text("Nasleduje: \(context.state.nextFigureName)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.65))
                    }
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("\(context.state.currentFigureIndex) / \(context.state.totalFigures)")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.04))
                    Text("figúra")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(white: 0.12))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 1.0, green: 0.84, blue: 0.04).opacity(0.3), lineWidth: 1))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.black)
            .activityBackgroundTint(Color.black)
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.dance")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.04))
                        Text(context.attributes.danceName)
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 4)
                    .padding(.leading, 4)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.currentFigureIndex)/\(context.state.totalFigures)")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.04))
                        .padding(.top, 4)
                        .padding(.trailing, 4)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.currentFigureName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.top, 4)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if !context.state.nextFigureName.isEmpty {
                            Label(context.state.nextFigureName, systemImage: "arrow.right.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                                .lineLimit(1)
                        } else {
                            Text("Posledná figúra zostavy")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        Spacer()
                        Text(timerInterval: context.state.lastUpdated...context.state.lastUpdated.addingTimeInterval(3600), countsDown: false)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.04))
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "figure.dance")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.04))
                    Text(context.attributes.danceName.prefix(3).uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                }
            } compactTrailing: {
                Text("\(context.state.currentFigureIndex)/\(context.state.totalFigures)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.04))
            } minimal: {
                Image(systemName: "figure.dance")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.04))
            }
            .keylineTint(Color(red: 1.0, green: 0.84, blue: 0.04))
        }
    }
}

