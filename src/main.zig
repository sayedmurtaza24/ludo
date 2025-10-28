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
};

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

    var board_buf: [2048]u8 = undefined;
    var stdin_buf: [2]u8 = undefined;

    var stdin = std.fs.File.stdin().reader(&stdin_buf);
    const reader = &stdin.interface;

    while (true) : (reader.toss(1)) {
        log.info("team: {s}", .{@tagName(game.curr)});

        if (game.dice.used) {
            log.info("press r to roll dice", .{});
        } else {
            const moves = game.availableMoves(game.curr);

            for (0..4) |i| {
                if (moves.isSet(i)) log.info("press {} to move piece {}", .{ i + 1, i + 1 });
            }
        }

        const input = reader.takeDelimiterExclusive('\n') catch |e| switch (e) {
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
                    const diceNum = game.dice.prepareNext() catch {
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
                        error.Used => continue,
                    };
                },
            }
        }

        game.forward() catch |e| switch (e) {
            error.DicePreparedNotUsed => log.info("must move piece now", .{}),
            error.GameEnded => break,
            error.DiceNotRolled => log.err("must roll dice first", .{}),
        };
        try board.print(&board_buf, &teams);
    }

    log.info("game ended {}", .{game});
}
