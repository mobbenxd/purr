import Foundation
import PurrCore

/// What build this is. `build.sh` writes these into Info.plist; under
/// `swift run` there is no Info.plist and the app reports itself as a dev build.
enum AppInfo {
    static var version: SemanticVersion? {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(SemanticVersion.init)
    }

    static var build: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    /// GitHub `owner/name` whose releases are checked for updates.
    static var repository: String {
        Bundle.main.object(forInfoDictionaryKey: "PurrRepository") as? String ?? "mobbenxd/purr"
    }

    static var versionText: String {
        guard let version else { return "dev" }
        return build.map { "v\(version) (\($0))" } ?? "v\(version)"
    }

    static var repositoryURL: URL { URL(string: "https://github.com/\(repository)")! }
}

/// Checks GitHub once a day for a newer Purr release (and a newer Mole).
@MainActor
final class UpdateChecker: ObservableObject {
    /// Set when a release newer than this build exists and was not skipped.
    @Published private(set) var purrRelease: GitHubRelease?
    @Published private(set) var moleInstalled: SemanticVersion?
    @Published private(set) var moleLatest: SemanticVersion?
    @Published private(set) var checking = false
    @Published private(set) var lastResult: String?

    var moPath: () -> String? = { nil }

    private var timer: Timer?
    private let defaults = UserDefaults.standard

    var moleUpdateAvailable: Bool {
        guard let moleInstalled, let moleLatest else { return false }
        return moleLatest > moleInstalled
    }

    var lastCheck: Date? { defaults.object(forKey: Prefs.lastUpdateCheck) as? Date }

    /// Checks shortly after launch (results are not kept across launches),
    /// then once a day while running.
    func start() {
        Task {
            try? await Task.sleep(for: .seconds(8))
            if defaults.bool(forKey: Prefs.checkUpdates) { await check(manual: false) }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { await self?.checkIfDue() }
        }
    }

    private func checkIfDue() async {
        guard defaults.bool(forKey: Prefs.checkUpdates) else { return }
        if let lastCheck, Date().timeIntervalSince(lastCheck) < 24 * 3600 { return }
        await check(manual: false)
    }

    func check(manual: Bool) async {
        guard !checking else { return }
        checking = true
        defer { checking = false }

        if let mo = moPath() { moleInstalled = await MoleCLI.version(mo) }
        async let purr = Self.latestRelease(AppInfo.repository)
        async let mole = Self.latestRelease("tw93/Mole")
        let (purrResult, moleResult) = await (purr, mole)

        moleLatest = (try? moleResult.get())?.version
        switch purrResult {
        case .success(let release):
            defaults.set(Date(), forKey: Prefs.lastUpdateCheck)
            apply(release, manual: manual)
        case .failure:
            lastResult = String(localized: "เช็กอัปเดตไม่สำเร็จ ลองใหม่ภายหลัง")
        }
    }

    /// Hides the banner until a version newer than this one comes out.
    func skipCurrentRelease() {
        guard let version = purrRelease?.version else { return }
        defaults.set(version.description, forKey: Prefs.skippedVersion)
        purrRelease = nil
    }

    private func apply(_ release: GitHubRelease?, manual: Bool) {
        guard let current = AppInfo.version else {
            purrRelease = nil
            lastResult = String(localized: "นี่คือ dev build ไม่ได้เช็กเวอร์ชัน")
            return
        }
        // A manual check shows skipped versions again.
        let skipped = manual ? nil : defaults.string(forKey: Prefs.skippedVersion)
        guard let release, release.isNewer(than: current, skipping: skipped), let version = release.version else {
            purrRelease = nil
            lastResult = String(localized: "ใช้เวอร์ชันล่าสุดอยู่แล้ว (\(AppInfo.versionText))")
            return
        }
        purrRelease = release
        lastResult = String(localized: "มีเวอร์ชันใหม่ v\(version.description)")

        if defaults.string(forKey: Prefs.notifiedVersion) != version.description {
            defaults.set(version.description, forKey: Prefs.notifiedVersion)
            Notifier.shared.post(id: "update", title: String(localized: "Purr v\(version.description) มาแล้ว 🎁"),
                                 body: String(localized: "คลิกเพื่อดูว่ามีอะไรใหม่และดาวน์โหลด"),
                                 url: release.htmlUrl)
        }
    }

    /// `nil` inside `.success` means the repository has no releases yet.
    private static func latestRelease(_ repo: String) async -> Result<GitHubRelease?, Error> {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Purr/\(AppInfo.version?.description ?? "dev")", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 404 { return .success(nil) }
            guard code == 200 else { throw URLError(.badServerResponse) }
            return .success(try GitHubRelease.decode(data))
        } catch {
            return .failure(error)
        }
    }
}
