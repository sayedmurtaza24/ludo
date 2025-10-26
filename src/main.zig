const std = @import("std");
const ludo = @import("ludo");
const log = std.log.scoped(.game);

const lib = @import("ludo");
const Color = lib.Color;
const Team = lib.Team;
const Game = lib.Game;
const Board = lib.Board;
const Piece = lib.Piece;

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

    game.curr = .yellow;

    // _ = try game.dice.prepareNext();
    game.dice.used = false;
    game.dice.num = 6;

    const board: Board = .init;
    const moves = game.availableMoves(.red);

    try game.move(@enumFromInt(0));

    // _ = try game.dice.prepareNext();
    game.dice.used = false;
    game.dice.num = 3;

    try game.move(@enumFromInt(0));

    game.dice.used = false;
    game.dice.num = 5;

    try game.move(@enumFromInt(0));

    game.dice.used = false;
    game.dice.num = 4;

    try game.move(@enumFromInt(0));

    try game.forward();

    log.info("{} {} {} {}", .{ moves.isSet(0), moves.isSet(1), moves.isSet(2), moves.isSet(3) });
    log.info("{}", .{game.teams.getAssertContains(.yellow).pieces});

    var buf: [2048]u8 = undefined;
    try board.print(&buf, &teams);
}
