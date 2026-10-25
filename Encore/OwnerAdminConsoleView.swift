import SwiftUI
import Supabase
import OSLog

// MARK: - Owner Admin Console
/// Gift a plan, find a dancer, ban or unban an account or delete it. Only the owner sees it (server `is_app_owner()`),
/// and every action is checked again on the server (RLS and owner functions), so the screen grants nothing
/// by itself. Moderation tool for App Review 1.2; described in the review notes (2.5.19).
struct OwnerAdminConsoleView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var authManager = AuthManager.shared

    enum Mode: Hashable { case search, email }

    @State private var mode: Mode = .search
    @State private var directEmail = ""
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchFailed = false
    @State private var searchResults: [AdminUserSearchItem] = []
    @State private var selectedUserId: UUID?

    @State private var grantTier: SubscriptionTier = .premium
    @State private var grantDurationMonths = 0   // 0 = navždy
    @State private var grantNote = "Darované od majiteľa"
    @State private var isActionInProgress = false
    @State private var statusMessage: String?
    @State private var successCount = 0

    @State private var banReasonText = "Porušenie pravidiel komunity"
    @State private var userToBan: AdminUserSearchItem?
    @State private var userToDelete: AdminUserSearchItem?
    /// Dancers who picked themselves in the KSIS members list and wait to be verified.
    @State private var dancersToVerify: [KSISDancer] = []
    /// Account name and e-mail of each of them, to compare with the KSIS name.
    @State private var accounts: [UUID: String] = [:]

    private var selectedUser: AdminUserSearchItem? {
        searchResults.first { $0.id == selectedUserId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ownerHeader
                        if !dancersToVerify.isEmpty { dancersSection }
                        PlannerChoice(options: [(Mode.search, "Hľadať človeka"), (Mode.email, "Podľa e-mailu")],
                                      selection: $mode)
                        if mode == .search {
                            searchSection
                            if let user = selectedUser {
                                userCard(user)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        } else {
                            emailGrantSection
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: mode)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedUserId)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Majiteľská konzola")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavrieť") { dismiss() }
                }
            }
            .alert("Konzola", isPresented: Binding(get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(statusMessage ?? "")
            }
            .confirmationDialog(
                "Zablokovať účet?",
                isPresented: Binding(get: { userToBan != nil }, set: { if !$0 { userToBan = nil } }),
                titleVisibility: .visible,
                presenting: userToBan
            ) { user in
                Button("Zablokovať \(user.name)", role: .destructive) { setBan(true, for: user) }
                Button("Zrušiť", role: .cancel) {}
            } message: { _ in
                Text("Odhlási sa na všetkých zariadeniach a už sa neprihlási. Dá sa to vrátiť tlačidlom Odblokovať.")
            }
            .sheet(item: $userToDelete) { user in
                OwnerDeleteAccountSheet(user: user) {
                    selectedUserId = nil
                    statusMessage = "Účet \(user.name) je zmazaný."
                    successCount += 1
                    Task { await search() }
                }
            }
            .task { await loadDancersToVerify() }
            .task(id: searchQuery) {
                // Searches as you type, after a short pause (a new letter cancels the previous search).
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                await search()
            }
            .sensoryFeedback(.success, trigger: successCount)
            .sensoryFeedback(.selection, trigger: selectedUserId)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Header
    private var ownerHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.title3)
                .foregroundColor(Color.gold400)
                .frame(width: 48, height: 48)
                .background(Color.gold500.opacity(0.16), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("MAJITEĽ")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .tracking(1.4)
                    .foregroundColor(Color.gold400)
                Text(authManager.userEmail)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(16)
        .homeCard(cornerRadius: 20)
    }

    // MARK: Search
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "POUŽÍVATELIA", systemImage: "magnifyingglass")
            PlannerTextField(placeholder: "Meno, ID tanečníka, klub alebo e-mail", text: $searchQuery,
                             systemImage: "magnifyingglass")
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if isSearching {
                ProgressView()
                    .tint(Color.gold400)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if searchFailed {
                hint("Vyhľadávanie zlyhalo. Skontroluj pripojenie.")
            } else if hasSearched && searchResults.isEmpty {
                hint("Nikto sa nenašiel.")
            }
            ForEach(searchResults) { item in
                resultRow(item)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
    }

    private func resultRow(_ item: AdminUserSearchItem) -> some View {
        let isOn = item.id == selectedUserId
        return Button {
            selectedUserId = isOn ? nil : item.id
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    Text([item.dancerCode, item.club, item.email].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if item.isBanned {
                    badge("ZABLOKOVANÝ", color: Color.latinRed)
                } else if item.tier != .free {
                    badge(item.tier.title.uppercased(), color: Color.gold400)
                }
            }
            .padding(12)
            .homeCard(cornerRadius: 16)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isOn ? Color.gold400.opacity(0.55) : .clear, lineWidth: 1))
        }
        .buttonStyle(.pressable(scale: 0.98))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: Selected user
    private func userCard(_ user: AdminUserSearchItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                Text(user.planText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.gold300)
                Text(user.id.uuidString)
                    .font(.caption2.monospaced())
                    .foregroundColor(.white.opacity(0.45))
                    .textSelection(.enabled)
            }

            HomeSectionHeader(title: "DAROVAŤ PLÁN", systemImage: "gift.fill")
            grantForm(actionTitle: "Udeliť \(user.name)") { grant(to: user) }

            HomeSectionHeader(title: "MODERÁCIA", systemImage: "shield.lefthalf.filled")
            if user.isBanned {
                Button { setBan(false, for: user) } label: {
                    Label("Odblokovať účet", systemImage: "lock.open.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.pressable(scale: 0.97))
                .disabled(isActionInProgress)
            } else {
                PlannerTextField(placeholder: "Dôvod zablokovania", text: $banReasonText, systemImage: "text.bubble")
                Button { userToBan = user } label: {
                    Label("Zablokovať účet", systemImage: "slash.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color.latinRed)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.latinRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.latinRed.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.pressable(scale: 0.97))
                .disabled(isActionInProgress || user.id == authManager.currentUser?.id)
            }
            Button { userToDelete = user } label: {
                Label("Zmazať účet natrvalo", systemImage: "trash.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Color.latinRed)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.pressable(scale: 0.97))
            .disabled(isActionInProgress || user.id == authManager.currentUser?.id)
        }
        .padding(16)
        .homeCard(cornerRadius: 20)
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.gold400.opacity(0.35), lineWidth: 1))
    }

    // MARK: E-mail
    private var emailGrantSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "DAROVAŤ PODĽA E-MAILU", systemImage: "envelope.fill")
            Text("Pre kamaráta, partnerku alebo trénera, ktorí už majú účet v Encore. Plán sa im odomkne hneď, bez platby.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
            PlannerTextField(placeholder: "meno@domena.sk", text: $directEmail, systemImage: "envelope")
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            grantForm(actionTitle: "Udeliť plán",
                      isEnabled: !directEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) { grantByEmail() }
        }
    }

    // MARK: Grant form (shared)
    private func grantForm(actionTitle: String, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            PlannerChoice(options: [(SubscriptionTier.premium, "Premium"), (.plus, "Plus"), (.free, "Zrušiť")],
                          selection: $grantTier)
            if grantTier != .free {
                PlannerChoice(options: [(0, "Navždy"), (12, "1 rok"), (6, "6 mes."), (1, "1 mes.")],
                              selection: $grantDurationMonths)
                    .transition(.opacity)
            }
            PlannerTextField(placeholder: "Poznámka (napr. partnerka, tréner)", text: $grantNote, systemImage: "note.text")
            PrimarySheetButton(title: grantTier == .free ? "Zrušiť darovaný plán" : actionTitle,
                               isLoading: isActionInProgress, isEnabled: isEnabled && !isActionInProgress, action: action)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: grantTier)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(.white.opacity(0.65))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(.caption2, design: .rounded).weight(.black))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }

    // MARK: - KSIS verification
    private var dancersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "OVERENIE TANEČNÍKOV", systemImage: "person.badge.shield.checkmark", count: dancersToVerify.count)
            ForEach(dancersToVerify) { dancer in
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(dancer.name) · č. \(dancer.personNumber)")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    Text(["Účet: \(accounts[dancer.userId] ?? "bez mena")", dancer.club.map { "KSIS: \($0)" }]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        PrimarySheetButton(title: "Overiť", isLoading: false, isEnabled: !isActionInProgress) {
                            decide(dancer, approve: true)
                        }
                        Button { decide(dancer, approve: false) } label: {
                            Text("Zamietnuť")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(Color.latinRed)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Color.latinRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.pressable(scale: 0.97))
                        .disabled(isActionInProgress)
                    }
                }
                .padding(14)
                .homeCard(cornerRadius: 18)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: dancersToVerify.map(\.id))
    }

    /// The owner reads every dancer and profile (RLS ksis_dancers_read, profiles).
    private func loadDancersToVerify() async {
        struct Account: Decodable {
            let id: UUID
            let name: String?
            let full_name: String?
            let email: String?
        }
        do {
            let client = SupabaseConfig.client
            let dancers: [KSISDancer] = try await client
                .from("ksis_dancers")
                .select("user_id, person_number, name, club, status, created_at")
                .eq("status", value: "pending")
                .order("created_at")
                .execute()
                .value
            let found: [Account] = dancers.isEmpty ? [] : try await client
                .from("profiles")
                .select("id, name, full_name, email")
                .in("id", values: dancers.map(\.userId))
                .execute()
                .value
            accounts = Dictionary(found.map { account in
                (account.id, [account.name ?? account.full_name, account.email].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
            }, uniquingKeysWith: { first, _ in first })
            dancersToVerify = dancers
        } catch {
            Logger.general.error("Loading dancers to verify failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func decide(_ dancer: KSISDancer, approve: Bool) {
        perform {
            struct Params: Encodable { let p_user: UUID; let p_approve: Bool }
            do {
                try await SupabaseConfig.client
                    .rpc("owner_decide_dancer", params: Params(p_user: dancer.userId, p_approve: approve))
                    .execute()
            } catch let error as PostgrestError where error.code == "23505" {
                throw OwnerConsoleError.dancerTaken
            }
            await loadDancersToVerify()
            return approve ? "\(dancer.name) je overený." : "Žiadosť je zamietnutá."
        }
    }

    // MARK: - Search
    /// Name (both name columns), dancer ID, club or e-mail; the owner may read every profile (RLS).
    private func search() async {
        // Characters that would change the PostgREST filter instead of being searched for.
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !",()*%\\\"".contains($0) }
        guard query.count >= 2 else {
            searchResults = []
            hasSearched = false
            searchFailed = false
            return
        }
        isSearching = true
        defer { isSearching = false }
        let client = SupabaseConfig.client

        struct ProfileDTO: Decodable {
            let id: UUID
            let name: String?
            let full_name: String?
            let club: String?
            let dancer_code: String?
            let email: String?
            let account_status: String?
        }
        struct EntitlementDTO: Decodable {
            let user_id: UUID
            let tier: String
            let expires_at: Date?
        }

        do {
            let profiles: [ProfileDTO] = try await client
                .from("profiles")
                .select("id, name, full_name, club, dancer_code, email, account_status")
                .or(["name", "full_name", "dancer_code", "club", "email"].map { "\($0).ilike.%\(query)%" }.joined(separator: ","))
                .limit(20)
                .execute()
                .value
            let entitlements: [EntitlementDTO] = profiles.isEmpty ? [] : try await client
                .from("user_entitlements")
                .select("user_id, tier, expires_at")
                .in("user_id", values: profiles.map(\.id))
                .execute()
                .value
            let plans = Dictionary(entitlements.map { ($0.user_id, $0) }, uniquingKeysWith: { first, _ in first })

            guard !Task.isCancelled else { return }
            searchResults = profiles.map { profile in
                let plan = plans[profile.id]
                let expired = plan?.expires_at.map { $0 < Date() } ?? false
                return AdminUserSearchItem(
                    id: profile.id,
                    name: profile.name ?? profile.full_name ?? "Tanečník",
                    club: profile.club,
                    dancerCode: profile.dancer_code,
                    email: profile.email,
                    isBanned: profile.account_status == "banned",
                    tier: expired ? .free : plan.flatMap { SubscriptionTier(serverValue: $0.tier) } ?? .free,
                    expiresAt: expired ? nil : plan?.expires_at
                )
            }
            hasSearched = true
            searchFailed = false
        } catch {
            guard !Task.isCancelled else { return }
            Logger.general.error("Admin search failed: \(error.localizedDescription, privacy: .public)")
            searchFailed = true
        }
    }

    // MARK: - Actions
    private func grantByEmail() {
        let email = directEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return }
        perform {
            let message = try await subscriptionManager.grantEntitlementByEmailAsOwner(
                targetEmail: email, tier: grantTier,
                durationMonths: grantDurationMonths == 0 ? nil : grantDurationMonths, notes: grantNote)
            directEmail = ""
            return message
        }
    }

    private func grant(to user: AdminUserSearchItem) {
        perform {
            try await subscriptionManager.grantEntitlementAsOwner(
                targetUserId: user.id, tier: grantTier,
                durationMonths: grantDurationMonths == 0 ? nil : grantDurationMonths, notes: grantNote)
            return grantTier == .free ? "\(user.name) už nemá darovaný plán." : "\(user.name) má teraz \(grantTier.title)."
        }
    }

    private func setBan(_ banned: Bool, for user: AdminUserSearchItem) {
        perform {
            try await subscriptionManager.setAccountBanStatusAsOwner(
                targetUserId: user.id, isBanned: banned, reason: banned ? banReasonText : "")
            return banned ? "Účet \(user.name) je zablokovaný." : "Účet \(user.name) je odblokovaný."
        }
    }

    /// Runs one owner action, shows its result and reloads the list, so the card shows the new state.
    private func perform(_ action: @escaping () async throws -> String) {
        isActionInProgress = true
        Task {
            defer { isActionInProgress = false }
            do {
                statusMessage = try await action()
                successCount += 1
                await search()
            } catch {
                statusMessage = "Nepodarilo sa: \(error.localizedDescription)"
            }
        }
    }
}

private enum OwnerConsoleError: LocalizedError {
    case dancerTaken
    var errorDescription: String? { "tohto tanečníka už má overený iný účet." }
}

// MARK: - Admin User Search Item
struct AdminUserSearchItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let club: String?
    let dancerCode: String?
    let email: String?
    let isBanned: Bool
    /// The plan from `user_entitlements` (gift or App Store record); Free when none or expired.
    let tier: SubscriptionTier
    let expiresAt: Date?

    var planText: String {
        guard tier != .free else { return "Plán: Free" }
        guard let expiresAt else { return "Plán: \(tier.title), navždy" }
        return "Plán: \(tier.title) do \(expiresAt.formatted(.dateTime.day().month().year().locale(Locale(identifier: "sk"))))"
    }
}
