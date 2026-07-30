import MCP

indirect enum AgentControlToolSchema {
    case string(String, enumValues: [String] = [])
    case integer(String, maximum: Int? = nil)
    case boolean(String)
    case array(String, items: AgentControlToolSchema)
    case object(String, properties: [String: AgentControlToolSchema], required: [String] = [])

    var value: Value {
        switch self {
        case .string(let description, let enumValues):
            var fields: [String: Value] = ["type": .string("string"), "description": .string(description)]
            if !enumValues.isEmpty { fields["enum"] = .array(enumValues.map(Value.string)) }
            return .object(fields)
        case .integer(let description, let maximum):
            var fields: [String: Value] = ["type": .string("integer"), "description": .string(description)]
            if let maximum { fields["maximum"] = .int(maximum) }
            return .object(fields)
        case .boolean(let description):
            return .object(["type": .string("boolean"), "description": .string(description)])
        case .array(let description, let items):
            return .object([
                "type": .string("array"), "description": .string(description), "items": items.value,
            ])
        case .object(let description, let properties, let required):
            var fields: [String: Value] = [
                "type": .string("object"), "description": .string(description),
                "properties": .object(properties.mapValues(\.value)),
            ]
            if !required.isEmpty { fields["required"] = .array(required.map(Value.string)) }
            return .object(fields)
        }
    }

    static func inputSchema(_ properties: [String: AgentControlToolSchema], required: [String] = []) -> Value {
        var fields: [String: Value] = [
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "properties": .object(properties.mapValues(\.value)),
        ]
        if !required.isEmpty { fields["required"] = .array(required.map(Value.string)) }
        return .object(fields)
    }
}
