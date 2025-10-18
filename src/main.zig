const std = @import("std");
const ludo = @import("ludo");

const lib = @import("ludo");
const Team = lib.Team;
const Game = lib.Game;
const Board = lib.Board;
const Piece = lib.Piece;

pub fn main() !void {
    var team_red: Team = .init(.red);
    var team_blue: Team = .init(.blue);
    var team_green: Team = .init(.green);
    var team_yellow: Team = .init(.yellow);

    var teams: [4]*Team = .{
        &team_red,
        &team_green,
        &team_blue,
        &team_yellow,
    };

    var game: Game = .init(&teams);

    const board: Board = .init;

    var print_buf: [2048]u8 = undefined;
    while (game.ended != true) {
        std.debug.print("\x1b[1J\x1b[?2026h", .{});

        game.rollDice();

        std.debug.print("{s}: DICE {}\n", .{ @tagName(game.curr_team.color), game.dice_num });
        std.debug.print("{s}: POS {any}\n", .{ @tagName(game.curr_team.color), game.curr_team.pieces });

        const moves = game.availableMoves();

        std.debug.print("{s}: MOVES {any}\n", .{ @tagName(game.curr_team.color), moves });

        if (std.mem.indexOfScalar(bool, &moves, true)) |idx| {
            std.debug.print("{s}: MOVING {}\n", .{ @tagName(game.curr_team.color), idx });

            game.move(@enumFromInt(idx));
        }

        std.debug.print("{s}: NEXT\n", .{@tagName(game.curr_team.color)});
        game.next();

        try board.print(&print_buf, game.teams);

        std.debug.print("\x1b[?2026l", .{});
        std.Thread.sleep(4000 * 1000 * 1000);
    }

    std.debug.print("SCORES: \n", .{});
    for (game.teams) |team| {
        std.debug.print("TEAM {s:<7}: at move {}\n", .{ @tagName(team.color), team.ended_at });
    }
}
