// ============================================================
// Packet :: Layer 4 — TENSION
// Closes CALM back to FLOW/CHAOS.
// Measures price of form retention.
// ============================================================

const std = @import("std");
const layer0 = @import("layer0_substrate.zig");
const layer1 = @import("layer1_chaos.zig");
const layer2 = @import("layer2_boundary.zig");
const layer3 = @import("layer3_calm.zig");

const Substrate = layer0.Substrate(layer0.DEFAULT_CONFIG);
const ChaosVM = layer1.ChaosVM;
const Boundary = layer2.Boundary;
const CalmVM = layer3.CalmVM;
const Op = layer3.Op;

pub const TensionAction = enum {
    hold,
    reinforce_calm,
    release_to_chaos,
    manifest_now,
};

pub const TensionState = struct {
    chaos_pressure: u32,
    calm_rigidity: u32,
    boundary_load: u32,
    unresolved_delta: u32,
    release_score: u32,
    action: TensionAction,
};

pub const Tension = struct {
    const Self = @This();

    release_threshold: u32,
    manifest_threshold: u32,
    reinforce_threshold: u32,

    total_releases: u32,
    total_reinforces: u32,
    total_manifests: u32,

    pub fn init() Self {
        return Self{
            .release_threshold = 120,
            .manifest_threshold = 180,
            .reinforce_threshold = 40,
            .total_releases = 0,
            .total_reinforces = 0,
            .total_manifests = 0,
        };
    }

    pub fn measure(
        self: *const Self,
        chaos: *const ChaosVM,
        boundary: *const Boundary,
        calm: *const CalmVM,
        sub: *const Substrate,
    ) TensionState {
        _ = self;

        const chaos_pressure =
        @as(u32, chaos.fingerprint() & 0xFF) +
        @as(u32, chaos.sub.mem.reg_a & 0xFF);

        const calm_rigidity =
        calm.layers_count * 8 +
        calm.program_len / 16;

        const boundary_load =
        boundary.encode.layers_encoded * 6 +
        @as(u32, @intFromFloat(boundary.encode.total_loss * 100.0));

        const unresolved_delta = if (chaos_pressure > calm_rigidity)
        chaos_pressure - calm_rigidity
        else
            calm_rigidity - chaos_pressure;

        const pu_penalty: u32 =
        if (sub.power.fraction() < 0.2) 40
            else if (sub.power.fraction() < 0.4) 20
                else 0;

                const release_score = unresolved_delta + boundary_load + pu_penalty;

        var action: TensionAction = .hold;

        if (release_score >= self.manifest_threshold) {
            action = .manifest_now;
        } else if (release_score >= self.release_threshold) {
            action = .release_to_chaos;
        } else if (release_score <= self.reinforce_threshold and calm.layers_count > 0) {
            action = .reinforce_calm;
        } else {
            action = .hold;
        }

        return TensionState{
            .chaos_pressure = chaos_pressure,
            .calm_rigidity = calm_rigidity,
            .boundary_load = boundary_load,
            .unresolved_delta = unresolved_delta,
            .release_score = release_score,
            .action = action,
        };
    }

    pub fn apply(
        self: *Self,
        state: TensionState,
        chaos: *ChaosVM,
        calm: *CalmVM,
        sub: *Substrate,
    ) void {
        switch (state.action) {
            .hold => {},

            .reinforce_calm => {
                self.total_reinforces += 1;

                // cheap local reinforcement: append a tiny stabilizer pattern
                const stabilizer = [_]u3{
                    Op.WIND, Op.WIND, Op.WATER, // ++.
                };
                calm.add_layer(&stabilizer);
            },

            .release_to_chaos => {
                self.total_releases += 1;
                self.releaseCrystalResidueToChaos(calm, chaos, sub);
            },

            .manifest_now => {
                self.total_manifests += 1;

                // force energy drain so lifecycle exits earlier into manifest
                _ = sub.power.spend(25);
            },
        }
    }

    fn releaseCrystalResidueToChaos(
        self: *Self,
        calm: *CalmVM,
        chaos: *ChaosVM,
        sub: *Substrate,
    ) void {
        _ = self;
        _ = sub;

        if (calm.program_len == 0) return;

        // take only a small residue from the latest crystal tail
        const count: u32 = if (calm.program_len >= 8) 8 else calm.program_len;

        var i: u32 = 0;
        while (i < count) : (i += 1) {
            const src_idx = calm.program_len - count + i;
            const trigram: u16 = calm.program[src_idx];

            // inject into CHAOS memory near D register,
            // not as full overwrite but as crz perturbation
            const addr: u16 = @intCast(
                (@as(u32, chaos.sub.mem.reg_d) + i) %
                layer0.DEFAULT_CONFIG.chaos_cells
            );

            const old = chaos.sub.mem.chaos_read(addr);
            const injected = layer0.crazy(old, trigram);
            chaos.sub.mem.chaos_write(addr, injected);
        }
    }
};

// ============================================================
// Example integration point
// Call after Boundary step, before final MANIFEST decision.
// ============================================================

pub fn tension_step(
    tension: *Tension,
    chaos: *ChaosVM,
    boundary: *Boundary,
    calm: *CalmVM,
    sub: *Substrate,
) TensionState {
    const state = tension.measure(chaos, boundary, calm, sub);
    tension.apply(state, chaos, calm, sub);
    return state;
}
