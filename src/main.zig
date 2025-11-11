const std = @import("std");
const ludo = @import("ludo");
const log = std.log.scoped(.game);

const lib = @import("ludo");
const Color = lib.Color;
const Team = lib.Team;
const Game = lib.Game;
const Board = lib.Board;
const Piece = lib.Piece;

const Input = enum {
    @"1",
    @"2",
    @"3",
    @"4",
    r,
    r1,
    r2,
    r3,
    r4,
    r5,
    r6,
};

var buf: [2048 + 10 + 128]u8 = undefined;

pub fn main() !void {
    var teams: std.EnumMap(Color, Team) = .init(.{
        .red = .init(0),
        .green = .init(1),
        .blue = .init(2),
        .yellow = .init(3),
    });

    var prng = std.Random.DefaultPrng.init(100);
    const seeded_random = std.Random.DefaultPrng.random(&prng);

    var game: Game = try .init(seeded_random, &teams);

    const board: Board = .init;

    var stdin_r = std.fs.File.stdin().reader(buf[2048..][0..10]);
    const stdin = &stdin_r.interface;

    var stdout_r = std.fs.File.stdout().writer(buf[2048 + 10 ..][0..128]);
    const stdout = &stdout_r.interface;

    while (true) : (stdin.toss(1)) {
        log.info("team: {s}", .{@tagName(game.curr)});

        if (game.dice.mod == .NotRolled) {
            log.info("press r to roll dice randomly or r[1-6] to roll deterministically", .{});
        } else {
            const moves = game.availableMoves(game.curr);

            for (0..4) |i| {
                if (moves.isSet(i)) log.info("press {} to move piece {}", .{ i + 1, i + 1 });
            }
        }

        _ = try stdout.write("input: ");
        _ = try stdout.flush();
        const input = stdin.takeDelimiterExclusive('\n') catch |e| switch (e) {
            error.StreamTooLong => {
                log.err("invalid input", .{});
                continue;
            },
            else => unreachable,
        };
        if (input.len == 0) {
            log.info("input invalid", .{});
            continue;
        }

        if (std.meta.stringToEnum(Input, input)) |i| {
            switch (i) {
                .r => {
                    const diceNum = game.dice.roll() catch {
                        log.err("dice already rolled", .{});
                        continue;
                    };
                    log.info("dice roll: {}", .{diceNum});
                },
                .@"1", .@"2", .@"3", .@"4" => {
                    const piece_idx: u2 = @intCast(@intFromEnum(i));
                    const piece: Piece = @enumFromInt(piece_idx);

                    game.move(piece) catch |e| switch (e) {
                        error.NoAvailableMove => log.err("you can't move", .{}),
                        error.IllegalMove => log.err("illegal move", .{}),
                        error.NotUsable => log.err("dice not usable", .{}),
                    };
                },
                .r1, .r2, .r3, .r4, .r5, .r6 => |d| {
                    const num: u3 = switch (d) {
                        .r1 => 1,
                        .r2 => 2,
                        .r3 => 3,
                        .r4 => 4,
                        .r5 => 5,
                        .r6 => 6,
                        else => unreachable,
                    };
                    const diceNum = game.dice.rollWithNum(num) catch {
                        log.err("dice already rolled", .{});
                        continue;
                    };
                    log.info("dice roll: {}", .{diceNum});
                },
            }
        }

        game.forward() catch |e| switch (e) {
            error.DiceRolledNotUsed => log.info("must move piece now", .{}),
            error.DiceNotRolled => log.err("must roll dice first", .{}),
            error.GameEnded => break,
        };
        try board.print(buf[0..2048], &teams);
    }

    log.info("game ended {}", .{game});
}
