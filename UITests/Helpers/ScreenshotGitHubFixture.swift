import Foundation

struct ScreenshotGitHubFixture {
    let directory: URL
    let stateURL: URL
    let pullRequestNumber = 42
    let pullRequestTitle = "Add screenshot coverage"

    init() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "agent-session-manager-screenshot-github-fixture-\(UUID().uuidString)")
        directory = root
        stateURL = root.appending(path: "state.json")

        let binURL = root.appending(path: "bin", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: binURL, withIntermediateDirectories: true)
        let script = #"""
            #!/usr/bin/env python3
            import json
            import os
            import re
            import sys

            args = sys.argv[1:]
            if len(args) >= 3 and args[0] == "api" and args[1] == "graphql" and "--input" in args:
                input_path = args[args.index("--input") + 1]
                with open(input_path, encoding="utf-8") as handle:
                    query = json.load(handle).get("query", "")
                with open(os.environ["AGENT_SESSION_MANAGER_SCREENSHOT_PR_STATE"], encoding="utf-8") as handle:
                    state = json.load(handle)

                aliases = re.findall(r"(pane_[0-9A-Fa-f]+): repository", query)
                node = {
                    "number": int(os.environ["AGENT_SESSION_MANAGER_SCREENSHOT_PR_NUMBER"]),
                    "title": os.environ["AGENT_SESSION_MANAGER_SCREENSHOT_PR_TITLE"],
                    "state": state["state"].upper(),
                    "url": "https://github.com/test-owner/test-repository/pull/42",
                    "isDraft": False,
                    "mergeable": "MERGEABLE",
                    "reviewDecision": "APPROVED",
                    "commits": {"nodes": []},
                    "reviewThreads": {"totalCount": 0},
                }
                data = {
                    alias: {"pullRequests": {"nodes": [node]}}
                    for alias in aliases
                }
                print("HTTP/1.1 200 OK")
                print("Content-Type: application/json")
                print()
                print(json.dumps({"data": data}))
                sys.exit(0)

            original_path = os.environ.get("AGENT_SESSION_MANAGER_SCREENSHOT_ORIGINAL_PATH", "")
            for directory in original_path.split(":"):
                candidate = os.path.join(directory, "gh")
                if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
                    os.execv(candidate, [candidate] + args)
            sys.exit(127)
            """#
        let scriptURL = binURL.appending(path: "gh")
        try? script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        writeState("open")
    }

    var launchEnvironment: [String: String] {
        let binPath = directory.appending(path: "bin").path
        let originalPath = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        return [
            "PATH": "\(binPath):\(originalPath)",
            "AGENT_SESSION_MANAGER_SCREENSHOT_ORIGINAL_PATH": originalPath,
            "AGENT_SESSION_MANAGER_SCREENSHOT_PR_STATE": stateURL.path,
            "AGENT_SESSION_MANAGER_SCREENSHOT_PR_NUMBER": String(pullRequestNumber),
            "AGENT_SESSION_MANAGER_SCREENSHOT_PR_TITLE": pullRequestTitle,
        ]
    }

    func markMerged() {
        writeState("merged")
    }

    private func writeState(_ state: String) {
        let data = Data("{\"state\":\"\(state)\"}".utf8)
        try? data.write(to: stateURL)
    }
}
