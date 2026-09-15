import Foundation

public struct AutomaticResult: Sendable {
    public var moved: [MoveRecord] = []
    public var failed: [Proposal] = []
    public var skipped: [String] = []
    public var waiting: Int = 0
}
extension SorterEngine {
    public func sortNewArrivals(settings: Settings, state: ArrivalState, failedPaths: Set<String> = []) async throws -> AutomaticResult {
        guard state.enabled else { return AutomaticResult() }
        guard state.source.standardizedFileURL.path == settings.source.standardizedFileURL.path else {
            throw SorterError.message("Automatic sorting source changed; initialize its exclusions before sorting.")
        }
        let scan = try await scan(settings: settings, excluding: try state.excludedPaths().union(failedPaths))
        var result = AutomaticResult()
        result.skipped = scan.skipped; result.waiting = scan.waiting
        for var proposal in scan.proposals {
            try Task.checkCancellation()
            // Standing approval applies only to arrivals outside the persistent baseline.
            proposal.approved = true
            do { result.moved.append(try move(proposal, settings: settings)) }
            catch {
                proposal.approved = false
                proposal.reason += " · Move failed: \(error.localizedDescription)"
                result.failed.append(proposal)
            }
        }
        return result
    }
}
