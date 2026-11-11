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
            // Decode the source image without recoloring or removing any pixels.
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
        ("gift", "Giving Ice Cubes")
    ]
    private static let pageURL = URL(string: "https://pokestats.gg/sprites/marill")!
    // Requested custom milestone scenes. They may be outside the first 45
    // standard gallery GIFs downloaded by earlier app versions.
    private static let specialSceneNames = [
        "Writing Name", "Very Happy Marill", "Yo-yo", "Hula Hoop",
        "Art time", "Fireworks", "Very Friendly"
    ]

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
        galleryFolder = documents.appendingPathComponent("MarillGallery", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: galleryFolder, withIntermediateDirectories: true)
        if let base = Bundle.main.resourceURL?.appendingPathComponent("MarillGallery"),
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
        return items.isEmpty ? "No animation found" : "\(items.count) animation(s)"
    }

    func title(for slot: String) -> String {
        if savedNames[slot] != nil { return "CUSTOM ANIMATION" }
        let items = gallery.filter { $0.slot == slot }
        guard !items.isEmpty else { return "AWAITING MARILL GIFS" }
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

    // Automatic, clock-based scenes use the original labeled GIF rather than
    // whichever animation was last manually selected in the Settings gallery.
    // Exact label matches first; otherwise fall back to the existing slot.
    func animation(named keyword: String, fallbackSlot: String) -> PixelAnimation? {
        let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let exact = gallery.first { $0.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized }
        let partial = gallery.first { $0.label.lowercased().contains(normalized) }
        if let entry = exact ?? partial {
            let url = urlFor(entry)
            if let cached = cache[url.path] { return cached }
            if let animation = PixelAnimation(fileURL: url) {
                cache[url.path] = animation
                return animation
            }
        }
        return animation(for: fallbackSlot)
    }

    private func urlFor(_ entry: GalleryGIF) -> URL {
        return (Bundle.main.resourceURL ?? galleryFolder)
            .appendingPathComponent("MarillGallery")
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
        gallery = bundled
        syncStatus = gallery.isEmpty ? "No bundled animations found." : "\(gallery.count) Marill sprites available."
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

    func syncMilestoneAnimations() async { }

    func reloadBundledAnimations() async {
        cache.removeAll()
        reload()
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


