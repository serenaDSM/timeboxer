import Foundation

final class PolicyStore {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private(set) var policy: FamilyPolicy
    let policyURL: URL

    init(fileManager: FileManager = .default) {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let directory = applicationSupport.appendingPathComponent("TimeBoxer", isDirectory: true)
        policyURL = directory.appendingPathComponent("family-policy.json")
        policy = .safeDefault

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: policyURL.path) {
                policy = try decoder.decode(FamilyPolicy.self, from: Data(contentsOf: policyURL))
            } else {
                try save(.safeDefault)
            }
        } catch {
            NSLog("TimeBoxer policy fallback: %@", error.localizedDescription)
        }
    }

    func reload() {
        do {
            policy = try decoder.decode(FamilyPolicy.self, from: Data(contentsOf: policyURL))
        } catch {
            NSLog("TimeBoxer could not reload policy: %@", error.localizedDescription)
        }
    }

    func save(_ nextPolicy: FamilyPolicy) throws {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(nextPolicy).write(to: policyURL, options: .atomic)
        policy = nextPolicy
    }
}
