// ============================================================
// Packet :: Layer 2 — BOUNDARY
// The Abyss. OBSERVE + CHOOSE + ENCODE.
// Watches CHAOS and CALM simultaneously.
// Gradual crystallization: max 35% per pass.
// PU-budget driven decisions.
// ============================================================

const std = @import("std");
const layer0 = @import("layer0_substrate.zig");
const layer1 = @import("layer1_chaos.zig");
const layer3 = @import("layer3_calm.zig");

const Substrate = layer0.Substrate(layer0.DEFAULT_CONFIG);
const ChaosVM = layer1.ChaosVM;
const CalmVM = layer3.CalmVM;
const Op = layer3.Op;

// ============================================================
// OBSERVE_A: watches CHAOS (short orbit, fast pulse)
// ============================================================

pub const ObserveA = struct {
    last_fp: u32,
    stagnation: u32, // consecutive same fingerprints
    total_reads: u32,

    pub fn init() ObserveA {
        return ObserveA{ .last_fp = 0, .stagnation = 0, .total_reads = 0 };
    }

    pub fn read(self: *ObserveA, chaos: *const ChaosVM) ChaosReading {
        const fp = chaos.fingerprint();
        if (fp == self.last_fp) {
            self.stagnation += 1;
        } else {
            self.stagnation = 0;
        }
        self.last_fp = fp;
        self.total_reads += 1;

        return ChaosReading{
            .fingerprint = fp,
            .a_value = chaos.sub.mem.reg_a,
            .stagnation = self.stagnation,
            .halted = chaos.halted,
        };
    }
};

pub const ChaosReading = struct {
    fingerprint: u32,
    a_value: u16,
    stagnation: u32,
    halted: bool,
};

// ============================================================
// OBSERVE_B: watches CALM (long orbit, slow wave)
// ============================================================

pub const ObserveB = struct {
    total_reads: u32,

    pub fn init() ObserveB {
        return ObserveB{ .total_reads = 0 };
    }

    pub fn read(self: *ObserveB, calm: *const CalmVM, sub: *const Substrate) CalmReading {
        self.total_reads += 1;
        return CalmReading{
            .layers = calm.layers_count,
            .program_size = calm.program_len,
            .pu_remaining = sub.power.remaining(),
            .pu_fraction = sub.power.fraction(),
        };
    }
};

pub const CalmReading = struct {
    layers: u32,
    program_size: u32,
    pu_remaining: i32,
    pu_fraction: f32,
};

// ============================================================
// CHOOSE: budget-driven decision
// ============================================================

pub const Decision = enum { chaos, encode, manifest };

pub const Choose = struct {
    stagnation_threshold: u32,
    panic_fraction: f32,
    encode_fraction: f32,

    pub fn init() Choose {
        return Choose{
            .stagnation_threshold = 5,
            .panic_fraction = 0.15,
            .encode_fraction = 0.4,
        };
    }

    pub fn decide(self: *const Choose, ra: ChaosReading, rb: CalmReading) Decision {
        // PU panic
        if (rb.pu_fraction < self.panic_fraction) return .manifest;

        // PU low — crystallize
        if (rb.pu_fraction < self.encode_fraction) return .encode;

        // Stagnation
        if (ra.stagnation > self.stagnation_threshold) return .encode;

        // CALM hungry
        if (rb.layers == 0 and rb.pu_fraction < 0.7) return .encode;

        // CHAOS halted
        if (ra.halted) return .encode;

        return .chaos;
    }
};

// ============================================================
// ENCODE: gradual crystallization (CHAOS → Trigrams)
// ============================================================

pub const Encode = struct {
    max_fraction: f32,
    min_loss: f32,
    total_loss: f32,
    layers_encoded: u32,

    // Buffer for generated trigram code
    buffer: [4096]u3,
    buffer_len: u32,

    pub fn init() Encode {
        return Encode{
            .max_fraction = 0.35,
            .min_loss = 0.01,
            .total_loss = 0,
            .layers_encoded = 0,
            .buffer = undefined,
            .buffer_len = 0,
        };
    }

    /// Crystallize one layer from CHAOS into trigram code
    pub fn crystallize(self: *Encode, chaos: *ChaosVM, calm: *CalmVM) EncodeResult {
        self.buffer_len = 0;

        // Extract region from CHAOS
        const region_size: u32 = @intFromFloat(@as(f32, @floatFromInt(layer0.DEFAULT_CONFIG.chaos_cells)) * self.max_fraction);
        const start = chaos.sub.mem.reg_d;

        // crz-hash the region (irreversible compression)
        var crystal_hash: u16 = chaos.sub.mem.chaos_read(start);
        var i: u32 = 1;
        while (i < region_size) : (i += 1) {
            const addr: u16 = @intCast((@as(u32, start) + i) % layer0.DEFAULT_CONFIG.chaos_cells);
            crystal_hash = layer0.crazy(crystal_hash, chaos.sub.mem.chaos_read(addr));
        }

        const crystal_val: u8 = @intCast(crystal_hash % 256);
        const a_val: u8 = @intCast(chaos.sub.mem.reg_a % 256);

        // Loss grows with each layer
        const layer_num = self.layers_encoded;
        const loss = self.min_loss * (1.0 + @as(f32, @floatFromInt(layer_num)) * 0.5);
        self.total_loss += loss;

        // Move to layer region on tape
        var move: u32 = 0;
        while (move < layer_num * 10) : (move += 1) {
            self.emit(Op.FIRE); // >
        }

        // Generate crystal value using multiply loop
        if (crystal_val > 0) {
            self.generate_value(crystal_val);
        } else {
            self.emit(Op.FIRE);
        }

        // Output (MANIFEST this crystal byte)
        self.emit(Op.WATER); // .

        // Encode fingerprint as data
        const fp = chaos.fingerprint();
        self.emit(Op.FIRE); // >
        self.generate_value(@intCast(fp & 0xFF));

        // Encode A value
        self.emit(Op.FIRE); // >
        if (a_val > 0) {
            self.generate_value(a_val);
        }

        // Layer marker
        self.emit(Op.FIRE); // >
        var marker: u32 = 0;
        while (marker <= layer_num) : (marker += 1) {
            self.emit(Op.WIND); // +
        }

        // Corrupt crystallized region in CHAOS (it's dead now)
        i = 0;
        while (i < region_size) : (i += 1) {
            const addr: u16 = @intCast((@as(u32, start) + i) % layer0.DEFAULT_CONFIG.chaos_cells);
            const old = chaos.sub.mem.chaos_read(addr);
            chaos.sub.mem.chaos_write(addr, layer0.crazy(old, crystal_hash));
        }

        // Add to CALM
        calm.add_layer(self.buffer[0..self.buffer_len]);

        self.layers_encoded += 1;

        return EncodeResult{
            .crystal_hash = crystal_hash,
            .crystal_value = crystal_val,
            .a_value = a_val,
            .loss = loss,
            .trigram_count = self.buffer_len,
            .layer = layer_num,
        };
    }

    fn emit(self: *Encode, op: u3) void {
        if (self.buffer_len < self.buffer.len) {
            self.buffer[self.buffer_len] = op;
            self.buffer_len += 1;
        }
    }

    fn generate_value(self: *Encode, target: u8) void {
        // Find best a*b+rem ≈ target
        var best_a: u8 = 1;
        var best_b: u8 = target;
        var best_cost: u16 = @as(u16, 1) + target;

        var a: u8 = 2;
        while (a < 18) : (a += 1) {
            const b = target / a;
            const rem = target - a * b;
            const cost = @as(u16, a) + b + rem;
            if (cost < best_cost) {
                best_a = a;
                best_b = b;
                best_cost = cost;
            }
        }

        if (best_b == 0) {
            // Just use increments
            var j: u8 = 0;
            while (j < target) : (j += 1) {
                self.emit(Op.WIND);
            }
            return;
        }

        // Generate: +++[>+++<-]>rem
        var j: u8 = 0;
        while (j < best_a) : (j += 1) self.emit(Op.WIND); // a × +
        self.emit(Op.HEAVEN); // [
        self.emit(Op.FIRE);   // >
        j = 0;
        while (j < best_b) : (j += 1) self.emit(Op.WIND); // b × +
        self.emit(Op.LAKE);     // <
        self.emit(Op.MOUNTAIN); // -
        self.emit(Op.EARTH);    // ]
        self.emit(Op.FIRE);     // >
        const rem = target - best_a * best_b;
        j = 0;
        while (j < rem) : (j += 1) self.emit(Op.WIND); // rem × +
    }
};

pub const EncodeResult = struct {
    crystal_hash: u16,
    crystal_value: u8,
    a_value: u8,
    loss: f32,
    trigram_count: u32,
    layer: u32,
};

// ============================================================
// Boundary: orchestrates the full lifecycle
// ============================================================

pub const Boundary = struct {
    obs_a: ObserveA,
    obs_b: ObserveB,
    choose: Choose,
    encode: Encode,

    pub fn init() Boundary {
        return Boundary{
            .obs_a = ObserveA.init(),
            .obs_b = ObserveB.init(),
            .choose = Choose.init(),
            .encode = Encode.init(),
        };
    }

    /// Run one decision cycle: observe → choose → act
    pub fn step(self: *Boundary, chaos: *ChaosVM, calm: *CalmVM, sub: *Substrate) Decision {
        // Spend PU for observation
        _ = sub.power.spend(layer0.Power.COST_OBSERVE);

        const ra = self.obs_a.read(chaos);
        const rb = self.obs_b.read(calm, sub);

        const decision = self.choose.decide(ra, rb);

        switch (decision) {
            .chaos => {
                // Let CHAOS run a burst
                _ = chaos.run_burst(5);
            },
            .encode => {
                // Spend PU for encode
                if (sub.power.spend(layer0.Power.COST_ENCODE)) {
                    _ = self.encode.crystallize(chaos, calm);
                }
            },
            .manifest => {
                // Done. CALM will execute.
            },
        }

        return decision;
    }

    /// Run full lifecycle until MANIFEST
    pub fn run_lifecycle(self: *Boundary, chaos: *ChaosVM, calm: *CalmVM, sub: *Substrate) void {
        while (sub.power.is_alive()) {
            const decision = self.step(chaos, calm, sub);
            if (decision == .manifest) break;
        }
    }
};

// ============================================================
// Tests
// ============================================================

test "Boundary: full lifecycle" {
    var sub = Substrate.init(500);
    _ = sub.input.fill("A");

    var chaos = ChaosVM.init(&sub);
    chaos.load_program("8_^]\\[ZYX");

    var calm = CalmVM.init(&sub);
    var boundary = Boundary.init();

    boundary.run_lifecycle(&chaos, &calm, &sub);

    // Should have created crystal layers
    try std.testing.expect(calm.layers_count > 0);
    // Should have consumed most PU
    try std.testing.expect(sub.power.remaining() < 100);
}

test "Boundary: encode produces valid trigrams" {
    var sub = Substrate.init(200);

    var chaos = ChaosVM.init(&sub);
    chaos.load_program("8_^");
    _ = chaos.run_burst(10);

    var calm = CalmVM.init(&sub);
    var enc = Encode.init();

    _ = sub.power.spend(0); // reset nothing
    const result = enc.crystallize(&chaos, &calm);

    try std.testing.expect(result.trigram_count > 0);
    try std.testing.expect(calm.program_len > 0);
    try std.testing.expectEqual(@as(u32, 1), calm.layers_count);
}

test "Boundary: CHOOSE decisions" {
    const choose = Choose.init();

    // Low PU → manifest
    const ra1 = ChaosReading{ .fingerprint = 0, .a_value = 0, .stagnation = 0, .halted = false };
    const rb_panic = CalmReading{ .layers = 0, .program_size = 0, .pu_remaining = 10, .pu_fraction = 0.1 };
    try std.testing.expectEqual(Decision.manifest, choose.decide(ra1, rb_panic));

    // Stagnation → encode
    const ra_stag = ChaosReading{ .fingerprint = 0, .a_value = 0, .stagnation = 10, .halted = false };
    const rb_ok = CalmReading{ .layers = 1, .program_size = 100, .pu_remaining = 400, .pu_fraction = 0.8 };
    try std.testing.expectEqual(Decision.encode, choose.decide(ra_stag, rb_ok));

    // Healthy → chaos
    const ra_ok = ChaosReading{ .fingerprint = 42, .a_value = 100, .stagnation = 0, .halted = false };
    try std.testing.expectEqual(Decision.chaos, choose.decide(ra_ok, rb_ok));
}
