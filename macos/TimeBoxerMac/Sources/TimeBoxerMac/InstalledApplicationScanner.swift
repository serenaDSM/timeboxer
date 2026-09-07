import Foundation

struct InstalledApplicationRecord: Codable, Equatable, Sendable {
    let bundleIdentifier: String
    let name: String
    let category: String?
    let recommended: Bool

    var payload: [String: Any] {
        var value: [String: Any] = [
            "bundleIdentifier": bundleIdentifier,
            "name": name,
            "recommended": recommended,
        ]
        if let category {
            value["category"] = category
        }
        return value
    }
}

enum InstalledApplicationScanner {
    static func recommendedBundleIdentifiers(
        in applications: [InstalledApplicationRecord]
    ) -> Set<String> {
        Set(applications.lazy.filter(\.recommended).map(\.bundleIdentifier))
    }

    static func scan(
        fileManager: FileManager = .default,
        directories: [URL]? = nil
    ) -> [InstalledApplicationRecord] {
        let roots = directories ?? defaultApplicationDirectories(fileManager: fileManager)
        var recordsByBundleIdentifier: [String: InstalledApplicationRecord] = [:]

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
                guard
                    let bundle = Bundle(url: url),
                    let bundleIdentifier = bundle.bundleIdentifier,
                    bundleIdentifier != "nz.co.timeboxer.mac"
                else { continue }

                let category = bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String
                let recommended = isRecommendedEntertainment(
                    bundleIdentifier: bundleIdentifier,
                    category: category
                )
                if bundleIdentifier.hasPrefix("com.apple.") && !recommended {
                    continue
                }

                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                recordsByBundleIdentifier[bundleIdentifier] = InstalledApplicationRecord(
                    bundleIdentifier: bundleIdentifier,
                    name: name,
                    category: category,
                    recommended: recommended
                )
            }
        }

        return recordsByBundleIdentifier.values.sorted {
            if $0.recommended != $1.recommended { return $0.recommended && !$1.recommended }
            let nameOrder = $0.name.localizedCaseInsensitiveCompare($1.name)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return $0.bundleIdentifier < $1.bundleIdentifier
        }
    }

    static func isRecommendedEntertainment(bundleIdentifier: String, category: String?) -> Bool {
        FamilyPolicy.safeDefault.blockedBundleIdentifiers.contains(bundleIdentifier)
            || category.map(EntertainmentClassification.isGameCategory) == true
    }

    private static func defaultApplicationDirectories(fileManager: FileManager) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        ]
    }
}
