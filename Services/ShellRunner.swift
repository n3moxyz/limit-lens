import Foundation

struct ShellResult {
    var stdout: String
    var stderr: String
    var status: Int32
}

enum ShellRunner {
    enum ShellError: LocalizedError {
        case emptyOutput(command: String, status: Int32)
        case launchFailed(String)

        var errorDescription: String? {
            switch self {
            case let .emptyOutput(command, status):
                "Command produced no usable output: \(command) (exit \(status))"
            case let .launchFailed(message):
                message
            }
        }
    }

    static func run(_ command: String, timeout: TimeInterval = 8) async throws -> ShellResult {
        try await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                throw ShellError.launchFailed(error.localizedDescription)
            }

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                if process.isRunning {
                    process.terminate()
                }
            }

            let stdoutData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            return ShellResult(
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? "",
                status: process.terminationStatus
            )
        }.value
    }
}
