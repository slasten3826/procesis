// ============================================================
// Packet :: Interactive Lifecycle Simulator (Fixed)
// ============================================================

const std = @import("std");
const layer0 = @import("layer0_substrate.zig");
const layer1 = @import("layer1_chaos.zig");
const layer2 = @import("layer2_boundary.zig");
const layer3 = @import("layer3_calm.zig");

const Substrate = layer0.Substrate(layer0.DEFAULT_CONFIG);
const ChaosVM = layer1.ChaosVM;
const CalmVM = layer3.CalmVM;
const Boundary = layer2.Boundary;

fn print(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

fn instrName(op: u8) []const u8 {
    return switch (op) {
        4 => "JUMP",
        5 => "MANI",
        23 => "FLOW",
        39 => "ROTR",
        40 => "WILL",
        62 => "OBS_A",
        81 => "OBS_B",
        else => "NOP",
    };
}

pub fn main() void {
    // --- 1. Ввод данных ---
    const args = std.process.argsAlloc(std.heap.page_allocator) catch {
        print("Error: Memory allocation failed.\n", .{});
        return;
    };
    defer std.process.argsFree(std.heap.page_allocator, args);

    const user_input = if (args.len > 1) args[1] else "DEFAULT";

    print("\n{s}\n", .{"=== PACKET SIM v0.1 ==="});
    print("Input: {s}\n", .{user_input});

    // --- 2. Инициализация ---
    var substrate = Substrate.init(1000); // 1000 PU
    _ = substrate.input.fill(user_input);

    var chaos = ChaosVM.init(&substrate);
    var calm = CalmVM.init(&substrate);
    var boundary = Boundary.init();

    chaos.load_program("8_^]\\[ZYX");

    print("\n{s}\n", .{"--- CHAOS PHASE ---"});

    // --- 3. Жизненный цикл ---
    while (substrate.power.is_alive()) {
        const ra = boundary.obs_a.read(&chaos);
        const rb = boundary.obs_b.read(&calm, &substrate);
        const decision = boundary.choose.decide(ra, rb);

        const c_ptr = chaos.sub.mem.reg_c;
        const val = chaos.sub.mem.chaos_read(c_ptr);
        const op = layer0.decode_instruction(val, c_ptr);

        var decision_str: []const u8 = "...";

        switch (decision) {
            .chaos => {
                decision_str = "CHAOS";
                if (!chaos.tick()) break;
            },
            .encode => {
                decision_str = "ENCODE";
                if (substrate.power.spend(layer0.Power.COST_ENCODE)) {
                    const res = boundary.encode.crystallize(&chaos, &calm);
                    print(">>> CRYSTALLIZE Layer {} Hash {} Loss {d:.2}\n", .{res.layer, res.crystal_hash, res.loss});
                }
            },
            .manifest => {
                decision_str = "MANIFEST";
                print(">>> MANIFEST TRIGGERED\n", .{});
                break;
            },
        }

        // Простой вывод без сложного форматирования
        print("Tick:{} PU:{} A:{} OP:{s} DEC:{s}\n", .{
            substrate.clock.ticks,
            substrate.power.remaining(),
              chaos.sub.mem.reg_a,
              instrName(op),
              decision_str
        });
    }

    print("\n{s}\n", .{"--- CHAOS END ---"});

    // --- 4. CALM PHASE ---
    print("Layers: {} Size: {}\n", .{calm.layers_count, calm.program_len});

    if (calm.program_len > 0) {
        print("Running CALM VM...\n", .{});

        calm.pc = 0;
        calm.halted = false;
        calm.sub.mem.calm_ptr = 0;

        var calm_tick: u32 = 0;
        while (calm.tick()) {
            calm_tick += 1;
            if (calm_tick > 10000) break;
        }

        print("\nOUTPUT: ", .{});
        var out_byte = substrate.output.pop();
        while (out_byte != null) : (out_byte = substrate.output.pop()) {
            print("{c}", .{out_byte.?});
        }
        print("\n", .{});
    }

    print("\n{s}\n", .{"=== DONE ==="});
}
