import SwiftUI

// MARK: - Prepojenia
/// Connections, the partner, coaches and students in one place (BRAND_GUIDELINES §1A). One way in: "+" (ID
/// tanečníka), your QR code for others, or scanning theirs. A connection gives no access to the other person's
/// things; the partner (one) is chosen from the connections and shares the routines.
struct FriendsListView: View {
    @ObservedObject private var connectionManager = ConnectionManager.shared
    @ObservedObject private var friendManager = FriendManager.shared
    @ObservedObject private var profileStore = UserProfileStore.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum ConnectionTab: String, CaseIterable, Identifiable {
        case connections = "Spojenia"
        case coaches = "Tréneri"
        case students = "Zverenci"
        case requests = "Žiadosti"

        var id: String { rawValue }

        /// Coaches and students wait for the coach tools (`AppFeatures.coachTools`).
        static var visible: [ConnectionTab] {
            AppFeatures.coachTools ? allCases : [.connections, .requests]
        }
    }

    @State private var selectedTab: ConnectionTab = .connections
    @State private var searchText = ""
    @State private var showScanner = false
    @State private var showMyCard = false
    @State private var showAddConnectionSheet = false
    @State private var showPaywallSheet = false
    @Namespace private var tabNamespace

    @State private var connectionToRevoke: DancerConnection? = nil
    @State private var showRevokeConfirmation = false
    @State private var showReportFallback = false
    /// The dancer about to be blocked (App Review 1.2), from a connection or a request.
    @State private var blockTarget: DancerConnection?
    @State private var actionCount = 0
    @State private var partnerToEnd: DancerConnection?
    /// A connection who shares results, opened to read them.
    @State private var resultsOf: DancerConnection?
    @State private var errorText: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            EllegancePageBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    quickActions
                    tabsBar
                    if showsSearch { searchBar }
                    tabContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)   // clear of the tab bar
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await connectionManager.fetchAllConnections() }
        }
        .navigationTitle("Prepojenia")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddConnectionSheet = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Pridať prepojenie")
            }
        }
        .sheet(isPresented: $showMyCard) {
            myCardSheet
        }
        .sheet(isPresented: $showAddConnectionSheet) {
            AddConnectionSheetView()
        }
        .sheet(isPresented: $showPaywallSheet) {
            SubscriptionPaywallView(initialTier: .premium)
        }
        .qrScanner(isPresented: $showScanner) { scannedCode in
            handleScannedQRCode(scannedCode)
        }
        .confirmationDialog(
            "Zrušiť prepojenie?",
            isPresented: $showRevokeConfirmation,
            titleVisibility: .visible
        ) {
            if let conn = connectionToRevoke {
                Button("Zrušiť prepojenie s \(conn.otherUserName)", role: .destructive) {
                    Task {
                        try? await connectionManager.revokeConnection(connectionId: conn.id)
                        connectionToRevoke = nil
                        actionCount += 1
                    }
                }
            }
            Button("Ponechať", role: .cancel) {
                connectionToRevoke = nil
            }
        } message: {
            Text("Spojenie sa zruší. Spojiť sa môžete kedykoľvek znova.")
        }
        .confirmationDialog(
            "Zmeniť na spojenie?",
            isPresented: Binding(get: { partnerToEnd != nil }, set: { if !$0 { partnerToEnd = nil } }),
            titleVisibility: .visible,
            presenting: partnerToEnd
        ) { conn in
            Button("Zmeniť \(conn.otherUserName) na spojenie") {
                run { try await connectionManager.makePlainConnection(connectionId: conn.id) }
            }
            Button("Ponechať", role: .cancel) {}
        } message: { _ in
            Text("Ostanete spojení, len už nebudete označení ako pár.")
        }
        .sheet(item: $resultsOf) { conn in
            if let couple = connectionManager.couplesByUser[conn.otherUserId] {
                ConnectionResultsSheet(connection: conn, couple: couple)
            }
        }
        .alert("Nepodarilo sa", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
        .confirmationDialog(
            "Zablokovať?",
            isPresented: Binding(get: { blockTarget != nil }, set: { if !$0 { blockTarget = nil } }),
            titleVisibility: .visible,
            presenting: blockTarget
        ) { conn in
            Button("Zablokovať \(conn.otherUserName)", role: .destructive) {
                Task {
                    try? await connectionManager.block(conn.otherUserId)
                    actionCount += 1
                }
            }
            Button("Zrušiť", role: .cancel) {}
        } message: { _ in
            Text("Prepojenie sa zruší, nebude ti môcť poslať žiadosť a nenájdete sa vo vyhľadávaní. Nedozvie sa to. Odblokovať môžeš v časti Žiadosti.")
        }
        .alert("Nahlásenie používateľa", isPresented: $showReportFallback) {
            Button("Rozumiem", role: .cancel) {}
        } message: {
            Text("V iPhone nie je nastavená aplikácia Mail. Napíš nám na \(AppContact.supportEmail) meno a ID tanečníka a čo sa stalo. Ozveme sa čo najskôr.")
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
        .sensoryFeedback(.success, trigger: actionCount)
        .task {
            await connectionManager.fetchAllConnections()
        }
    }

    private var showsSearch: Bool {
        guard selectedTab != .requests else { return false }
        return currentList.count > 4 || !searchText.isEmpty
    }

    private var currentList: [DancerConnection] {
        switch selectedTab {
        case .connections: return connectionManager.activePartners + connectionManager.activeConnections
        case .coaches: return connectionManager.activeCoaches
        case .students: return connectionManager.activeStudents
        case .requests: return []
        }
    }

    // MARK: Quick actions
    private var quickActions: some View {
        HStack(spacing: 10) {
            actionTile("Môj QR kód", icon: "qrcode") { showMyCard = true }
            actionTile("Naskenovať QR", icon: "qrcode.viewfinder") { showScanner = true }
        }
    }

    private func actionTile(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color.gold300)
                .frame(maxWidth: .infinity, minHeight: 48)
                .homeCard(cornerRadius: 14)
        }
        .buttonStyle(.pressable)
    }

    // MARK: Tabs
    private var tabsBar: some View {
        HStack(spacing: 6) {
            ForEach(ConnectionTab.visible) { tab in
                let isSelected = selectedTab == tab
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78)) { selectedTab = tab }
                } label: {
                    HStack(spacing: 4) {
                        Text(tab.rawValue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        if tab == .requests && !connectionManager.incomingRequests.isEmpty {
                            Text("\(connectionManager.incomingRequests.count)")
                                .font(.system(.caption2, design: .rounded).weight(.black))
                                .foregroundColor(Color.obsidian900)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.gold400, in: Capsule())
                                .contentTransition(.numericText())
                        }
                    }
                    .font(.footnote.weight(isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background {
                        ZStack {
                            Capsule().fill(Color.white.opacity(0.05))
                            if isSelected {
                                Capsule()
                                    .fill(Color.white.opacity(0.14))
                                    .matchedGeometryEffect(id: "connectionTab", in: tabNamespace)
                            }
                        }
                    }
                    .overlay(Capsule().stroke(isSelected ? Color.gold400.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    // MARK: Search
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.textSecondary)
            TextField("", text: $searchText, prompt: Text("Meno, klub alebo ID tanečníka").foregroundColor(Color.textPlaceholder))
                .foregroundColor(.white)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Color.textSecondary)
                }
                .accessibilityLabel("Vymazať hľadanie")
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
        .transition(.opacity)
    }

    // MARK: Content
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .connections:
            connectionsTabContent
        case .coaches:
            connectionList(
                filtered(connections: connectionManager.activeCoaches), badge: "Tréner",
                empty: emptyStateView(
                    icon: "graduationcap.fill",
                    title: "Zatiaľ žiadny tréner",
                    subtitle: "Tréner uvidí tvoje zostavy a môže ti k figúram písať poznámky.",
                    actionTitle: "Pridať trénera"
                )
            )
        case .students:
            studentsTabContent
        case .requests:
            requestsTabContent
        }
    }

    // MARK: Connections and the partner
    @ViewBuilder
    private var connectionsTabContent: some View {
        let partners = filtered(connections: connectionManager.activePartners)
        let plain = filtered(connections: connectionManager.activeConnections)
        if partners.isEmpty && plain.isEmpty {
            emptyStateView(
                icon: "person.2.fill",
                title: "Zatiaľ žiadne spojenia",
                subtitle: "Spoj sa s kamarátmi z tanca cez QR kód alebo ID tanečníka. Svoj tanečný pár potom označíš v spojeniach.",
                actionTitle: "Pridať spojenie"
            )
        } else {
            if !partners.isEmpty {
                HomeSectionHeader(title: "PARTNER", systemImage: "figure.dance")
                    .padding(.horizontal, 4)
                if connectionManager.activePartners.count > 1 {
                    Text("Partner môže byť len jeden. Ostatných zmeň na spojenie.")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Color.latinRed)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(partners) { conn in
                    connectionRow(conn: conn)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
            if !plain.isEmpty {
                HomeSectionHeader(title: "SPOJENIA", systemImage: "person.2.fill", count: plain.count)
                    .padding(.horizontal, 4)
                    .padding(.top, partners.isEmpty ? 0 : 8)
                ForEach(plain) { conn in
                    connectionRow(conn: conn)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
        }
    }

    /// Class and points of the person's KSIS couple, and its places in the cup tables read on this iPhone.
    private func ksisLine(for conn: DancerConnection) -> String? {
        guard let couple = connectionManager.couplesByUser[conn.otherUserId] else { return nil }
        var parts = [("ŠTT", couple.stt), ("LAT", couple.lat)].compactMap { label, standing in
            standing.className.map { "\(label) \($0)" + (standing.points.map { " \($0) b" } ?? "") }
        }
        if let id = couple.coupleId { parts += SlovakCupStore.shared.places(ofCouple: id) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Runs one change and shows the server's reason when it is refused (for example a second partner).
    private func run(_ change: @escaping () async throws -> Void) {
        Task {
            do {
                try await change()
                actionCount += 1
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func connectionList(_ list: [DancerConnection], badge: String, empty: some View) -> some View {
        if list.isEmpty {
            empty
        } else {
            ForEach(list) { conn in
                connectionRow(conn: conn, badgeTitle: badge)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
    }

    // MARK: Students (Premium)
    @ViewBuilder
    private var studentsTabContent: some View {
        if !subscriptionManager.canAccessStudioRoster {
            VStack(spacing: 12) {
                Image(systemName: "person.3.sequence.fill")
                    .font(.title2)
                    .foregroundColor(Color.gold400)
                Text("Moji zverenci")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Ako tréner vidíš zostavy svojich zverencov, píšeš im poznámky k figúram a zapisuješ, čo ste robili na lekcii. Je to súčasť Premium.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                PrimarySheetButton(title: "Pozrieť Premium", isLoading: false, isEnabled: true) {
                    showPaywallSheet = true
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .homeCard(cornerRadius: 20)
        } else {
            NavigationLink {
                StudioCoachRosterView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color.obsidian900)
                        .frame(width: 36, height: 36)
                        .background(Color.gold400, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Moji zverenci")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                        Text("Zostavy, poznámky a čo ste robili naposledy")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.65))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(14)
                .homeCard(cornerRadius: 16)
            }
            .buttonStyle(.pressable)

            connectionList(
                filtered(connections: connectionManager.activeStudents), badge: "Zverenec",
                empty: emptyStateView(
                    icon: "person.3.sequence.fill",
                    title: "Zatiaľ žiadni zverenci",
                    subtitle: "Pridaj zverenca cez jeho ID tanečníka alebo QR kód.",
                    actionTitle: "Pridať zverenca"
                )
            )
        }
    }

    // MARK: Requests
    @ViewBuilder
    private var requestsTabContent: some View {
        if !connectionManager.incomingRequests.isEmpty {
            HomeSectionHeader(title: "CHCÚ SA PREPOJIŤ", count: connectionManager.incomingRequests.count)
                .padding(.horizontal, 4)
            ForEach(connectionManager.incomingRequests) { req in
                incomingRequestCard(req: req)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }

        if !connectionManager.outgoingRequests.isEmpty {
            HomeSectionHeader(title: "ČAKÁ NA POTVRDENIE", count: connectionManager.outgoingRequests.count)
                .padding(.horizontal, 4)
                .padding(.top, 8)
            ForEach(connectionManager.outgoingRequests) { req in
                outgoingRequestCard(req: req)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }

        if connectionManager.incomingRequests.isEmpty && connectionManager.outgoingRequests.isEmpty {
            emptyStateView(
                icon: "tray",
                title: "Žiadne žiadosti",
                subtitle: "Keď ti niekto pošle žiadosť o prepojenie, uvidíš ju tu.",
                actionTitle: "Pridať prepojenie"
            )
        }

        if !connectionManager.blockedDancers.isEmpty {
            HomeSectionHeader(title: "ZABLOKOVANÍ", count: connectionManager.blockedDancers.count)
                .padding(.horizontal, 4)
                .padding(.top, 8)
            ForEach(connectionManager.blockedDancers) { dancer in
                blockedRow(dancer)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
    }

    private func blockedRow(_ dancer: DancerSearchResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dancer.fullName)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                if !dancer.dancerCode.isEmpty {
                    Text(dancer.dancerCode)
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
            }
            Spacer()
            Button("Odblokovať") {
                Task {
                    try? await connectionManager.unblock(dancer.id)
                    actionCount += 1
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(Color.white.opacity(0.08), in: Capsule())
            .buttonStyle(.pressable)
        }
        .padding(12)
        .homeCard(cornerRadius: 14)
    }

    // MARK: Rows
    /// Coaches and students carry their role; connections and the partner the Spojenie / Pár tag.
    private func connectionRow(conn: DancerConnection, badgeTitle: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: conn.relationshipType.badgeIcon)
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color.gold400)
                .frame(width: 44, height: 44)
                .background(Color.gold500.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(conn.otherUserName)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if let badgeTitle {
                        Text(badgeTitle)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(Color.gold300)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gold500.opacity(0.16), in: Capsule())
                    } else {
                        pairTag(conn)
                    }
                }
                Text([conn.otherUserDancerCode, conn.otherUserClub].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
                if let ksis = ksisLine(for: conn) {
                    Label(ksis, systemImage: "chevron.right")
                        .labelStyle(TrailingIconLabel())
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.gold300)
                        .lineLimit(2)
                }
            }
            // Someone who shares results opens them; the others have nothing more to show.
            .contentShape(Rectangle())
            .onTapGesture {
                if connectionManager.couplesByUser[conn.otherUserId] != nil { resultsOf = conn }
            }

            Spacer(minLength: 4)

            Menu {
                Button(role: .destructive) {
                    connectionToRevoke = conn
                    showRevokeConfirmation = true
                } label: {
                    Label(conn.relationshipType == .connection ? "Zrušiť spojenie" : "Zrušiť prepojenie", systemImage: "person.badge.minus")
                }
                Button {
                    report(conn)
                } label: {
                    Label("Nahlásiť používateľa", systemImage: "flag")
                }
                Button(role: .destructive) {
                    blockTarget = conn
                } label: {
                    Label("Zablokovať", systemImage: "hand.raised")
                }
            } label: {
                GlassCircleLabel(icon: "ellipsis", size: 36)
            }
            .accessibilityLabel("Možnosti pre \(conn.otherUserName)")
        }
        .padding(12)
        .homeCard(cornerRadius: 16)
    }

    /// "Spojenie" or "Pár", tap to pick. Pár asks the other person, who accepts it; there is only one partner.
    private func pairTag(_ conn: DancerConnection) -> some View {
        let isPair = conn.relationshipType == .partner
        let asked = !isPair && connectionManager.outgoingRequests.contains {
            $0.otherUserId == conn.otherUserId && $0.relationshipType == .partner
        }
        return Menu {
            Button {
                if isPair { partnerToEnd = conn }
            } label: {
                Label("Spojenie", systemImage: isPair ? "person.2" : "checkmark")
            }
            Button {
                run { try await connectionManager.sendRequest(targetUserId: conn.otherUserId, type: .partner) }
            } label: {
                Label(asked ? "Pár · čaká na potvrdenie" : "Pár", systemImage: isPair ? "checkmark" : "figure.dance")
            }
            .disabled(isPair || asked || !connectionManager.activePartners.isEmpty)
        } label: {
            HStack(spacing: 3) {
                Text(isPair ? "Pár" : asked ? "Pár · čaká" : "Spojenie")
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .font(.caption2.weight(.bold))
            .foregroundColor(isPair ? Color.obsidian900 : Color.gold300)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isPair ? Color.gold400 : Color.gold500.opacity(0.16), in: Capsule())
            .contentTransition(.opacity)
        }
        .accessibilityLabel(isPair ? "Pár" : "Spojenie")
        .accessibilityHint("Vyber, či je to tvoj tanečný pár")
    }

    private func incomingRequestCard(req: DancerConnection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "envelope.badge.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Color.gold400)
                    .frame(width: 42, height: 42)
                    .background(Color.gold500.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(req.otherUserName)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    Text(req.relationshipType.requestText)
                        .font(.caption)
                        .foregroundColor(Color.gold300)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Menu {
                    Button {
                        report(req)
                    } label: {
                        Label("Nahlásiť používateľa", systemImage: "flag")
                    }
                    Button(role: .destructive) {
                        blockTarget = req
                    } label: {
                        Label("Zablokovať", systemImage: "hand.raised")
                    }
                } label: {
                    GlassCircleLabel(icon: "ellipsis", size: 36)
                }
                .accessibilityLabel("Možnosti pre \(req.otherUserName)")
            }

            HStack(spacing: 10) {
                Button {
                    Task {
                        do {
                            try await connectionManager.acceptRequest(connectionId: req.id)
                            actionCount += 1
                        } catch {
                            errorText = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Prijať", systemImage: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(Color.obsidian900)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Color.gold400, in: Capsule())
                }
                .buttonStyle(.pressable)

                Button {
                    Task { try? await connectionManager.rejectRequest(connectionId: req.id) }
                } label: {
                    Text("Odmietnuť")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Color.white.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(14)
        .homeCard(cornerRadius: 16)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.gold400.opacity(0.35), lineWidth: 1))
    }

    private func outgoingRequestCard(req: DancerConnection) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(req.otherUserName)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Text(req.relationshipType == .partner ? "Žiadosť o partnera" : "Žiadosť o spojenie")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
            Spacer()
            Button("Zrušiť žiadosť") {
                Task { try? await connectionManager.revokeConnection(connectionId: req.id) }
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(Color.white.opacity(0.08), in: Capsule())
            .buttonStyle(.pressable)
        }
        .padding(12)
        .homeCard(cornerRadius: 14)
    }

    private func emptyStateView(icon: String, title: String, subtitle: String, actionTitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(Color.gold400.opacity(0.8))
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Text(subtitle)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button { showAddConnectionSheet = true } label: {
                Label(actionTitle, systemImage: "plus")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(Color.obsidian900)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 40)
                    .background(Color.gold400, in: Capsule())
            }
            .buttonStyle(.pressable)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .homeCard(cornerRadius: 20)
    }

    private func filtered(connections: [DancerConnection]) -> [DancerConnection] {
        let clean = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return connections }
        return connections.filter {
            $0.otherUserName.localizedCaseInsensitiveContains(clean) ||
            $0.otherUserClub.localizedCaseInsensitiveContains(clean) ||
            $0.otherUserDancerCode.localizedCaseInsensitiveContains(clean)
        }
    }

    // MARK: - My card
    private var myCardSheet: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        EncoreMemberCardView(
                            name: profileStore.currentName,
                            club: profileStore.currentClub,
                            allowInteractiveTilt: true,
                            showActionButtons: true
                        )

                        if !profileStore.dancerCode.isEmpty {
                            Button {
                                UIPasteboard.general.string = profileStore.dancerCode
                                actionCount += 1
                            } label: {
                                Label("ID tanečníka: \(profileStore.dancerCode)", systemImage: "doc.on.doc")
                                    .font(.subheadline.weight(.bold).monospaced())
                                    .foregroundColor(Color.gold300)
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 40)
                                    .background(Color.gold500.opacity(0.16), in: Capsule())
                            }
                            .buttonStyle(.pressable)
                            .accessibilityHint("Skopíruje ID tanečníka")
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Môj QR kód")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hotovo") { showMyCard = false }
                        .fontWeight(.bold)
                        .foregroundColor(Color.gold400)
                }
            }
        }
    }

    private func handleScannedQRCode(_ code: String) {
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.starts(with: "DNC-") {
            // A scanned ID tanečníka
            Task {
                try? await connectionManager.sendRequestByDancerCode(code: clean, type: .connection)
            }
        } else if let url = URL(string: clean) {
            _ = friendManager.handleIncomingURL(url)
        }
    }
}

// MARK: - Xcode Canvas Preview
#Preview("FriendsListView - Tanečné Prepojenia") {
    NavigationStack {
        FriendsListView()
    }
    .previewWithSampleData()
}


// MARK: - Reporting a user
private extension FriendsListView {
    /// Opens an e-mail to support with the reported person's name and ID tanečníka filled in.
    /// Nothing is "sent" silently: the user sees and sends the message, so the report is real.
    func report(_ conn: DancerConnection) {
        let body = """
        Nahlasujem používateľa:
        Meno: \(conn.otherUserName)
        ID tanečníka: \(conn.otherUserDancerCode)

        Čo sa stalo:

        """
        guard let url = AppContact.mailURL(subject: "Nahlásenie používateľa", body: body) else {
            showReportFallback = true
            return
        }
        openURL(url) { accepted in
            if !accepted { showReportFallback = true }
        }
    }
}

/// Text first, then a small icon: "A ŠTT 120 b ›".
private struct TrailingIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon.font(.caption2.weight(.bold))
        }
    }
}
