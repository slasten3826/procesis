// ============================================================
// Packet :: Layer 3 — CALM (Trigram VM)
// Deterministic. 3-bit instructions. I Ching semantics.
//
// ☰ Heaven (111) = CONNECT  = [ (start cycle)
// ☷ Earth  (000) = DISSOLVE = ] (end cycle)
// ☲ Fire   (101) = CYCLE    = > (advance)
// ☱ Lake   (110) = RUNTIME  = < (retreat)
// ☴ Wind   (011) = OBSERVE  = + (increment)
// ☶ Mountain(001)= LOGIC    = - (decrement)
// ☵ Water  (010) = ENCODE   = . (output)
// ☳ Thunder(100) = CHOOSE   = , (input)
//
// 3 bits per instruction. 38% of Brainfuck size.
// No opcode table needed — bits ARE the instruction.
// ============================================================

const std = @import("std");
const layer0 = @import("layer0_substrate.zig");

const Substrate = layer0.Substrate(layer0.DEFAULT_CONFIG);

// Trigram opcodes (3-bit)
pub const Op = struct {
    pub const HEAVEN: u3 = 0b111;   // ☰ [ start cycle
    pub const EARTH: u3 = 0b000;    // ☷ ] end cycle
    pub const FIRE: u3 = 0b101;     // ☲ > advance
    pub const LAKE: u3 = 0b110;     // ☱ < retreat
    pub const WIND: u3 = 0b011;     // ☴ + increment
    pub const MOUNTAIN: u3 = 0b001; // ☶ - decrement
    pub const WATER: u3 = 0b010;    // ☵ . output
    pub const THUNDER: u3 = 0b100;  // ☳ , input
};

pub const MAX_PROGRAM = 8192;
pub const MAX_BRACKETS = 512;

pub const CalmVM = struct {
    const Self = @This();

    sub: *Substrate,

    // Program storage (3-bit values packed as u8 for simplicity)
    program: [MAX_PROGRAM]u3,
    program_len: u32,

    // Bracket matching (pre-computed for O(1) jumps)
    bracket_match: [MAX_BRACKETS]u32,  // index → matching index
    bracket_from: [MAX_BRACKETS]u32,   // source positions
    bracket_to: [MAX_BRACKETS]u32,     // target positions
    bracket_count: u32,

    // Execution state
    pc: u32,
    total_ticks: u32,
    halted: bool,

    // Crystal layers info
    layers_count: u32,

    pub fn init(substrate: *Substrate) Self {
        var vm = Self{
            .sub = substrate,
            .program = undefined,
            .program_len = 0,
            .bracket_match = undefined,
            .bracket_from = undefined,
            .bracket_to = undefined,
            .bracket_count = 0,
            .pc = 0,
            .total_ticks = 0,
            .halted = false,
            .layers_count = 0,
        };
        @memset(&vm.program, 0);
        return vm;
    }

    /// Add a crystal layer (append trigram code)
    pub fn add_layer(self: *Self, code: []const u3) void {
        for (code) |op| {
            if (self.program_len >= MAX_PROGRAM) break;
            self.program[self.program_len] = op;
            self.program_len += 1;
        }
        self.layers_count += 1;
        self.rebuild_brackets();
    }

    /// Add layer from raw bytes (each byte = one trigram, low 3 bits)
    pub fn add_layer_bytes(self: *Self, bytes: []const u8) void {
        for (bytes) |b| {
            if (self.program_len >= MAX_PROGRAM) break;
            self.program[self.program_len] = @intCast(b & 0x07);
            self.program_len += 1;
        }
        self.layers_count += 1;
        self.rebuild_brackets();
    }

    fn rebuild_brackets(self: *Self) void {
        // Pre-compute bracket matching for ☰/☷ pairs
        var stack: [256]u32 = undefined;
        var sp: u32 = 0;
        self.bracket_count = 0;

        var i: u32 = 0;
        while (i < self.program_len) : (i += 1) {
            if (self.program[i] == Op.HEAVEN) {
                if (sp < 256) {
                    stack[sp] = i;
                    sp += 1;
                }
            } else if (self.program[i] == Op.EARTH) {
                if (sp > 0) {
                    sp -= 1;
                    const open = stack[sp];
                    if (self.bracket_count + 1 < MAX_BRACKETS) {
                        // Store both directions
                        self.bracket_from[self.bracket_count] = open;
                        self.bracket_to[self.bracket_count] = i;
                        self.bracket_count += 1;
                        self.bracket_from[self.bracket_count] = i;
                        self.bracket_to[self.bracket_count] = open;
                        self.bracket_count += 1;
                    }
                }
            }
        }
    }

    fn find_match(self: *const Self, pos: u32) u32 {
        var i: u32 = 0;
        while (i < self.bracket_count) : (i += 1) {
            if (self.bracket_from[i] == pos) return self.bracket_to[i];
        }
        return pos; // no match found, stay
    }

    /// Execute one tick
    pub fn tick(self: *Self) bool {
        if (self.halted or self.pc >= self.program_len) {
            self.halted = true;
            return false;
        }

        if (!self.sub.power.spend(layer0.Power.COST_CALM_TICK)) {
            self.halted = true;
            return false;
        }

        const op = self.program[self.pc];
        const ptr = self.sub.mem.calm_ptr;

        switch (op) {
            Op.HEAVEN => { // ☰ [ start cycle
                if (self.sub.mem.calm_read(ptr) == 0) {
                    self.pc = self.find_match(self.pc);
                }
            },
            Op.EARTH => { // ☷ ] end cycle
                if (self.sub.mem.calm_read(ptr) != 0) {
                    self.pc = self.find_match(self.pc);
                }
            },
            Op.FIRE => { // ☲ > advance
                if (self.sub.mem.calm_ptr < layer0.DEFAULT_CONFIG.calm_tape_size - 1) {
                    self.sub.mem.calm_ptr += 1;
                }
            },
            Op.LAKE => { // ☱ < retreat
                if (self.sub.mem.calm_ptr > 0) {
                    self.sub.mem.calm_ptr -= 1;
                }
            },
            Op.WIND => { // ☴ + increment
                const val = self.sub.mem.calm_read(ptr);
                self.sub.mem.calm_write(ptr, val +% 1);
            },
            Op.MOUNTAIN => { // ☶ - decrement
                const val = self.sub.mem.calm_read(ptr);
                self.sub.mem.calm_write(ptr, val -% 1);
            },
            Op.WATER => { // ☵ . output
                _ = self.sub.io_write(self.sub.mem.calm_read(ptr));
            },
            Op.THUNDER => { // ☳ , input
                if (self.sub.io_read()) |byte| {
                    self.sub.mem.calm_write(ptr, byte);
                }
            },
        }

        self.pc += 1;
        self.total_ticks += 1;
        self.sub.tick();
        return true;
    }

    /// Run until halt or max ticks
    pub fn run(self: *Self, max_ticks: u32) u32 {
        var count: u32 = 0;
        while (count < max_ticks and self.tick()) {
            count += 1;
        }
        return count;
    }
};

// ============================================================
// Tests
// ============================================================

test "Trigram VM: Hello World (A=65)" {
    // BF: ++++++++[>++++++++<-]>+.
    // = 8×wind, heaven, fire, 8×wind, lake, mountain, earth, fire, wind, water
    var sub = Substrate.init(10000);
    var vm = CalmVM.init(&sub);

    const program = [_]u3{
        Op.WIND, Op.WIND, Op.WIND, Op.WIND, Op.WIND, Op.WIND, Op.WIND, Op.WIND, // ++++++++
        Op.HEAVEN,                                                                  // [
        Op.FIRE,                                                                    // >
        Op.WIND, Op.WIND, Op.WIND, Op.WIND, Op.WIND, Op.WIND, Op.WIND, Op.WIND, // ++++++++
        Op.LAKE,                                                                    // <
        Op.MOUNTAIN,                                                                // -
        Op.EARTH,                                                                   // ]
        Op.FIRE,                                                                    // >
        Op.WIND,                                                                    // +
        Op.WATER,                                                                   // .
    };

    vm.add_layer(&program);
    _ = vm.run(10000);

    // Output should be 65 ('A')
    const out = sub.output.pop();
    try std.testing.expectEqual(@as(u8, 65), out.?);
}

test "Trigram VM: Count to 3" {
    // BF: +++.+.+.
    var sub = Substrate.init(10000);
    var vm = CalmVM.init(&sub);

    const program = [_]u3{
        Op.WIND, Op.WIND, Op.WIND, Op.WATER,  // +++.
        Op.WIND, Op.WATER,                       // +.
        Op.WIND, Op.WATER,                       // +.
    };

    vm.add_layer(&program);
    _ = vm.run(1000);

    try std.testing.expectEqual(@as(u8, 3), sub.output.pop().?);
    try std.testing.expectEqual(@as(u8, 4), sub.output.pop().?);
    try std.testing.expectEqual(@as(u8, 5), sub.output.pop().?);
}

test "Trigram VM: Multiply 5x7=35" {
    // BF: +++++[>+++++++<-]>.
    var sub = Substrate.init(10000);
    var vm = CalmVM.init(&sub);

    const program = [_]u3{
        Op.WIND, Op.WIND, Op.WIND, Op.WIND, Op.WIND,                             // +++++
        Op.HEAVEN,                                                                  // [
        Op.FIRE,                                                                    // >
        Op.WIND, Op.WIND, Op.WIND, Op.WIND, Op.WIND, Op.WIND, Op.WIND,          // +++++++
        Op.LAKE,                                                                    // <
        Op.MOUNTAIN,                                                                // -
        Op.EARTH,                                                                   // ]
        Op.FIRE,                                                                    // >
        Op.WATER,                                                                   // .
    };

    vm.add_layer(&program);
    _ = vm.run(10000);

    try std.testing.expectEqual(@as(u8, 35), sub.output.pop().?);
}

test "Trigram VM: Multiple layers" {
    var sub = Substrate.init(10000);
    var vm = CalmVM.init(&sub);

    // Layer 1: set cell to 10
    const layer1 = [_]u3{
        Op.WIND, Op.WIND, Op.WIND, Op.WIND, Op.WIND,
        Op.WIND, Op.WIND, Op.WIND, Op.WIND, Op.WIND, // ++++++++++
        Op.WATER,                                        // .
    };

    // Layer 2: add 5 more, output
    const layer2 = [_]u3{
        Op.WIND, Op.WIND, Op.WIND, Op.WIND, Op.WIND, // +++++
        Op.WATER,                                        // .
    };

    vm.add_layer(&layer1);
    vm.add_layer(&layer2);
    _ = vm.run(1000);

    try std.testing.expectEqual(@as(u8, 10), sub.output.pop().?);
    try std.testing.expectEqual(@as(u8, 15), sub.output.pop().?);
    try std.testing.expectEqual(@as(u32, 2), vm.layers_count);
}
