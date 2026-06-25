-- [⊞ ◈] [▽ ☰ ☷ ☴ ☵ ☲ ☶ ☳ ☱ △]
-- ProcessLang :: Canon
-- Glyph-first source of truth for operators, layers, and topology.

local canon = {}

canon.version = "1.0"
canon.source = "ProcessLang canonical operator topology"

canon.layers = {
    ["⋯"] = {
        name = "chaos",
        meaning = "raw potential before stable holding",
    },
    ["⊞"] = {
        name = "table",
        meaning = "addressability, relation layout, primary structure",
    },
    ["◈"] = {
        name = "crystall",
        meaning = "stable form, assembled structure, operational holding",
    },
    ["▲"] = {
        name = "manifest",
        meaning = "appeared object, exported result, world-facing thing",
    },
}

canon.operators = {
    ["▽"] = {
        name = "FLOW",
        layers = {"⋯"},
        core = "x→f→x′",
        adjacent = {"☰", "☷", "☴"},
    },
    ["☰"] = {
        name = "CONNECT",
        layers = {"⋯", "⊞"},
        core = "a+b→rel",
        adjacent = {"▽", "☷", "☴", "☵"},
    },
    ["☷"] = {
        name = "DISSOLVE",
        layers = {"⋯", "⊞"},
        core = "rel→parts",
        adjacent = {"▽", "☰", "☴", "☳"},
    },
    ["☴"] = {
        name = "OBSERVE",
        layers = {"⊞"},
        core = "observe(x)",
        adjacent = {"▽", "☰", "☷", "☵", "☳", "☱"},
    },
    ["☵"] = {
        name = "ENCODE",
        layers = {"⊞", "◈"},
        core = "x*→pattern",
        adjacent = {"☰", "☴", "☱", "☳", "☲"},
    },
    ["☳"] = {
        name = "CHOOSE",
        layers = {"⊞", "◈"},
        core = "{paths}→1",
        adjacent = {"☷", "☴", "☱", "☵", "☶"},
    },
    ["☲"] = {
        name = "CYCLE",
        layers = {"◈"},
        core = "iterate fⁿ(x)",
        adjacent = {"☵", "☶", "△", "☱"},
    },
    ["☶"] = {
        name = "LOGIC",
        layers = {"◈"},
        core = "rules(x)",
        adjacent = {"☳", "☲", "☱", "△"},
    },
    ["☱"] = {
        name = "RUNTIME",
        layers = {"◈"},
        core = "ctx→state′",
        adjacent = {"☴", "△", "☵", "☳", "☶", "☲"},
    },
    ["△"] = {
        name = "MANIFEST",
        layers = {"▲"},
        core = "output",
        adjacent = {"☱", "☲", "☶"},
    },
}

canon.inventory_order = {"▽", "☰", "☷", "☵", "☳", "☴", "☲", "☶", "☱", "△"}
canon.trace_order = {"▽", "☰", "☷", "☴", "☵", "☲", "☶", "☳", "☱", "△"}

canon.aliases = {}
for glyph, operator in pairs(canon.operators) do
    canon.aliases[operator.name] = glyph
end

function canon.resolve(value)
    return canon.operators[value] and value or canon.aliases[value]
end

function canon.is_adjacent(left, right)
    local left_glyph = canon.resolve(left)
    local right_glyph = canon.resolve(right)
    local operator = left_glyph and canon.operators[left_glyph]

    if not operator or not right_glyph then
        return false
    end

    for _, glyph in ipairs(operator.adjacent) do
        if glyph == right_glyph then
            return true
        end
    end

    return false
end

function canon.is_valid_trace(trace)
    for index = 1, #trace - 1 do
        if not canon.is_adjacent(trace[index], trace[index + 1]) then
            return false, index
        end
    end

    return true
end

return canon
