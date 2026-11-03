import Foundation
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

struct PixelAnimation {
    let frames: [UIImage]
    let durations: [TimeInterval]
    let totalDuration: TimeInterval

    init?(fileURL: URL) {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        guard CGImageSourceGetCount(source) > 0 else { return nil }
        var loaded: [UIImage] = []
        var delays: [TimeInterval] = []
        for i in 0..<min(CGImageSourceGetCount(source), 180) {
            guard let image = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any]
            let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let seconds = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? NSNumber)?.doubleValue ?? 0.16
            loaded.append(UIImage(cgImage: image))
            delays.append(max(0.06, seconds))
        }
        guard !loaded.isEmpty else { return nil }
        frames = loaded
        durations = delays
        totalDuration = delays.reduce(0, +)
    }

    func frame(at date: Date) -> UIImage {
        guard frames.count > 1, totalDuration > 0 else { return frames[0] }
        let position = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: totalDuration)
        var elapsed = 0.0
        for (index, delay) in durations.enumerated() {
            elapsed += delay
            if position < elapsed { return frames[index] }
        }
        return frames[frames.count - 1]
    }
}

struct GalleryGIF: Codable, Identifiable {
    let file: String
    let label: String
    let slot: String
    let source_url: String
    var id: String { file }
}

@MainActor
final class SpriteLibrary: ObservableObject {
    static let slots: [(key: String, title: String)] = [
        ("idle", "Greeting / Idle"),
        ("walk", "Walking"),
        ("meal", "Eating / Breakfast"),
        ("play", "Playing / Afternoon"),
        ("bath", "Bath / Evening"),
        ("sleep", "Sleeping"),
        ("friend", "Friendship"),
        ("gift", "Giving Watts")
    ]
    private static let pageURL = URL(string: "https://www.serebii.net/virtualpet/pokemonpikachu2/")!

    @Published private(set) var imports: [String: PixelAnimation] = [:]
    @Published private(set) var savedNames: [String: String] = [:]
    @Published private(set) var gallery: [GalleryGIF] = []
    @Published private(set) var selected: [String: Int] = [:]
    @Published private(set) var isSyncing = false
    @Published private(set) var syncStatus = ""
    @Published var errorMessage: String?

    private let folder: URL
    private let galleryFolder: URL
    private var cache: [String: PixelAnimation] = [:]
    private var bundled: [GalleryGIF] = []

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folder = documents.appendingPathComponent("SpriteImports", isDirectory: true)
        galleryFolder = documents.appendingPathComponent("SerebiiGallery", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: galleryFolder, withIntermediateDirectories: true)
        if let base = Bundle.main.resourceURL?.appendingPathComponent("SerebiiGallery"),
           let data = try? Data(contentsOf: base.appendingPathComponent("manifest.json")),
           let entries = try? JSONDecoder().decode([GalleryGIF].self, from: data) {
            bundled = entries
        }
        reload()
    }

    var galleryCount: Int { gallery.count }

    func name(for slot: String) -> String {
        if let name = savedNames[slot] { return name + " (custom override)" }
        let items = gallery.filter { $0.slot == slot }
        return items.isEmpty ? "No animation found" : "\(items.count) original GIF(s)"
    }

    func title(for slot: String) -> String {
        if savedNames[slot] != nil { return "CUSTOM ANIMATION" }
        let items = gallery.filter { $0.slot == slot }
        guard !items.isEmpty else { return "AWAITING PIKACHU GIFS" }
        let index = (selected[slot] ?? 0) % items.count
        return items[index].label.uppercased()
    }

    func advance(_ slot: String, by delta: Int = 1) {
        let count = gallery.filter { $0.slot == slot }.count
        guard count > 1 else { return }
        selected[slot] = ((selected[slot] ?? 0) + delta % count + count) % count
    }

    func animation(for slot: String) -> PixelAnimation? {
        if let local = imports[slot] { return local }
        let possibilities = gallery.filter { $0.slot == slot }
        if !possibilities.isEmpty {
            let entry = possibilities[(selected[slot] ?? 0) % possibilities.count]
            let url = urlFor(entry)
            if let cached = cache[url.path] { return cached }
            if let animation = PixelAnimation(fileURL: url) {
                cache[url.path] = animation
                return animation
            }
        }
        if slot != "idle" { return animation(for: "idle") }
        return nil
    }

    private func urlFor(_ entry: GalleryGIF) -> URL {
        let local = galleryFolder.appendingPathComponent(entry.file)
        if FileManager.default.fileExists(atPath: local.path) { return local }
        return (Bundle.main.resourceURL ?? galleryFolder)
            .appendingPathComponent("SerebiiGallery")
            .appendingPathComponent(entry.file)
    }

    func reload() {
        var found: [String: PixelAnimation] = [:]
        var names: [String: String] = [:]
        for slot in Self.slots {
            for ext in ["gif", "png", "jpg", "jpeg"] {
                let candidate = folder.appendingPathComponent("\(slot.key).\(ext)")
                guard FileManager.default.fileExists(atPath: candidate.path),
                      let animation = PixelAnimation(fileURL: candidate) else { continue }
                found[slot.key] = animation
                names[slot.key] = "\(slot.key).\(ext) · \(animation.frames.count) frame(s)"
                break
            }
        }
        imports = found
        savedNames = names
        let localManifest = galleryFolder.appendingPathComponent("manifest.json")
        var local: [GalleryGIF] = []
        if let data = try? Data(contentsOf: localManifest) {
            local = (try? JSONDecoder().decode([GalleryGIF].self, from: data)) ?? []
        }
        let localKeys = Set(local.map(\.source_url))
        gallery = local + bundled.filter { !localKeys.contains($0.source_url) }
        syncStatus = gallery.isEmpty ? "No GS sprites saved. Connect to download gallery." : "\(gallery.count) GS animations available."
    }

    func importSprite(_ url: URL, into slot: String) {
        guard Self.slots.contains(where: { $0.key == slot }) else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        guard ["gif", "png", "jpg", "jpeg"].contains(ext) else {
            errorMessage = "Choose a GIF, PNG, or JPEG."
            return
        }
        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "Couldn't read that file."
            return
        }
        let target = folder.appendingPathComponent("\(slot).\(ext)")
        do {
            for old in ["gif", "png", "jpg", "jpeg"] {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent("\(slot).\(old)"))
            }
            try data.write(to: target, options: .atomic)
            guard PixelAnimation(fileURL: target) != nil else {
                try? FileManager.default.removeItem(at: target)
                throw NSError(domain: "PocketPika", code: 1, userInfo: [NSLocalizedDescriptionKey: "Couldn't decode sprite file"])
            }
            errorMessage = nil
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Automatically sync original GIF files from the website with permission asserted by the owner.
    /// All files are stored locally; no web service or tracking is used by the app.
    func syncFromSerebii() async {
        guard !isSyncing else { return }
        isSyncing = true
        errorMessage = nil
        syncStatus = "Connecting to the GS animation gallery..."
        defer { isSyncing = false }
        do {
            var request = URLRequest(url: Self.pageURL)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw GalleryError.badPage }
            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { throw GalleryError.badPage }
            let candidates = Self.candidates(in: html)
            guard !candidates.isEmpty else { throw GalleryError.noImages }
            let existing = Set(gallery.map(\.source_url))
            var downloaded = 0
            var local: [GalleryGIF] = []
            if let data = try? Data(contentsOf: galleryFolder.appendingPathComponent("manifest.json")) {
                local = (try? JSONDecoder().decode([GalleryGIF].self, from: data)) ?? []
            }
            let slotsPriority = ["idle", "walk", "meal", "sleep", "bath", "friend", "gift", "play"]
            let ordered = slotsPriority.flatMap { slot in candidates.filter { $0.slot == slot } }
            for (i, item) in ordered.enumerated() {
                if downloaded >= 45 { break }
                if existing.contains(item.source_url) { continue }
                guard let url = URL(string: item.source_url) else { continue }
                var imageRequest = URLRequest(url: url)
                imageRequest.setValue(Self.pageURL.absoluteString, forHTTPHeaderField: "Referer")
                imageRequest.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile", forHTTPHeaderField: "User-Agent")
                do {
                    let (bytes, result) = try await URLSession.shared.data(for: imageRequest)
                    guard (result as? HTTPURLResponse)?.statusCode == 200,
                          bytes.count < 4_000_000,
                          bytes.starts(with: [71, 73, 70, 56]),
                          bytes.count >= 6 else { continue }
                    let name = "serebii_\(i).gif"
                    try bytes.write(to: galleryFolder.appendingPathComponent(name), options: .atomic)
                    local.append(GalleryGIF(file: name, label: item.label, slot: item.slot, source_url: item.source_url))
                    downloaded += 1
                    syncStatus = "Downloading GS GIFs: \(downloaded) saved"
                } catch {
                    // Some original files may no longer exist. Keep the ones that succeeded.
                }
            }
            if !local.isEmpty {
                let manifest = try JSONEncoder().encode(local)
                try manifest.write(to: galleryFolder.appendingPathComponent("manifest.json"), options: .atomic)
            }
            reload()
            if gallery.isEmpty { throw GalleryError.noImages }
            syncStatus = "Ready: \(gallery.count) original Pocket Pikachu 2 GIFs."
        } catch {
            syncStatus = "Gallery download unavailable."
            errorMessage = "Couldn't fetch GIFs from Serebii: \(error.localizedDescription). You can retry in Settings or import files manually."
        }
    }

    private enum GalleryError: LocalizedError {
        case badPage, noImages
        var errorDescription: String? {
            switch self {
            case .badPage: return "The page didn't return a readable response"
            case .noImages: return "No matching original GIF images were found in the page HTML"
            }
        }
    }

    private static func candidates(in html: String) -> [GalleryGIF] {
        guard let tagRe = try? NSRegularExpression(pattern: #"(?is)<img\b[^>]*>"#) else { return [] }
        let ns = html as NSString
        let tags = tagRe.matches(in: html, range: NSRange(location: 0, length: ns.length))
        var results: [GalleryGIF] = []
        var seen = Set<String>()
        for tagMatch in tags {
            let tag = ns.substring(with: tagMatch.range)
            guard let src = attribute("src", in: tag) ?? attribute("data-src", in: tag),
                  let alt = attribute("alt", in: tag) ?? attribute("title", in: tag) else { continue }
            let altLower = alt.lowercased()
            guard altLower.contains("animated pocket pikachu 2") else { continue }
            guard let resolved = URL(string: src.replacingOccurrences(of: "&amp;", with: "&"), relativeTo: Self.pageURL)?.absoluteURL else { continue }
            var components = URLComponents(url: resolved, resolvingAgainstBaseURL: true)
            components?.scheme = "https"
            guard let url = components?.url, let hostname = url.host?.lowercased(),
                  hostname == "serebii.net" || hostname.hasSuffix(".serebii.net"),
                  !seen.contains(url.absoluteString) else { continue }
            seen.insert(url.absoluteString)
            let label = alt.replacingOccurrences(of: #"(?i)^animated\s+pocket\s+pikachu\s*2\s+image\s*[-:]?\s*"#, with: "", options: .regularExpression)
            let slot = classify(label)
            results.append(GalleryGIF(file: "", label: label, slot: slot, source_url: url.absoluteString))
        }
        return results
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        let pattern = "(?i)\\b" + NSRegularExpression.escapedPattern(for: name) + #"\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let match = re.firstMatch(in: tag, range: NSRange(location: 0, length: (tag as NSString).length)) else { return nil }
        let ns = tag as NSString
        for group in 1...3 where match.range(at: group).location != NSNotFound {
            return ns.substring(with: match.range(at: group))
        }
        return nil
    }

    private static func classify(_ label: String) -> String {
        let text = label.lowercased()
        func has(_ terms: [String]) -> Bool { terms.contains { text.contains($0) } }
        if has(["sleep", "dream", "waking", "night time", "yawn"]) { return "sleep" }
        if has(["bath", "shower", "brush teeth"]) { return "bath" }
        if has(["eat", "apple", "juice", "ice cream", "food", "mealtime", "breakfast"]) { return "meal" }
        if has(["walk", "heading", "roll", "skipping", "aerobics", "pull up", "hula hoop", "stroll"]) { return "walk" }
        if has(["grumpy", "friend", "very happy", "waving", "wave"]) { return "friend" }
        if has(["thanks", "thank you", "gift", "wink"]) { return "gift" }
        if has(["greeting", "come here", "nice to meet", "falls over", "pikachu's back", "dance"]) { return "idle" }
        return "play"
    }
}

struct AnimatedPixelSprite: View {
    let animation: PixelAnimation
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: animation.frames.count <= 1)) { context in
            Image(uiImage: animation.frame(at: context.date))
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        }
    }
}
