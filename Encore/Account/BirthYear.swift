import SwiftUI

// MARK: - Birth year
/// Only the year is kept (`profiles.birth_year`). Whoever may still be under 16 is found only by the dancer ID or the
/// QR code (`search_dancers`), and a parent agrees at sign-up: Slovakia keeps the GDPR age of 16 (art. 8).
enum BirthYear {
    static var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    /// Newest first: people look for their own year from the top.
    static var choices: [Int] { Array((currentYear - 100)...(currentYear - 5)).reversed() }

    /// Born after (this year − 17) may still be 15 today. The server's name search uses the same line.
    static func needsParentConsent(_ year: Int) -> Bool { year > currentYear - 17 }

    static func isComplete(_ year: Int?, parentConsent: Bool) -> Bool {
        guard let year else { return false }
        return !needsParentConsent(year) || parentConsent
    }
}

/// The year, and under 16 the parent's consent. Used at sign-up and when an account has no year yet.
struct BirthYearField: View {
    @Binding var year: Int?
    @Binding var parentConsent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.gold400)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text("Rok narodenia")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer(minLength: 8)
                Picker("Rok narodenia", selection: $year.animation(.spring(response: 0.35, dampingFraction: 0.85))) {
                    Text("Vyber").tag(Int?.none)
                    ForEach(BirthYear.choices, id: \.self) { choice in
                        Text(String(choice)).tag(Int?.some(choice))
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.gold400)
                .labelsHidden()
            }
            .frame(minHeight: 44)
            .sensoryFeedback(.selection, trigger: year)

            if let year, BirthYear.needsParentConsent(year) {
                PlannerToggleRow(
                    title: "Rodič alebo zákonný zástupca súhlasí",
                    subtitle: "Pod 16 rokov to vyžaduje zákon. Podľa mena ťa nikto nenájde, len cez ID tanečníka alebo QR kód.",
                    systemImage: "figure.and.child.holdinghands",
                    isOn: $parentConsent
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

/// Asked once of an account without a year (Apple, Google, accounts from before). "Neskôr" keeps it hidden from the
/// name search until the year is given.
struct BirthYearSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileStore = UserProfileStore.shared
    @State private var year: Int?
    @State private var parentConsent = false
    @State private var isSaving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                VStack(alignment: .leading, spacing: 18) {
                    Text("Podľa veku nastavíme, kto ťa môže v Encore nájsť. Ukladáme iba rok a zmeniť sa nedá.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    BirthYearField(year: $year, parentConsent: $parentConsent)
                        .padding(14)
                        .homeCard(cornerRadius: 18)
                    if let errorText {
                        Text(errorText)
                            .font(.footnote.weight(.medium))
                            .foregroundColor(.latinRed)
                    }
                    Spacer()
                    PrimarySheetButton(title: "Uložiť", isLoading: isSaving,
                                       isEnabled: BirthYear.isComplete(year, parentConsent: parentConsent), action: save)
                }
                .padding(20)
            }
            .navigationTitle("Rok narodenia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Neskôr") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard let year else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await profileStore.setBirthYear(year)
                dismiss()
            } catch {
                errorText = "Rok sa nepodarilo uložiť. Skontroluj pripojenie a skús to znova."
            }
        }
    }
}
