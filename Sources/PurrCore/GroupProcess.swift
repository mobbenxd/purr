import Darwin
import Foundation

/// Runs a command in its own process group so that stopping it also stops
/// everything it spawned. `mo` is a shell wrapper: terminating only its pid
/// leaves helpers such as `status-go` running as orphans.
public final class GroupProcess: @unchecked Sendable {
    public let executable: String
    public let arguments: [String]
    public var environment: [String: String]
    /// Runs the whole group at a lower CPU priority (for background work).
    public var lowPriority = false

    /// Called on a background queue for each chunk of stdout/stderr.
    /// Set both callbacks before `start()` and leave them alone afterwards.
    public var onOutput: (@Sendable (Data) -> Void)?
    /// Called once on a background queue after the process exited and its
    /// output was drained. Negative values mean "killed by signal".
    public var onExit: (@Sendable (Int32) -> Void)?

    public private(set) var pid: pid_t = 0

    private let queue = DispatchQueue(label: "purr.groupprocess")
    private var exitStatus: Int32?
    private var outputClosed = false
    private var reported = false
    private var readHandle: FileHandle?

    public init(executable: String, arguments: [String], environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
    }

    public func start() throws {
        let pipe = Pipe()
        let writeFD = pipe.fileHandleForWriting.fileDescriptor

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, writeFD, 1)
        posix_spawn_file_actions_adddup2(&actions, writeFD, 2)

        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        defer { posix_spawnattr_destroy(&attr) }
        // New process group (pgid = pid), and no other inherited descriptors.
        posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT
                                              | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK))
        posix_spawnattr_setpgroup(&attr, 0)
        // The app ignores SIGTERM/SIGINT (it handles them itself) and ignored
        // signals survive exec; restore defaults so Stop can end `mo` politely.
        var defaults = sigset_t()
        sigemptyset(&defaults)
        for sig in [SIGPIPE, SIGTERM, SIGINT, SIGHUP, SIGQUIT] { sigaddset(&defaults, sig) }
        posix_spawnattr_setsigdefault(&attr, &defaults)
        var mask = sigset_t()
        sigemptyset(&mask)
        posix_spawnattr_setsigmask(&attr, &mask)

        let argv = ([executable] + arguments).map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            argv.forEach { free($0) }
            envp.forEach { free($0) }
        }

        var child: pid_t = 0
        let result = posix_spawn(&child, executable, &actions, &attr, argv, envp)
        try? pipe.fileHandleForWriting.close()
        guard result == 0 else {
            try? pipe.fileHandleForReading.close()
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(result))
        }
        pid = child
        if lowPriority { setpriority(PRIO_PGRP, id_t(child), 10) }

        let handle = pipe.fileHandleForReading
        readHandle = handle
        handle.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard let self else { return }
            if data.isEmpty {
                h.readabilityHandler = nil
                self.queue.async { self.outputClosed = true; self.reportIfDone() }
            } else {
                self.onOutput?(data)
            }
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            var status: Int32 = 0
            while waitpid(child, &status, 0) == -1 && errno == EINTR {}
            let code = (status & 0x7f) == 0 ? (status >> 8) & 0xff : -(status & 0x7f)
            // Helpers left behind would otherwise keep the pipe open forever.
            kill(-child, SIGTERM)
            guard let self else { return }
            self.queue.async {
                self.exitStatus = code
                self.reportIfDone()
            }
            self.queue.asyncAfter(deadline: .now() + 2) {
                self.outputClosed = true
                self.reportIfDone()
            }
        }
    }

    public var isRunning: Bool {
        queue.sync { pid != 0 && exitStatus == nil }
    }

    /// SIGTERM to the whole group, then SIGKILL whatever is still alive.
    /// Does nothing once the process has exited, so a late call can never hit
    /// an unrelated group that reused the id.
    public func terminate(grace: TimeInterval = 3) {
        queue.async { [self] in
            let group = pid
            guard group > 0, exitStatus == nil else { return }
            kill(-group, SIGTERM)
            queue.asyncAfter(deadline: .now() + grace) { [self] in
                if exitStatus == nil { kill(-group, SIGKILL) }
            }
        }
    }

    private func reportIfDone() {
        guard !reported, outputClosed, let code = exitStatus else { return }
        reported = true
        readHandle?.readabilityHandler = nil
        try? readHandle?.close()
        onExit?(code)
    }
}

extension GroupProcess {
    /// Runs to completion and returns everything it printed.
    public static func capture(_ executable: String, _ arguments: [String],
                               environment: [String: String] = ProcessInfo.processInfo.environment,
                               lowPriority: Bool = false,
                               timeout: TimeInterval = 600) async throws -> (status: Int32, output: Data) {
        let process = GroupProcess(executable: executable, arguments: arguments, environment: environment)
        process.lowPriority = lowPriority
        let collected = Collected()
        let timeoutKill = DispatchWorkItem { process.terminate(grace: 1) }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.onOutput = { collected.append($0) }
                process.onExit = {
                    timeoutKill.cancel()
                    continuation.resume(returning: ($0, collected.data))
                }
                do {
                    try process.start()
                    DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutKill)
                    // Cancelled before the process existed: onCancel had nothing to stop.
                    if Task.isCancelled { process.terminate(grace: 1) }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            process.terminate(grace: 1)
        }
    }

    private final class Collected: @unchecked Sendable {
        private let lock = NSLock()
        private var buffer = Data()
        func append(_ data: Data) { lock.withLock { buffer.append(data) } }
        var data: Data { lock.withLock { buffer } }
    }
}
