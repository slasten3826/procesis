// ============================================================
// Packet :: Layer 0 — Substrate
// Hardware abstraction. Static memory. Zero allocations.
// Zig freestanding / embedded target.
//
// API for Layer 1/2/3:
//   mem    — static memory regions
//   io     — input/output buffers
//   clock  — tick counter, entropy source
//   power  — PU budget, sleep/wake
//
// Targets:
//   linux  — testing (stdin/stdout, clock_gettime)
//   esp32  — production (UART/SPI/Radio, hardware timer)
//   psp    — experiment (MIPS, custom I/O)
// ============================================================

const std = @import("std");

// ============================================================
// Configuration (comptime)
// ============================================================

pub const Config = struct {
    // Layer 1: Chaos VM memory
    chaos_cells: u32 = 59049, // 3^10
    chaos_cell_bytes: u32 = 2, // uint16 per cell

    // Layer 3: Calm VM tape
    calm_tape_size: u32 = 30000,
    calm_cell_bytes: u32 = 1, // uint8 per cell

    // I/O buffers
    input_buffer_size: u32 = 256,
    output_buffer_size: u32 = 256,

    // PU budget
    default_pu_budget: u32 = 10000,

    // Timing
    ticks_per_second: u32 = 240_000_000, // ESP32 @ 240MHz

    pub fn chaos_mem_bytes(self: Config) u32 {
        return self.chaos_cells * self.chaos_cell_bytes; // 118098
    }

    pub fn calm_mem_bytes(self: Config) u32 {
        return self.calm_tape_size * self.calm_cell_bytes; // 30000
    }

    pub fn total_mem_bytes(self: Config) u32 {
        return self.chaos_mem_bytes() +
            self.calm_mem_bytes() +
            self.input_buffer_size +
            self.output_buffer_size;
    }
};

pub const DEFAULT_CONFIG = Config{};

// ============================================================
// Memory: Static regions, zero allocations
// ============================================================

pub fn Memory(comptime config: Config) type {
    return struct {
        const Self = @This();

        // Layer 1: Chaos VM — 59049 × uint16
        chaos: [config.chaos_cells]u16,

        // Layer 3: Calm VM — 30000 × uint8
        calm: [config.calm_tape_size]u8,

        // Registers (Layer 1)
        reg_a: u16,
        reg_c: u16,
        reg_d: u16,

        // Calm VM state
        calm_ptr: u32,
        calm_pc: u32,
        calm_program_len: u32,

        pub fn init() Self {
            return Self{
                .chaos = [_]u16{0} ** config.chaos_cells,
                .calm = [_]u8{0} ** config.calm_tape_size,
                .reg_a = 0,
                .reg_c = 0,
                .reg_d = 0,
                .calm_ptr = 0,
                .calm_pc = 0,
                .calm_program_len = 0,
            };
        }

        // --- Chaos memory access ---

        pub fn chaos_read(self: *const Self, addr: u16) u16 {
            return self.chaos[@intCast(addr % config.chaos_cells)];
        }

        pub fn chaos_write(self: *Self, addr: u16, val: u16) void {
            self.chaos[@intCast(addr % config.chaos_cells)] = val;
        }

        // --- Calm tape access ---

        pub fn calm_read(self: *const Self, addr: u32) u8 {
            if (addr >= config.calm_tape_size) return 0;
            return self.calm[@intCast(addr)];
        }

        pub fn calm_write(self: *Self, addr: u32, val: u8) void {
            if (addr >= config.calm_tape_size) return;
            self.calm[@intCast(addr)] = val;
        }
    };
}

// ============================================================
// I/O: Ring buffers for input/output
// ============================================================

pub fn RingBuffer(comptime size: u32) type {
    return struct {
        const Self = @This();

        data: [size]u8,
        read_pos: u32,
        write_pos: u32,
        count: u32,

        pub fn init() Self {
            return Self{
                .data = [_]u8{0} ** size,
                .read_pos = 0,
                .write_pos = 0,
                .count = 0,
            };
        }

        pub fn push(self: *Self, byte: u8) bool {
            if (self.count >= size) return false;
            self.data[@intCast(self.write_pos)] = byte;
            self.write_pos = (self.write_pos + 1) % size;
            self.count += 1;
            return true;
        }

        pub fn pop(self: *Self) ?u8 {
            if (self.count == 0) return null;
            const byte = self.data[@intCast(self.read_pos)];
            self.read_pos = (self.read_pos + 1) % size;
            self.count -= 1;
            return byte;
        }

        pub fn is_empty(self: *const Self) bool {
            return self.count == 0;
        }

        pub fn is_full(self: *const Self) bool {
            return self.count >= size;
        }

        pub fn available(self: *const Self) u32 {
            return self.count;
        }

        // Fill from slice (for loading input data)
        pub fn fill(self: *Self, data: []const u8) u32 {
            var written: u32 = 0;
            for (data) |byte| {
                if (!self.push(byte)) break;
                written += 1;
            }
            return written;
        }
    };
}

// ============================================================
// Clock: Tick counter + entropy source
// ============================================================

pub const Clock = struct {
    ticks: u64,
    start_ticks: u64,

    pub fn init() Clock {
        return Clock{
            .ticks = 0,
            .start_ticks = 0,
        };
    }

    pub fn tick(self: *Clock) void {
        self.ticks += 1;
    }

    pub fn elapsed(self: *const Clock) u64 {
        return self.ticks - self.start_ticks;
    }

    pub fn reset(self: *Clock) void {
        self.start_ticks = self.ticks;
    }

    /// Entropy from tick counter — mix with chaos state for seeding
    pub fn entropy_byte(self: *const Clock) u8 {
        // Simple hash of tick counter
        const t = self.ticks;
        const mixed = t ^ (t >> 7) ^ (t >> 13) ^ (t >> 23);
        return @intCast(mixed & 0xFF);
    }
};

// ============================================================
// Power: PU budget + sleep/wake
// ============================================================

pub const Power = struct {
    pu_budget: i32,
    pu_total: i32,
    sleeping: bool,

    // PU costs (comptime-known)
    pub const COST_CHAOS_TICK: i32 = 1;
    pub const COST_OBSERVE: i32 = 1;
    pub const COST_ENCODE: i32 = 50;
    pub const COST_CALM_TICK: i32 = 1;
    pub const COST_IO: i32 = 2;

    pub fn init(budget: i32) Power {
        return Power{
            .pu_budget = budget,
            .pu_total = budget,
            .sleeping = false,
        };
    }

    pub fn spend(self: *Power, cost: i32) bool {
        if (self.pu_budget < cost) {
            self.sleeping = true;
            return false;
        }
        self.pu_budget -= cost;
        return true;
    }

    pub fn remaining(self: *const Power) i32 {
        return self.pu_budget;
    }

    pub fn fraction(self: *const Power) f32 {
        if (self.pu_total <= 0) return 0.0;
        return @as(f32, @floatFromInt(self.pu_budget)) / @as(f32, @floatFromInt(self.pu_total));
    }

    pub fn is_alive(self: *const Power) bool {
        return !self.sleeping and self.pu_budget > 0;
    }

    pub fn wake(self: *Power, new_budget: i32) void {
        self.pu_budget = new_budget;
        self.pu_total = new_budget;
        self.sleeping = false;
    }
};

// ============================================================
// Substrate: Ties everything together
// ============================================================

pub fn Substrate(comptime config: Config) type {
    return struct {
        const Self = @This();

        mem: Memory(config),
        input: RingBuffer(config.input_buffer_size),
        output: RingBuffer(config.output_buffer_size),
        clock: Clock,
        power: Power,

        pub fn init(pu_budget: i32) Self {
            return Self{
                .mem = Memory(config).init(),
                .input = RingBuffer(config.input_buffer_size).init(),
                .output = RingBuffer(config.output_buffer_size).init(),
                .clock = Clock.init(),
                .power = Power.init(pu_budget),
            };
        }

        // --- Layer 0 API ---

        /// Read one byte from input (FLOW)
        pub fn io_read(self: *Self) ?u8 {
            if (!self.power.spend(Power.COST_IO)) return null;
            return self.input.pop();
        }

        /// Write one byte to output (MANIFEST)
        pub fn io_write(self: *Self, byte: u8) bool {
            if (!self.power.spend(Power.COST_IO)) return false;
            return self.output.push(byte);
        }

        /// Advance system clock
        pub fn tick(self: *Self) void {
            self.clock.tick();
        }

        /// Get entropy byte (for seeding chaos)
        pub fn entropy(self: *const Self) u8 {
            return self.clock.entropy_byte();
        }

        /// Check if system is alive
        pub fn alive(self: *const Self) bool {
            return self.power.is_alive();
        }

        /// Sleep (PU exhausted)
        pub fn sleep(self: *Self) void {
            self.power.sleeping = true;
        }

        /// Wake with new PU budget
        pub fn wake(self: *Self, budget: i32) void {
            self.power.wake(budget);
        }

        /// Drain output buffer to slice
        pub fn drain_output(self: *Self, buf: []u8) u32 {
            var i: u32 = 0;
            while (i < buf.len) {
                if (self.output.pop()) |byte| {
                    buf[@intCast(i)] = byte;
                    i += 1;
                } else break;
            }
            return i;
        }

        /// Status report
        pub fn status(self: *const Self) Status {
            return Status{
                .ticks = self.clock.ticks,
                .pu_remaining = self.power.remaining(),
                .pu_fraction = self.power.fraction(),
                .input_pending = self.input.available(),
                .output_pending = self.output.available(),
                .sleeping = self.power.sleeping,
            };
        }
    };
}

pub const Status = struct {
    ticks: u64,
    pu_remaining: i32,
    pu_fraction: f32,
    input_pending: u32,
    output_pending: u32,
    sleeping: bool,
};

// ============================================================
// Crazy operation (shared between layers)
// ============================================================

const CRAZY_TABLE = [3][3]u8{
    [_]u8{ 1, 0, 0 },
    [_]u8{ 1, 0, 2 },
    [_]u8{ 2, 2, 1 },
};

pub fn crazy(a: u16, d: u16) u16 {
    var result: u32 = 0;
    var power: u32 = 1;
    var aa: u32 = @intCast(a);
    var dd: u32 = @intCast(d);
    for (0..10) |_| {
        result += @as(u32, CRAZY_TABLE[dd % 3][aa % 3]) * power;
        aa /= 3;
        dd /= 3;
        power *= 3;
    }
    return @intCast(result % 59049);
}

pub fn rotr(val: u16) u16 {
    const v: u32 = @intCast(val);
    const pow3_9: u32 = 19683; // 3^9
    return @intCast(v / 3 + (v % 3) * pow3_9);
}

// ============================================================
// XLAT1 table (self-encryption / DISSOLVE)
// ============================================================

pub const XLAT1 = [94]u8{
    '+', 'b', '(', '2', '9', 'e', '*', 'j', '1', 'V',
    'M', 'E', 'K', 'L', 'y', 'C', '}', ')', '8', '&',
    'm', '#', '~', 'W', '>', 'q', 'x', 'd', 'R', 'p',
    '0', 'w', 'k', 'r', 'U', 'o', '[', 'D', '7', ',',
    'X', 'T', 'c', 'A', '"', 'l', 'I', '.', 'v', '%',
    '{', 'g', 'J', 'h', '4', 'G', '\\', '-', '=', 'O',
    '@', '5', '`', '_', '3', 'i', '<', '?', 'Z', '\'',
    ';', 'F', 'N', 'Q', 'u', 'Y', ']', 's', 'z', 'f',
    '$', '!', 'B', 'S', '/', '|', 't', ':', 'P', 'n',
    '6', '^', 'H', 'a',
};

pub fn encrypt(val: u16) u16 {
    return @intCast(XLAT1[@intCast(val % 94)]);
}

pub fn decode_instruction(mem_val: u16, pos: u16) u8 {
    const v: u32 = @intCast(mem_val);
    const p: u32 = @intCast(pos);
    return @intCast((v -% 33 +% p) % 94);
}

// ============================================================
// Tests
// ============================================================

test "config sizes" {
    const c = DEFAULT_CONFIG;
    try std.testing.expectEqual(@as(u32, 118098), c.chaos_mem_bytes());
    try std.testing.expectEqual(@as(u32, 30000), c.calm_mem_bytes());
    // Total < 150KB — fits in ESP32 (520KB RAM)
    try std.testing.expect(c.total_mem_bytes() < 150000);
}

test "memory init" {
    var mem = Memory(DEFAULT_CONFIG).init();
    try std.testing.expectEqual(@as(u16, 0), mem.chaos_read(0));
    try std.testing.expectEqual(@as(u16, 0), mem.chaos_read(59048));
    mem.chaos_write(100, 42);
    try std.testing.expectEqual(@as(u16, 42), mem.chaos_read(100));
}

test "ring buffer" {
    var buf = RingBuffer(4).init();
    try std.testing.expect(buf.is_empty());
    try std.testing.expect(buf.push(10));
    try std.testing.expect(buf.push(20));
    try std.testing.expect(buf.push(30));
    try std.testing.expect(buf.push(40));
    try std.testing.expect(!buf.push(50)); // full
    try std.testing.expectEqual(@as(?u8, 10), buf.pop());
    try std.testing.expectEqual(@as(?u8, 20), buf.pop());
    try std.testing.expectEqual(@as(u32, 2), buf.available());
}

test "power budget" {
    var pwr = Power.init(100);
    try std.testing.expect(pwr.is_alive());
    try std.testing.expect(pwr.spend(50));
    try std.testing.expectEqual(@as(i32, 50), pwr.remaining());
    try std.testing.expect(pwr.spend(50));
    try std.testing.expectEqual(@as(i32, 0), pwr.remaining());
    try std.testing.expect(!pwr.spend(1)); // depleted → sleep
    try std.testing.expect(!pwr.is_alive());
    pwr.wake(200);
    try std.testing.expect(pwr.is_alive());
    try std.testing.expectEqual(@as(i32, 200), pwr.remaining());
}

test "crazy operation" {
    // crz(0, 0) = 1 (from table: [0][0] = 1, repeated 10 times)
    // Actually: crz(0,0) = 1*1 + 1*3 + 1*9 + ... = (3^10-1)/2 = 29524
    // Wait, each trit: CRAZY_TABLE[0][0] = 1, so result = 1+3+9+27+...+19683 = 29524
    const r = crazy(0, 0);
    try std.testing.expectEqual(@as(u16, 29524), r);

    // crz is irreversible: crz(a,d) loses information
    const r1 = crazy(10, 20);
    const r2 = crazy(10, 21);
    try std.testing.expect(r1 != r2);
}

test "rotr" {
    // 10 rotations = identity
    var val: u16 = 12345;
    const original = val;
    for (0..10) |_| {
        val = rotr(val);
    }
    try std.testing.expectEqual(original, val);
}

test "substrate lifecycle" {
    var sub = Substrate(DEFAULT_CONFIG).init(100);

    // Load input
    _ = sub.input.fill("PACKET");

    // Read
    try std.testing.expectEqual(@as(?u8, 'P'), sub.io_read());
    try std.testing.expectEqual(@as(?u8, 'A'), sub.io_read());

    // Write output
    try std.testing.expect(sub.io_write(42));

    // Check status
    const s = sub.status();
    try std.testing.expect(s.pu_remaining < 100);
    try std.testing.expect(!s.sleeping);
    try std.testing.expectEqual(@as(u32, 4), s.input_pending); // "CKET" left
    try std.testing.expectEqual(@as(u32, 1), s.output_pending);
}

test "encrypt and decode" {
    // NOP_A at position 0: (char - 33 + 0) % 94 = 62
    // char = 62 + 33 = 95
    const instr = decode_instruction(95, 0);
    try std.testing.expectEqual(@as(u8, 62), instr); // NOP_A

    // After encryption
    const encrypted = encrypt(95);
    const next_instr = decode_instruction(encrypted, 0);
    try std.testing.expect(next_instr != 62); // different instruction after DISSOLVE
}
