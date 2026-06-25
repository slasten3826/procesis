const std = @import("std");
const layer0 = @import("layer0_substrate.zig");

const Substrate = layer0.Substrate(layer0.DEFAULT_CONFIG);

pub const ChaosVM = struct {
    const Self = @This();
    sub: *Substrate,
    halted: bool,

    const OP_CRZ: u8 = 40;
    const OP_ROTR: u8 = 39;
    const OP_JUMP: u8 = 4;
    const OP_INPUT: u8 = 23;
    const OP_NOP_A: u8 = 62;
    const OP_NOP_B: u8 = 81;
    const OP_MANIFEST: u8 = 5;

    pub fn init(substrate: *Substrate) Self {
        return Self{ .sub = substrate, .halted = false };
    }

    pub fn load_program(self: *Self, program: []const u8) void {
        var pos: usize = 0;
        for (program) |ch| {
            if (ch == ' ' or ch == '\t' or ch == '\n' or ch == '\r') continue;
            if (pos < layer0.DEFAULT_CONFIG.chaos_cells) {
                self.sub.mem.chaos_write(@intCast(pos), @intCast(ch));
                pos += 1;
            }
        }
        if (pos == 0) { self.sub.mem.chaos_write(0, layer0.crazy(0, 0)); pos = 1; }
        if (pos == 1) { self.sub.mem.chaos_write(1, layer0.crazy(self.sub.mem.chaos_read(0), 0)); pos = 2; }
        var i: usize = pos;
        while (i < layer0.DEFAULT_CONFIG.chaos_cells) : (i += 1) {
            const prev2 = self.sub.mem.chaos_read(@intCast(i - 2));
            const prev1 = self.sub.mem.chaos_read(@intCast(i - 1));
            self.sub.mem.chaos_write(@intCast(i), layer0.crazy(prev2, prev1));
        }
        self.sub.mem.reg_a = 0;
        self.sub.mem.reg_c = 0;
        self.sub.mem.reg_d = 0;
        self.halted = false;
    }

    pub fn tick(self: *Self) bool {
        if (self.halted) return false;
        if (!self.sub.power.spend(layer0.Power.COST_CHAOS_TICK)) { self.halted = true; return false; }
        self.sub.tick();
        const c_ptr = self.sub.mem.reg_c;
        const val_at_c = self.sub.mem.chaos_read(c_ptr);
        const instr = layer0.decode_instruction(val_at_c, c_ptr);
        const d_ptr = self.sub.mem.reg_d;
        const val_at_d = self.sub.mem.chaos_read(d_ptr);

        switch (instr) {
            OP_CRZ => { const res = layer0.crazy(self.sub.mem.reg_a, val_at_d); self.sub.mem.reg_a = res; self.sub.mem.chaos_write(d_ptr, res); },
            OP_ROTR => { const rotated = layer0.rotr(val_at_d); self.sub.mem.chaos_write(d_ptr, rotated); self.sub.mem.reg_a = rotated; },
            OP_JUMP => { self.sub.mem.reg_c = val_at_d; },
            OP_INPUT => { if (self.sub.io_read()) |byte| { self.sub.mem.reg_a = @intCast(byte); } else { self.sub.mem.reg_a = 59048; } },
            OP_MANIFEST => { _ = self.sub.io_write(@intCast(self.sub.mem.reg_a % 256)); },
            OP_NOP_A, OP_NOP_B => {},
            else => {},
        }

        if (val_at_c >= 33 and val_at_c <= 126) {
            self.sub.mem.chaos_write(c_ptr, layer0.encrypt(val_at_c));
        }
        self.sub.mem.reg_c = @intCast((@as(u32, self.sub.mem.reg_c) + 1) % layer0.DEFAULT_CONFIG.chaos_cells);
        self.sub.mem.reg_d = @intCast((@as(u32, self.sub.mem.reg_d) + 1) % layer0.DEFAULT_CONFIG.chaos_cells);
        return true;
    }

    pub fn run_burst(self: *Self, max_ticks: u32) u32 {
        var count: u32 = 0;
        while (count < max_ticks and self.tick()) { count += 1; }
        return count;
    }

    pub fn fingerprint(self: *const Self) u32 {
        var h: u32 = @intCast(self.sub.mem.reg_a);
        h ^= @intCast(self.sub.mem.reg_c);
        h ^= @intCast(self.sub.mem.reg_d);
        h ^= @intCast(self.sub.mem.chaos_read(self.sub.mem.reg_c));
        h ^= @intCast(self.sub.mem.chaos_read(self.sub.mem.reg_d));
        return h;
    }
};

test "Chaos VM lifecycle" {
    var sub = Substrate.init(1000);
    var vm = ChaosVM.init(&sub);
    vm.load_program("JJppp");
    try std.testing.expect(!vm.halted);
    try std.testing.expectEqual(@as(u16, 0), vm.sub.mem.reg_c);
    var i: u32 = 0;
    while (i < 100) : (i += 1) { if (!vm.tick()) break; }
    try std.testing.expect(sub.power.remaining() < 1000);
    try std.testing.expect(sub.clock.ticks > 0);
    try std.testing.expect(vm.sub.mem.chaos_read(0) != 'J');
}

test "Chaos VM Input/Output" {
    var sub = Substrate.init(500);
    var vm = ChaosVM.init(&sub);
    _ = sub.input.fill("A");
    vm.load_program("&");
    vm.sub.mem.reg_a = 65;
    _ = vm.tick();
    try std.testing.expectEqual(@as(u32, 1), sub.output.available());
    const out = sub.output.pop();
    try std.testing.expectEqual(@as(u8, 'A'), out.?);
}

test "Chaos VM Halt on empty PU" {
    var sub = Substrate.init(5);
    var vm = ChaosVM.init(&sub);
    vm.load_program("jjjjj");
    var ticks: u32 = 0;
    while (vm.tick()) { ticks += 1; }
    try std.testing.expect(ticks <= 5);
    try std.testing.expect(vm.halted);
    try std.testing.expect(!sub.power.is_alive());
}
