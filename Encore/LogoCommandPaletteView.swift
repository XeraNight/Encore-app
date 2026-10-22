import SwiftUI

// MARK: - Interactive Logo Command Palette Sheet
struct LogoCommandPaletteView: View {
    @Binding var isPresented: Bool
    let onSelectNewRoutine: () -> Void
    let onSelectCompare: () -> Void
    let onSelectLibrary: () -> Void
    let onSelectCanvas: () -> Void
    let onSelectCamera: () -> Void
    let onSelectScanQR: () -> Void
    let onSelectRoutine: (Routine) -> Void
    
    let routines: [Routine]
    let allFigures: [FigureLibraryItem]
    
    @State private var searchQuery: String = ""
    
    var filteredRoutines: [Routine] {
        if searchQuery.isEmpty { return routines }
        return routines.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.danceName.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    var filteredFigures: [FigureLibraryItem] {
        if searchQuery.isEmpty { return [] }
        return allFigures.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.danceName.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.obsidian900.ignoresSafeArea()
                
                GeometryReader { geo in
                    let autoSidePadding = max(geo.size.width * 0.08, 20)
                    
                    VStack(spacing: 16) {
                        
                        // Search Header Bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color.gold400)
                            
                            TextField("Hľadať akcie, zostavy alebo figúry...", text: $searchQuery)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                            
                            if !searchQuery.isEmpty {
                                Button {
                                    searchQuery = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color.white.opacity(0.4))
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.themeCard)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.gold400.opacity(0.30), lineWidth: 1)
                        )
                        .padding(.horizontal, autoSidePadding)
                        .padding(.top, 16)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                
                                // Primary Commands Grid
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("HLAVNÉ PRÍKAZY")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(Color.white.opacity(0.4))
                                        .tracking(1.2)
                                    
                                    VStack(spacing: 8) {
                                        commandRow(icon: "plus.circle.fill", title: "Nová choreografia", subtitle: "Založiť zostavu na plátne", color: Color.gold500) {
                                            isPresented = false
                                            onSelectNewRoutine()
                                        }
                                        
                                        commandRow(icon: "arrow.left.and.right.square.fill", title: "Porovnať videá", subtitle: "Moje video a vzor vedľa seba", color: Color.standardBlue) {
                                            isPresented = false
                                            onSelectCompare()
                                        }
                                        
                                        commandRow(icon: "square.grid.2x2.fill", title: "Zostavy", subtitle: "Zobraziť všetky zostavy", color: Color.latinPink) {
                                            isPresented = false
                                            onSelectCanvas()
                                        }
                                        
                                        commandRow(icon: "books.vertical.fill", title: "Knižnica a Figúry", subtitle: "Register krokov a techniky", color: Color.syncEmerald) {
                                            isPresented = false
                                            onSelectLibrary()
                                        }
                                        
                                        commandRow(icon: "video.fill", title: "Kamera & Spomalené zábery", subtitle: "Natočiť nový tréningový záznam", color: Color.gold400) {
                                            isPresented = false
                                            onSelectCamera()
                                        }
                                        
                                        commandRow(icon: "qrcode.viewfinder", title: "Skenovať QR kód", subtitle: "Naimportovať zostavu od partnera", color: Color.white.opacity(0.7)) {
                                            isPresented = false
                                            onSelectScanQR()
                                        }
                                    }
                                }
                                
                                // Matching Routines
                                if !filteredRoutines.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("ZODPOVEDAJÚCE ZOSTAVY (\(filteredRoutines.count))")
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundColor(Color.white.opacity(0.4))
                                            .tracking(1.2)
                                        
                                        ForEach(filteredRoutines.prefix(5)) { routine in
                                            Button {
                                                isPresented = false
                                                onSelectRoutine(routine)
                                            } label: {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(routine.name)
                                                            .font(.system(size: 14, weight: .bold))
                                                            .foregroundColor(.white)
                                                        Text("\(routine.danceName) • \(routine.canvasNodes.count) figúr")
                                                            .font(.system(size: 11))
                                                            .foregroundColor(Color.textSecondary)
                                                    }
                                                    Spacer()
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(Color.gold400)
                                                }
                                                .padding(12)
                                                .background(Color.themeCard.opacity(0.7))
                                                .cornerRadius(12)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                
                                // Matching Figures from Library (if searching)
                                if !filteredFigures.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("NÁJDENÉ FIGÚRY V KNIŽNICI (\(filteredFigures.count))")
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundColor(Color.white.opacity(0.4))
                                            .tracking(1.2)
                                        
                                        ForEach(filteredFigures.prefix(6)) { fig in
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(fig.name)
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundColor(.white)
                                                    Text("\(fig.danceName) • \(fig.rhythm)")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(Color.gold400)
                                                }
                                                Spacer()
                                            }
                                            .padding(12)
                                            .background(Color.themeCard.opacity(0.5))
                                            .cornerRadius(10)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, autoSidePadding)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationTitle("Rýchle hľadanie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavrieť") { isPresented = false }
                        .foregroundColor(Color.gold400)
                }
            }
        }
    }
    
    private func commandRow(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Color.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            .padding(12)
            .background(Color.themeCard)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
