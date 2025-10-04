const std = @import("std");
const assert = std.debug.assert;

const total_available_moves = 56;

pub const Piece = enum(u2) { _ };
pub const Color = enum { red, green, blue, yellow };

pub const Team = struct {
    pieces: [4]i7 = .{ -1, -1, -1, -1 },
    color: Color,

    pub fn init(color: Color) Team {
        return .{ .color = color };
    }
};

pub const Game = struct {
    teams: []*Team,
    curr_team: *Team,

    dice_rolled: bool = false,
    dice_num: u3 = 0,

    const Self = @This();

    pub fn init(teams: []*Team) Game {
        assert(teams.len >= 2 and teams.len <= 4);
        return .{ .teams = teams, .curr_team = teams[0] };
    }

    pub fn rollDice(self: *Self) void {
        self.dice_num = std.crypto.random.intRangeAtMost(u3, 1, 6);
        self.dice_rolled = true;
    }

    pub fn availableMoves(self: *Self) [4]bool {
        if (!self.dice_rolled) return .{false} ** 4;

        var moves: [4]bool = undefined;
        for (self.curr_team.pieces, 0..) |piece, i| {
            moves[i] = self.dice_rolled and
                (piece != -1 or self.dice_num == 6) and
                (piece + self.dice_num < total_available_moves);
        }
        return moves;
    }

    pub fn move(self: *Self, piece_idx: Piece) void {
        const curr_piece: i7 = self.curr_team.pieces[@intFromEnum(piece_idx)];

        assert(self.dice_num != 6 or curr_piece == -1);
        assert(self.dice_num != 0 and self.dice_rolled == true);
        assert(curr_piece + self.dice_num < total_available_moves);

        self.dice_rolled = false;
        self.curr_team.pieces[@intFromEnum(piece_idx)] += self.dice_num;

        const curr_team_idx = std.mem.indexOfScalar(*Team, self.teams, self.curr_team).?;
        self.curr_team = self.teams[(curr_team_idx + 1) % self.teams.len];
    }

    pub fn format(self: *Self, writer: std.Io.Writer) !void {
        _ = self;
        _ = writer;
    }
};

test Game {
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

    game.curr_team.pieces[0] = 55;
    try expectEqual(game.availableMoves(), .{ false, true, true, true });

    const active_team = game.curr_team;
    game.move(@enumFromInt(1));

    try expectEqual(active_team.pieces, .{ 55, 5, -1, -1 });
    try expectEqual(game.curr_team.color, .green);

    var i: TableIndexes = .init;

    i.print();
    i.indexOfAtPos(team_red, @enumFromInt(0));
}

const table =
    \\ [ ][ ][ ][ ][ ][ ][X][Y][Z][ ][ ][ ][ ][ ][ ]
    \\ [ ][!][ ][!][ ][ ][W][ ][a][ ][ ][@][ ][@][ ]
    \\ [ ][ ][ ][ ][ ][ ][V][ ][b][ ][ ][ ][ ][ ][ ]
    \\ [ ][!][ ][!][ ][ ][U][ ][c][ ][ ][@][ ][@][ ]
    \\ [ ][ ][ ][ ][ ][ ][T][ ][d][ ][ ][ ][ ][ ][ ]
    \\ [ ][ ][ ][ ][ ][ ][S][ ][e][ ][ ][ ][ ][ ][ ]
    \\ [M][N][O][P][Q][R][ ][ ][ ][f][g][h][i][j][k]
    \\ [L][ ][ ][ ][ ][ ][ ][ ][ ][ ][ ][ ][ ][ ][l]
    \\ [K][J][I][H][G][F][ ][ ][ ][r][q][p][o][n][m]
    \\ [ ][ ][ ][ ][ ][ ][E][ ][s][ ][ ][ ][ ][ ][ ]
    \\ [ ][ ][ ][ ][ ][ ][D][ ][t][ ][ ][ ][ ][ ][ ]
    \\ [ ][#][ ][#][ ][ ][C][ ][u][ ][ ][$][ ][$][ ]
    \\ [ ][ ][ ][ ][ ][ ][B][ ][v][ ][ ][ ][ ][ ][ ]
    \\ [ ][#][ ][#][ ][ ][A][ ][w][ ][ ][$][ ][$][ ]
    \\ [ ][ ][ ][ ][ ][ ][z][y][x][ ][ ][ ][ ][ ][ ]
    \\
;

const TableIndexes = struct {
    table_copy: [705]u8,
    path_indexes: [52]usize,
    home_indexes: [16]usize,

    const init: TableIndexes = blk: {
        var indexes: [52]usize = undefined;

        @setEvalBranchQuota(50_000);
        for ('A'..'Z' + 1, 0..) |c, i| {
            indexes[i] = std.mem.indexOfScalar(u8, table, c).?;
        }
        for ('a'..'z' + 1, 'Z' + 1 - 'A'..) |c, i| {
            indexes[i] = std.mem.indexOfScalar(u8, table, c).?;
        }

        var table_copy = table.*;
        for (indexes) |i| {
            table_copy[i] = ' ';
        }

        var home_indexes: [16]usize = undefined;
        for (.{ '!', '@', '#', '$' }, 0..) |h, offset| {
            for (offset * 4..offset * 4 + 4) |i| {
                const idx = std.mem.indexOfScalar(u8, &table_copy, h).?;
                home_indexes[i] = idx;
                table_copy[idx] = ' ';
            }
        }

        break :blk .{
            .table_copy = table_copy,
            .path_indexes = indexes,
            .home_indexes = home_indexes,
        };
    };

    fn indexOfAtPos(self: *@This(), game: *Game, team: *Team, piece: Piece) usize {
        const piece_idx = @intFromEnum(piece);
        const pos = team.pieces[piece_idx];

        if (pos == -1) {}
    }

    fn print(self: *@This()) void {
        std.debug.print("{s}", .{self.table_copy});
    }
};

test TableIndexes {}

fn findNextMove() i7 {}
