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
}

const table =
    \\ [ ][ ][ ][ ][ ][ ][x][x][x][ ][ ][ ][ ][ ][ ]
    \\ [ ][b][ ][b][ ][ ][x][y][x][ ][ ][y][ ][y][ ]
    \\ [ ][ ][ ][ ][ ][ ][x][y][x][ ][ ][ ][ ][ ][ ]
    \\ [ ][b][ ][b][ ][ ][x][y][x][ ][ ][y][ ][y][ ]
    \\ [ ][ ][ ][ ][ ][ ][x][y][x][ ][ ][ ][ ][ ][ ]
    \\ [ ][ ][ ][ ][ ][ ][x][y][x][ ][ ][ ][ ][ ][ ]
    \\ [x][x][x][x][x][x][ ][h][ ][x][x][x][x][x][x]
    \\ [x][b][b][b][b][b][h][ ][h][g][g][g][g][g][x]
    \\ [x][x][x][x][x][x][ ][h][ ][x][x][x][x][x][x]
    \\ [ ][ ][ ][ ][ ][ ][x][r][x][ ][ ][ ][ ][ ][ ]
    \\ [ ][ ][ ][ ][ ][ ][x][r][x][ ][ ][ ][ ][ ][ ]
    \\ [ ][r][ ][r][ ][ ][x][r][x][ ][ ][g][ ][g][ ]
    \\ [ ][ ][ ][ ][ ][ ][x][r][x][ ][ ][ ][ ][ ][ ]
    \\ [ ][r][ ][r][ ][ ][s][r][x][ ][ ][g][ ][g][ ]
    \\ [ ][ ][ ][ ][ ][ ][e][x][x][ ][ ][ ][ ][ ][ ]
    \\
;

const TableIndexes = struct {
    red_path_indexes: [58]usize = blk: {
        var idx = std.mem.indexOfScalar(u8, table, 's').?;

        var indexes: [58]usize = undefined;
        indexes[0] = idx;

        @setEvalBranchQuota(10_000);
        for (1..57) |i| {
            idx = nextX(i, indexes, idx, false) orelse break;
            indexes[i] = idx;
        }

        break :blk indexes;
    },

    const init: TableIndexes = .{};

    fn isCorrect(iter: usize, prev: [58]usize, idx: ?usize) bool {
        if (idx) |i| {
            for (0..iter - 1) |pi| {
                if (i == prev[pi]) return false;
            }
            return true;
        } else {
            return false;
        }
    }

    fn nextX(iter: usize, prev: [58]usize, idx: usize, next: bool) ?usize {
        const lineLen = table.len / 15;

        const up: ?usize = blk: {
            if (lineLen > idx) break :blk null;
            if (table[idx - lineLen] == 'x') {
                break :blk idx - lineLen;
            } else {
                break :blk null;
            }
        };
        if (isCorrect(iter, prev, up)) return up;

        const down: ?usize = blk: {
            if (lineLen + idx > table.len) break :blk null;
            if (table[idx + lineLen] == 'x') {
                break :blk idx + lineLen;
            } else {
                break :blk null;
            }
        };
        if (isCorrect(iter, prev, down)) return down;

        const left: ?usize = blk: {
            if (idx < 3) break :blk null;
            if (table[idx - 3] == 'x') {
                break :blk idx - 3;
            } else {
                break :blk null;
            }
        };
        if (isCorrect(iter, prev, left)) return left;

        const right: ?usize = blk: {
            if (idx + 3 > table.len) break :blk null;
            if (table[idx + 3] == 'x') {
                break :blk idx + 3;
            } else {
                break :blk null;
            }
        };
        if (isCorrect(iter, prev, right)) return right;

        const topleft: ?usize = blk: {
            if (idx - lineLen - 3 < table.len) break :blk null;
            if (table[idx - lineLen - 3] == 'x') {
                break :blk idx - lineLen - 3;
            } else {
                break :blk null;
            }
        };
        if (isCorrect(iter, prev, topleft)) return topleft;

        const topright: ?usize = blk: {
            if (idx - lineLen + 3 > table.len) break :blk null;
            if (table[idx - lineLen + 3] == 'x') {
                break :blk idx - lineLen + 3;
            } else {
                break :blk null;
            }
        };
        if (isCorrect(iter, prev, topright)) return topright;

        if (!next) {
            return nextX(iter, prev, idx, true);
        }

        return null;
    }

    fn print(self: @This()) void {
        var tableCopy = table.*;

        for (self.red_path_indexes, 0..) |i, x| {
            if (i != 0) tableCopy[i] = '0' + @as(u8, @intCast(x));
        }

        std.debug.print("{any}", .{self.red_path_indexes});
        std.debug.print("{s}", .{tableCopy});
    }
};

test TableIndexes {
    const i: TableIndexes = .init;

    i.print();
}

fn findNextMove() i7 {}
