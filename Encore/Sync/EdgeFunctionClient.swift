import Foundation
import OSLog
import Supabase

/// Calls one of our Supabase Edge Functions. Every function answers an error as `{ error, message }` with a
/// Slovak message the app can show as is.
enum EdgeFunctionClient {
    enum Failure: Error {
        /// The function answered with an error. `message` is ready to show, `code` tells the kind.
        case server(code: String?, message: String?)
        /// No usable answer (offline, timeout, unexpected reply).
        case network
    }

    private struct ServerError: Decodable {
        let error: String?
        let message: String?
    }

    static func call<Body: Encodable, Reply: Decodable>(_ name: String, _ body: Body) async throws -> Reply {
        do {
            return try await SupabaseConfig.client.functions.invoke(name, options: FunctionInvokeOptions(body: body))
        } catch FunctionsError.httpError(_, let data) {
            let reply = try? JSONDecoder().decode(ServerError.self, from: data)
            throw Failure.server(code: reply?.error, message: reply?.message)
        } catch {
            Logger.sync.error("\(name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw Failure.network
        }
    }
}
