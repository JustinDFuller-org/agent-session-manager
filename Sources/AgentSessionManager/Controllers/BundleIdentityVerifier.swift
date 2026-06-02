import Foundation

enum BundleIdentityVerifier {
    @discardableResult
    static func checkPreferredURL(
        runningURL: URL,
        preferredURL: URL?,
        bundleIdentifier: String
    ) -> Bool {
        guard let preferredURL else { return true }
        return InvariantReporter.shared.check(
            .appBundleIdentityPreferredURL,
            runningURL.standardizedFileURL == preferredURL.standardizedFileURL,
            context: [
                "bundle.identifier": bundleIdentifier,
                "running.url": runningURL.standardizedFileURL.path,
                "preferred.url": preferredURL.standardizedFileURL.path,
            ])
    }
}
