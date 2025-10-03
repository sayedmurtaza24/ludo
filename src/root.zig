const std = @import("std");
const assert = std.debug.assert;

const total_available_moves = 56;

pub const Piece = enum(u2) { _ };
pub const Color = enum { red, green, blue, yellow };

pub const Team = struct {
    pieces: [4]i6 = .{ -1, -1, -1, -1 },
    color: Color,

    pub fn init(color: Color) Team {
        return .{ .color = color };
    }
};

pub const Game = struct {
    teams: []*Team,
    turn: *Team,

    dice_rolled: bool = false,
    dice_num: u3 = 0,

    const Self = @This();

    pub fn init(teams: []*Team) Game {
        assert(teams.len >= 2 and teams.len <= 4);
        return .{ .teams = teams, .turn = teams[0] };
    }

    pub fn rollDice(self: *Self) void {
        self.dice_num = std.crypto.random.intRangeAtMost(u3, 1, 6);
        self.dice_rolled = true;
    }

    pub fn availableMoves(self: *Self) [4]bool {
        if (!self.dice_rolled) return .{false} ** 4;

        var moves: [4]bool = undefined;
        for (self.turn.pieces, 0..) |piece, i| {
            moves[i] = self.dice_rolled and
                (piece != -1 or self.dice_num == 6) and
                (piece + self.dice_num < total_available_moves);
        }
        return moves;
    }

    pub fn move(self: *Self, piece_idx: Piece) void {
        const curr_team: Team = self.teams[self.turn];
        const curr_piece: usize = curr_team.pieces[@intFromEnum(piece_idx)];

        assert(self.dice_num != 6 or curr_team[curr_piece] == -1);
        assert(self.dice_num != 0 and self.dice_rolled == true);
        assert(curr_piece + self.dice_num < total_available_moves);

        self.dice_rolled = false;
        self.teams[self.turn].pieces[piece_idx] += self.dice_num;
    }
};

test "Game" {
    const expectEqual = std.testing.expectEqual;

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

    try expectEqual(game.availableMoves(), .{false} ** 4);

    game.rollDice();

    game.dice_num = 1;
    try expectEqual(game.availableMoves(), .{false} ** 4);

    game.dice_num = 6;
    try expectEqual(game.availableMoves(), .{true} ** 4);
}
