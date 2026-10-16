import SwiftData
import SwiftUI

// MARK: - Časová os figúry (Premium)
/// Every take of one figure by the day it was filmed, so progress is visible: "pred 3 mesiacmi a dnes" in one
/// tap, or any two takes side by side in the comparison. Takes are remembered from now on whenever a new video
/// replaces the figure's video (camera or Fotky); the current video is always part of the line.
extension CanvasNode {
    /// Keeps a new video of this figure in its timeline. The date is when it was filmed when Fotky knows it.
    func recordTake(_ path: String, in context: ModelContext) {
        guard !mediaVault.contains(where: { $0.filePath == path }) else { return }
        let entry = VideoMediaEntry(filePath: path, title: figureName, role: .myTake,
                                    createdAt: PhotoLibraryVideoStore.creationDate(of: path) ?? Date())
        entry.canvasNode = self
        context.insert(entry)
        try? context.save()
    }

    /// How many takes the line has, without asking Fotky for dates (cheap enough for every redraw).
    var timelineTakeCount: Int {
        let paths = Set(mediaVault.filter { $0.role == .myTake }.map(\.filePath))
        return paths.count + (videoPath.map { paths.contains($0) ? 0 : 1 } ?? 0)
    }

    /// The figure's takes, oldest first; the current video is added when it was never recorded as a take.
    var timelineTakes: [FigureTake] {
        var takes = mediaVault
            .filter { $0.role == .myTake && !MediaResolver.isImagePath(path: $0.filePath) }
            .map { FigureTake(path: $0.filePath, date: $0.createdAt, entryId: $0.id) }
        if let current = videoPath, !MediaResolver.isImagePath(path: current),
           !takes.contains(where: { $0.path == current }) {
            takes.append(FigureTake(path: current, date: PhotoLibraryVideoStore.creationDate(of: current), entryId: nil))
        }
        return takes.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }
}

struct FigureTake: Identifiable, Equatable {
    let path: String
    /// Nil for an older current video whose filming date is unknown.
    let date: Date?
    let entryId: UUID?
    var id: String { path }

    /// "14. 10." for the comparison slots.
    var shortTitle: String {
        date?.formatted(.dateTime.day().month(.defaultDigits).locale(Locale(identifier: "sk"))) ?? "Aktuálne"
    }
}

struct FigureTimelineView: View {
    @Bindable var node: CanvasNode
    var onSaveCorrection: ((FigureCorrection) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selected: [String] = []
    @State private var comparison: TakePair?

    private struct TakePair: Identifiable {
        let newer: FigureTake
        let older: FigureTake
        var id: String { newer.id + older.id }
    }

    var body: some View {
        let takes = node.timelineTakes
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if takes.count < 2 {
                            hint(takes.isEmpty
                                 ? "Figúra zatiaľ nemá video. Natoč ju a pri každom ďalšom natočení sa nový záber pridá sem."
                                 : "Zatiaľ je tu jeden záber. Keď figúru natočíš znova, uvidíš tu oba a porovnáš ich jedným ťuknutím.")
                        } else {
                            firstAndLastButton(takes)
                        }
                        ForEach(takes.reversed()) { take in
                            takeRow(take, isCurrent: take.path == node.videoPath)
                        }
                        if takes.count >= 2 {
                            Text("Vyber dva zábery a porovnaj ich vedľa seba.")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if selected.count == 2 {
                    PrimarySheetButton(title: "Porovnať vybrané", isLoading: false, isEnabled: true) { compareSelected(takes) }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selected)
            .navigationTitle(node.figureName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zavrieť") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: selected)
        .fullScreenCover(item: $comparison) { pair in
            DualVideoComparisonView(
                pathA: .constant(pair.newer.path),
                pathB: .constant(pair.older.path),
                titleA: pair.newer.shortTitle,
                titleB: pair.older.shortTitle,
                figureName: node.figureName,
                onSaveCorrection: onSaveCorrection
            )
        }
    }

    private func firstAndLastButton(_ takes: [FigureTake]) -> some View {
        Button {
            if let first = takes.first, let last = takes.last { comparison = TakePair(newer: last, older: first) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3.weight(.bold))
                    .foregroundColor(Color.obsidian900)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prvý a posledný záber")
                        .font(.headline)
                        .foregroundColor(Color.obsidian900)
                    if let first = takes.first?.date {
                        Text("\(PlannerCalendar.daysText(until: first)) a teraz, vedľa seba")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color.obsidian900.opacity(0.7))
                    }
                }
                Spacer()
            }
            .padding(16)
            .background(LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.pressable(scale: 0.97))
    }

    private func takeRow(_ take: FigureTake, isCurrent: Bool) -> some View {
        let isSelected = selected.contains(take.path)
        return Button { toggle(take) } label: {
            HStack(spacing: 12) {
                MediaThumbnailView(path: take.path, cornerRadius: 10)
                    .frame(width: 72, height: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text(take.date?.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "sk"))) ?? "Dátum neznámy")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    if let date = take.date {
                        Text(PlannerCalendar.daysText(until: date))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                Spacer()
                if isCurrent {
                    Text("Aktuálne")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(Color.gold300)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gold500.opacity(0.14), in: Capsule())
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? Color.gold400 : .white.opacity(0.3))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(12)
            .homeCard(cornerRadius: 18)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.gold400.opacity(0.6) : .clear, lineWidth: 1))
        }
        .buttonStyle(.pressable(scale: 0.98))
        .contextMenu {
            if !isCurrent {
                Button { setCurrent(take) } label: { Label("Použiť ako video figúry", systemImage: "checkmark.circle") }
            }
            if let entryId = take.entryId, !isCurrent {
                Button(role: .destructive) { removeFromTimeline(entryId) } label: {
                    Label("Odstrániť z časovej osi", systemImage: "minus.circle")
                }
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCard(cornerRadius: 20)
    }

    private func toggle(_ take: FigureTake) {
        if let index = selected.firstIndex(of: take.path) {
            selected.remove(at: index)
        } else {
            if selected.count == 2 { selected.removeFirst() }
            selected.append(take.path)
        }
    }

    private func compareSelected(_ takes: [FigureTake]) {
        let picked = takes.filter { selected.contains($0.path) }
        guard picked.count == 2 else { return }
        comparison = TakePair(newer: picked[1], older: picked[0])
    }

    /// An older take becomes the figure's video again; the timeline keeps every take.
    private func setCurrent(_ take: FigureTake) {
        if let current = node.videoPath { node.recordTake(current, in: modelContext) }
        node.videoPath = take.path
        try? modelContext.save()
    }

    /// Only the line forgets it; the video stays in Fotky.
    private func removeFromTimeline(_ entryId: UUID) {
        guard let entry = node.mediaVault.first(where: { $0.id == entryId }) else { return }
        selected.removeAll { $0 == entry.filePath }
        modelContext.delete(entry)
        try? modelContext.save()
    }
}
