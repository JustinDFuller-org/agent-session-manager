enum OpenCodeLaunchPolicy {
    private static let controlledFlags: Set<String> = ["--hostname", "--mdns", "--mdns-domain", "--port"]

    static func sanitize(_ arguments: [String]) -> [String] {
        var result: [String] = []
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            let flag = argument.split(separator: "=", maxSplits: 1).first.map(String.init) ?? argument
            if controlledFlags.contains(flag) {
                if !argument.contains("="), index + 1 < arguments.count,
                    !arguments[index + 1].hasPrefix("--")
                {
                    index += 1
                }
                index += 1
                continue
            }
            result.append(argument)
            index += 1
        }
        return result
    }
}
