import Foundation
import IOKit

struct DeviceInfo: Equatable, Sendable {
    var modelName: String
    var modelDetail: String
    var symbol: String
    var osName: String
    var osVersion: String
    var chip: String
    var architecture: String
    var memoryBytes: UInt64
    var storageFree: Int64
    var storageTotal: Int64

    var storageUsedFraction: Double {
        guard storageTotal > 0 else { return 0 }
        return min(max(Double(storageTotal - storageFree) / Double(storageTotal), 0), 1)
    }

    static let placeholder = DeviceInfo(
        modelName: "Mac", modelDetail: "", symbol: "desktopcomputer",
        osName: "macOS", osVersion: "", chip: "", architecture: "",
        memoryBytes: 0, storageFree: 0, storageTotal: 0
    )
}

nonisolated enum SystemInfo {
    static func read() -> DeviceInfo {
        let identifier = sysctlString("hw.model") ?? "Mac"
        let productName = deviceTreeProductName()
        let marketing = marketingName(identifier: identifier, productName: productName)
        let (name, detail) = split(marketing: marketing, identifier: identifier)
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let version = os.patchVersion > 0
            ? "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
            : "\(os.majorVersion).\(os.minorVersion)"
        let storage = storageCapacity()
        return DeviceInfo(
            modelName: name,
            modelDetail: detail,
            symbol: symbol(identifier: identifier, name: marketing ?? productName ?? ""),
            osName: releaseName(major: os.majorVersion),
            osVersion: version,
            chip: chipName(),
            architecture: hardwareArchitecture(),
            memoryBytes: ProcessInfo.processInfo.physicalMemory,
            storageFree: storage.free,
            storageTotal: storage.total
        )
    }

    static func storageCapacity() -> (free: Int64, total: Int64) {
        let root = URL(fileURLWithPath: "/")
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        guard let values = try? root.resourceValues(forKeys: keys) else { return (0, 0) }
        let free = values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)
        return (free, Int64(values.volumeTotalCapacity ?? 0))
    }

    private static func marketingName(identifier: String, productName: String?) -> String? {
        if let name = productName, name != identifier, name.contains(" ") {
            return name
        }
        if let names = CFPreferencesCopyAppValue("CPU Names" as CFString, "com.apple.SystemProfiler" as CFString) as? [String: String] {
            let languageCode = Locale.preferredLanguages.first?.prefix(2) ?? "en"
            if let match = names.first(where: { $0.key.contains("-\(languageCode)") })?.value { return match }
            if let any = names.values.sorted().first { return any }
        }
        return nil
    }

    private static func deviceTreeProductName() -> String? {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product")
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }
        guard let property = IORegistryEntryCreateCFProperty(entry, "product-name" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else { return nil }
        if let data = property as? Data {
            let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: CharacterSet(charactersIn: "\0").union(.whitespacesAndNewlines))
            return text.isEmpty ? nil : text
        }
        return property as? String
    }

    private static func split(marketing: String?, identifier: String) -> (String, String) {
        guard let marketing else { return (familyName(identifier: identifier), identifier) }
        if let open = marketing.firstIndex(of: "("), marketing.hasSuffix(")") {
            let name = marketing[..<open].trimmingCharacters(in: .whitespaces)
            let detail = marketing[marketing.index(after: open)..<marketing.index(before: marketing.endIndex)]
            return (name, String(detail))
        }
        return (marketing, identifier)
    }

    private static func familyName(identifier: String) -> String {
        let families: [(String, String)] = [
            ("MacBookPro", "MacBook Pro"), ("MacBookAir", "MacBook Air"), ("MacBook", "MacBook"),
            ("iMacPro", "iMac Pro"), ("iMac", "iMac"), ("Macmini", "Mac mini"),
            ("MacPro", "Mac Pro"), ("Mac", "Mac"),
        ]
        return families.first { identifier.hasPrefix($0.0) }?.1 ?? "Mac"
    }

    static func symbol(identifier: String, name: String) -> String {
        let n = name.lowercased(), id = identifier.lowercased()
        if n.contains("macbook") || id.hasPrefix("macbook") { return "laptopcomputer" }
        if n.contains("imac") || id.hasPrefix("imac") { return "desktopcomputer" }
        if n.contains("mac mini") || id.hasPrefix("macmini") { return "macmini" }
        if n.contains("mac studio") { return "macstudio" }
        if n.contains("mac pro") || id.hasPrefix("macpro") {
            return id == "macpro6,1" || n.contains("late 2013") ? "macpro.gen2" : "macpro.gen3"
        }
        if id.contains("virtual") || id.hasPrefix("vmware") || id.hasPrefix("parallels") { return "macwindow" }
        return "desktopcomputer"
    }

    private static func releaseName(major: Int) -> String {
        let names: [Int: String] = [
            11: "Big Sur", 12: "Monterey", 13: "Ventura", 14: "Sonoma", 15: "Sequoia", 26: "Tahoe",
        ]
        return names[major].map { "macOS \($0)" } ?? "macOS"
    }

    private static func chipName() -> String {
        guard var brand = sysctlString("machdep.cpu.brand_string") else { return hardwareArchitecture() }
        for token in ["(R)", "(TM)", "CPU"] {
            brand = brand.replacingOccurrences(of: token, with: "")
        }
        if let at = brand.range(of: "@") {
            brand = String(brand[..<at.lowerBound])
        }
        return brand.split(separator: " ").joined(separator: " ")
    }

    private static func hardwareArchitecture() -> String {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0, value == 1 {
            return "Apple silicon"
        }
        return "Intel x86_64"
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespaces)
    }
}

nonisolated enum ByteFormat {
    static func storage(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: bytes)
    }

    static func memory(_ bytes: UInt64) -> String {
        let gigabytes = Double(bytes) / 1_073_741_824
        return gigabytes >= 1 ? "\(Int(gigabytes.rounded())) GB" : "\(Int(Double(bytes) / 1_048_576)) MB"
    }

    static func file(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
