import Foundation
import Supabase
import Observation
import OSLog

struct DragMessage: Codable, Sendable {
    let nodeId: UUID
    let x: Double
    let y: Double
    let senderId: UUID?
    
    init(nodeId: UUID, x: Double, y: Double, senderId: UUID? = nil) {
        self.nodeId = nodeId
        self.x = x
        self.y = y
        self.senderId = senderId
    }
}

struct CanvasActionMessage: Codable, Sendable {
    let action: String          // "added", "deleted", "updated", "transition_updated"
    let nodeId: UUID
    let figureName: String
    let x: Double
    let y: Double
    let rhythm: String
    let notes: String
    let sharedVideoPath: String?   // the shared copy; the original never leaves its iPhone
    let orderIndex: Int
    let transitionNotes: String
    let senderId: UUID
    let senderName: String
    var bars: Int? = nil
}

// MARK: - Presence (Part 3 – partner cursory)
struct PresenceState: Codable, Sendable {
    let userId: String        // senderId.uuidString
    let userName: String
    let x: Double
    let y: Double
    let draggingNodeId: String?  // nil = len pohyb kurzora, inak ťahá figúrku
}

@Observable
final class CanvasRealtimeManager {
    // Uses the shared SupabaseConfig.client singleton — no separate instantiation.
    private var client: SupabaseClient? { SupabaseConfig.client }
    private var channel: RealtimeChannelV2?
    private let senderId = UUID()
    private var lastBroadcastAtByNode: [UUID: Date] = [:]
    private let minimumBroadcastInterval: TimeInterval = 0.04
    private var listenerTasks: [Task<Void, Never>] = []
    private var statusSubscription: RealtimeSubscription?
    private var currentUserName: String = "User"

    var isConnected = false
    var isRefreshing = false
    var needsRefreshAfterReconnect = false  // Part 2 – trigger auto-refresh po reconnecte

    // MARK: - Presence (Part 3)
    var partnerPresences: [String: PresenceState] = [:]  // userId → stav

    // MARK: - Broadcast Callbacks (low-latency drag & canvas actions)
    var onNodeMoved: ((UUID, Double, Double) -> Void)?
    var onNodeAdded: ((CanvasNode, String) -> Void)?
    var onNodeDeleted: ((UUID, String, String) -> Void)?
    var onNodeUpdated: ((CanvasNode, String) -> Void)?
    var onTransitionUpdated: ((UUID, String, String) -> Void)?

    // MARK: - Postgres Change Callbacks (DB-level sync fallback)
    var onDBNodeInserted: ((DBCanvasNodeRow) -> Void)?
    var onDBNodeUpdated: ((DBCanvasNodeRow) -> Void)?
    var onDBNodeDeleted: ((UUID) -> Void)?

    init() {}

    func connect(to routineId: UUID, userName: String = "User") {
        guard let client else {
            Logger.realtime.warning("Supabase Realtime disabled: missing configuration.")
            return
        }
        
        self.currentUserName = userName
        
        // Clean up previous channel if reconnecting or changing routine
        if channel != nil {
            disconnect()
        }
        
        let channelId = "canvas_\(routineId.uuidString.lowercased())"
        Logger.realtime.info("Connecting to channel: \(channelId, privacy: .public)")

        Task {
            // 1. Explicitly ensure WebSocket client is connected before creating channel
            await client.realtimeV2.connect()

            // 1b. Remove any stale/existing channel for this topic so a fresh channel is created with valid callback state
            let topic = "realtime:\(channelId)"
            if let oldChannel = client.realtimeV2.channels[topic] ?? client.realtimeV2.channels[channelId] {
                await client.realtimeV2.removeChannel(oldChannel)
            }

            // 2. Configure channel with low-latency broadcast & presence key
            let ch = client.realtimeV2.channel(channelId) { config in
                config.broadcast = BroadcastJoinConfig(acknowledgeBroadcasts: false, receiveOwnBroadcasts: false)
                config.presence = PresenceJoinConfig(key: self.senderId.uuidString)
            }
            self.channel = ch

            // 3. Listen to official channel subscription status changes
            self.statusSubscription = ch.onStatusChange { [weak self] newStatus in
                guard let self else { return }
                Task { @MainActor in
                    let wasConnected = self.isConnected
                    self.isConnected = (newStatus == .subscribed)
                    
                    if newStatus == .subscribed {
                        Logger.realtime.info("Channel \(channelId, privacy: .public) confirmed SUBSCRIBED.")
                        if !wasConnected {
                            self.needsRefreshAfterReconnect = true
                        }
                        // Guaranteed .subscribed: track our presence safely without any warnings
                        let myPresence = PresenceState(
                            userId: self.senderId.uuidString,
                            userName: self.currentUserName,
                            x: 0, y: 0,
                            draggingNodeId: nil
                        )
                        Task {
                            guard let activeCh = self.channel, activeCh.status == .subscribed else { return }
                            try? await activeCh.track(myPresence)
                        }
                    } else {
                        Logger.realtime.info("Channel \(channelId, privacy: .public) status: \(String(describing: newStatus))")
                    }
                }
            }

            // MARK: Broadcast – node drag (low latency, no DB)
            _ = ch.onBroadcast(event: "node_moved") { [weak self] payload in
                guard let self else { return }
                Task { @MainActor in
                    guard let jsonData = try? JSONEncoder().encode(payload),
                          let drag = try? JSONDecoder().decode(DragMessage.self, from: jsonData) else {
                        return
                    }
                    guard drag.senderId != self.senderId else { return }
                    self.onNodeMoved?(drag.nodeId, drag.x, drag.y)
                }
            }

            // MARK: Broadcast – canvas structural actions
            _ = ch.onBroadcast(event: "canvas_action") { [weak self] payload in
                guard let self else { return }
                Task { @MainActor in
                    guard let jsonData = try? JSONEncoder().encode(payload),
                          let actionMsg = try? JSONDecoder().decode(CanvasActionMessage.self, from: jsonData) else {
                        return
                    }
                    guard actionMsg.senderId != self.senderId else { return }
                    
                    if actionMsg.action == "added" {
                        let node = CanvasNode(
                            id: actionMsg.nodeId,
                            x: actionMsg.x,
                            y: actionMsg.y,
                            figureName: actionMsg.figureName,
                            rhythm: actionMsg.rhythm,
                            notes: actionMsg.notes,
                            orderIndex: actionMsg.orderIndex,
                            transitionNotes: actionMsg.transitionNotes
                        )
                        node.sharedVideoPath = actionMsg.sharedVideoPath
                        node.bars = actionMsg.bars
                        self.onNodeAdded?(node, actionMsg.senderName)
                    } else if actionMsg.action == "deleted" {
                        self.onNodeDeleted?(actionMsg.nodeId, actionMsg.figureName, actionMsg.senderName)
                    } else if actionMsg.action == "updated" {
                        let node = CanvasNode(
                            id: actionMsg.nodeId,
                            x: actionMsg.x,
                            y: actionMsg.y,
                            figureName: actionMsg.figureName,
                            rhythm: actionMsg.rhythm,
                            notes: actionMsg.notes,
                            orderIndex: actionMsg.orderIndex,
                            transitionNotes: actionMsg.transitionNotes
                        )
                        node.sharedVideoPath = actionMsg.sharedVideoPath
                        node.bars = actionMsg.bars
                        self.onNodeUpdated?(node, actionMsg.senderName)
                    } else if actionMsg.action == "transition_updated" {
                        self.onTransitionUpdated?(actionMsg.nodeId, actionMsg.transitionNotes, actionMsg.senderName)
                    }
                }
            }

            // MARK: Postgres Changes – DB-level fallback (upsert nevyvolá false DELETE eventy)
            let pgFilter: RealtimePostgresFilter = .eq("routine_id", value: routineId.uuidString.lowercased())
            let insertions = ch.postgresChange(InsertAction.self, schema: "public", table: "canvas_nodes", filter: pgFilter)
            let updates    = ch.postgresChange(UpdateAction.self, schema: "public", table: "canvas_nodes", filter: pgFilter)
            let deletions  = ch.postgresChange(DeleteAction.self, schema: "public", table: "canvas_nodes", filter: pgFilter)

            // MARK: Presence – partner cursory (Part 3)
            let presenceChanges = ch.presenceChange()

            // Helper decoder shared across tasks
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            // Postgres Change streams
            let t1 = Task { [weak self] in
                guard let self else { return }
                for await insert in insertions {
                    if let data = try? JSONEncoder().encode(insert.record),
                       let row = try? decoder.decode(DBCanvasNodeRow.self, from: data) {
                        await MainActor.run { self.onDBNodeInserted?(row) }
                    }
                }
            }
            let t2 = Task { [weak self] in
                guard let self else { return }
                for await update in updates {
                    if let data = try? JSONEncoder().encode(update.record),
                       let row = try? decoder.decode(DBCanvasNodeRow.self, from: data) {
                        await MainActor.run { self.onDBNodeUpdated?(row) }
                    }
                }
            }
            let t3 = Task { [weak self] in
                guard let self else { return }
                for await deletion in deletions {
                    if let data = try? JSONEncoder().encode(deletion.oldRecord),
                       let row = try? decoder.decode(DBCanvasNodeRow.self, from: data) {
                        await MainActor.run { self.onDBNodeDeleted?(row.id) }
                    }
                }
            }

            // Presence stream – partner cursory (Part 3)
            let t4 = Task { [weak self] in
                guard let self else { return }
                for await presenceChange in presenceChanges {
                    var newPresences: [String: PresenceState] = [:]
                    for (_, presence) in presenceChange.joins {
                        if let data = try? JSONEncoder().encode(presence.state),
                           let state = try? decoder.decode(PresenceState.self, from: data) {
                            newPresences[state.userId] = state
                        }
                    }
                    let leaveKeys = Set(presenceChange.leaves.keys)
                    await MainActor.run {
                        var updated = self.partnerPresences.merging(newPresences) { _, new in new }
                        for key in leaveKeys { updated.removeValue(forKey: key) }
                        updated.removeValue(forKey: self.senderId.uuidString)
                        self.partnerPresences = updated
                    }
                }
            }

            self.listenerTasks = [t1, t2, t3, t4]

            // Join the channel topic
            do {
                try await ch.subscribeWithError()
            } catch {
                Logger.realtime.error("Subscribe failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run { self.isConnected = false }
                return
            }

            // MARK: Part 2 – Heartbeat: sleduje stav kanála každých 8 sekúnd
            let heartbeat = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(8))
                    guard let self, let ch = self.channel else { continue }
                    let alive = ch.status == .subscribed
                    await MainActor.run {
                        if self.isConnected != alive {
                            self.isConnected = alive
                        }
                    }
                }
            }
            self.listenerTasks.append(heartbeat)
        }
    }

    // MARK: - Presence Update (volaj pri každom pohybe / drag)
    func updatePresence(x: Double, y: Double, userName: String, draggingNodeId: UUID? = nil) {
        guard let ch = channel, ch.status == .subscribed else { return }
        let state = PresenceState(
            userId: senderId.uuidString,
            userName: userName,
            x: x, y: y,
            draggingNodeId: draggingNodeId?.uuidString
        )
        Task {
            guard ch.status == .subscribed else { return }
            try? await ch.track(state)
        }
    }

    // MARK: - Broadcast Senders

    func broadcastNodeMove(nodeId: UUID, x: Double, y: Double, force: Bool = false) {
        guard let ch = channel, ch.status == .subscribed else { return }
        
        if !force {
            let now = Date()
            if let last = lastBroadcastAtByNode[nodeId],
               now.timeIntervalSince(last) < minimumBroadcastInterval {
                return
            }
            lastBroadcastAtByNode[nodeId] = now
        }
        
        let message = DragMessage(nodeId: nodeId, x: x, y: y, senderId: senderId)
        Task { try? await ch.broadcast(event: "node_moved", message: message) }
    }

    func broadcastNodeAdded(node: CanvasNode, senderName: String) {
        guard let ch = channel, ch.status == .subscribed else { return }
        let message = CanvasActionMessage(action: "added", nodeId: node.id, figureName: node.figureName,
            x: node.x, y: node.y, rhythm: node.rhythm, notes: node.notes, sharedVideoPath: node.sharedVideoPath,
            orderIndex: node.orderIndex, transitionNotes: node.transitionNotes, senderId: senderId, senderName: senderName,
            bars: node.bars)
        Task { try? await ch.broadcast(event: "canvas_action", message: message) }
    }

    func broadcastNodeDeleted(nodeId: UUID, figureName: String, senderName: String) {
        guard let ch = channel, ch.status == .subscribed else { return }
        let message = CanvasActionMessage(action: "deleted", nodeId: nodeId, figureName: figureName,
            x: 0, y: 0, rhythm: "", notes: "", sharedVideoPath: nil, orderIndex: 0, transitionNotes: "",
            senderId: senderId, senderName: senderName)
        Task { try? await ch.broadcast(event: "canvas_action", message: message) }
    }

    func broadcastNodeUpdated(node: CanvasNode, senderName: String) {
        guard let ch = channel, ch.status == .subscribed else { return }
        let message = CanvasActionMessage(action: "updated", nodeId: node.id, figureName: node.figureName,
            x: node.x, y: node.y, rhythm: node.rhythm, notes: node.notes, sharedVideoPath: node.sharedVideoPath,
            orderIndex: node.orderIndex, transitionNotes: node.transitionNotes, senderId: senderId, senderName: senderName,
            bars: node.bars)
        Task { try? await ch.broadcast(event: "canvas_action", message: message) }
    }

    func broadcastTransitionUpdated(node: CanvasNode, senderName: String) {
        guard let ch = channel, ch.status == .subscribed else { return }
        let message = CanvasActionMessage(action: "transition_updated", nodeId: node.id, figureName: node.figureName,
            x: node.x, y: node.y, rhythm: node.rhythm, notes: node.notes, sharedVideoPath: node.sharedVideoPath,
            orderIndex: node.orderIndex, transitionNotes: node.transitionNotes, senderId: senderId, senderName: senderName,
            bars: node.bars)
        Task { try? await ch.broadcast(event: "canvas_action", message: message) }
    }

    // MARK: - Disconnect

    func disconnect() {
        statusSubscription?.cancel()
        statusSubscription = nil
        for task in listenerTasks { task.cancel() }
        listenerTasks = []
        partnerPresences = [:]
        guard let client, let ch = channel else { return }
        Task {
            if ch.status == .subscribed {
                await ch.untrack()
            }
            await client.realtimeV2.removeChannel(ch)
        }
        channel = nil
        isConnected = false
        Logger.realtime.info("Disconnected from channel")
    }
}
