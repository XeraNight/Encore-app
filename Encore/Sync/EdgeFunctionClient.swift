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

    /// What an error answer says. A call refused by the platform itself (too many calls) has no body of ours, but
    /// callers still need to know it was a limit, so a run can stop instead of asking on.
    static func failure(status: Int, data: Data) -> Failure {
        let reply = try? JSONDecoder().decode(ServerError.self, from: data)
        return .server(code: reply?.error ?? (status == 429 ? "rate_limited" : nil), message: reply?.message)
    }

    static func call<Body: Encodable, Reply: Decodable>(_ name: String, _ body: Body) async throws -> Reply {
        do {
            return try await SupabaseConfig.client.functions.invoke(name, options: FunctionInvokeOptions(body: body))
        } catch FunctionsError.httpError(let status, let data) {
            throw failure(status: status, data: data)
        } catch {
            Logger.sync.error("\(name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw Failure.network
        }
    }
}
