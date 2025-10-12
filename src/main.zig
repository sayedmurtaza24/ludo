const std = @import("std");
const ludo = @import("ludo");

const lib = @import("ludo");
const Team = lib.Team;
const Game = lib.Game;
const Board = lib.Board;

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

    game.teams[0].pieces = .{ -1, -1, -1, -1 };
    game.teams[1].pieces = .{ -1, -1, -1, -1 };
    game.teams[2].pieces = .{ -1, -1, -1, -1 };
    game.teams[3].pieces = .{ -1, -1, -1, -1 };

    var print_buf: [2048]u8 = undefined;
    for (teams) |team| {
        for (0..56) |i| {
            team.pieces[3] = @intCast(i);
            try board.print(&print_buf, game.teams);

            std.Thread.sleep(30 * 1000 * 1000);
        }
    }
}
