import WatchConnectivity

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated, error == nil else { return }
        Task { @MainActor in self.pushWatchContext() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in self.handleIncoming(userInfo: userInfo) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        guard let typeRaw = message[WatchMessageKey.type] as? String,
              WatchMessageType(rawValue: typeRaw) == .requestData
        else { replyHandler([:]); return }

        // WCSession's reply handler isn't Sendable; box it so the
        // hop to the main actor is explicit. It is called exactly once.
        let box = ReplyHandlerBox(replyHandler)
        Task { @MainActor in
            box.handler(self.collectWatchContext())
        }
    }
}

/// Carries WCSession's non-Sendable reply closure across an actor hop.
/// Safe because the closure is invoked exactly once and WCSession allows
/// calling it from any thread.
private nonisolated struct ReplyHandlerBox: @unchecked Sendable {
    let handler: ([String: Any]) -> Void
    nonisolated init(_ handler: @escaping ([String: Any]) -> Void) { self.handler = handler }
}
