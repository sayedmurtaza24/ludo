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

    var board: Board = .init;

    game.teams[0].pieces = .{ -1, 0, 1, 2 };
    game.teams[1].pieces = .{ -1, 0, 1, 2 };
    game.teams[2].pieces = .{ -1, 0, 1, 2 };
    game.teams[3].pieces = .{ -1, 0, 1, 2 };

    for (game.teams, 0..) |t, x| {
        const indexes = board.indexes(t, x);
        for (indexes) |idx| {
            board.map[idx] = '◉';
        }
    }

    board.print(std.testing.allocator);
}

const board_map =
    \\ [ ][ ][ ][ ][ ][ ][X][Y][Z][ ][ ][ ][ ][ ][ ]
    \\ [ ][!][ ][!][ ][ ][W][ ][a][ ][ ][@][ ][@][ ]
    \\ [ ][ ][ ][ ][ ][ ][V][ ][b][ ][ ][ ][ ][ ][ ]
    \\ [ ][!][ ][!][ ][ ][U][ ][c][ ][ ][@][ ][@][ ]
    \\ [ ][ ][ ][ ][ ][ ][T][ ][d][ ][ ][ ][ ][ ][ ]
    \\ [ ][ ][ ][ ][ ][ ][S][ ][e][ ][ ][ ][ ][ ][ ]
    \\ [M][N][O][P][Q][R][ ][.][ ][f][g][h][i][j][k]
    \\ [L][ ][ ][ ][ ][ ][.][ ][.][ ][ ][ ][ ][ ][l]
    \\ [K][J][I][H][G][F][ ][.][ ][r][q][p][o][n][m]
    \\ [ ][ ][ ][ ][ ][ ][E][ ][s][ ][ ][ ][ ][ ][ ]
    \\ [ ][ ][ ][ ][ ][ ][D][ ][t][ ][ ][ ][ ][ ][ ]
    \\ [ ][#][ ][#][ ][ ][C][ ][u][ ][ ][$][ ][$][ ]
    \\ [ ][ ][ ][ ][ ][ ][B][ ][v][ ][ ][ ][ ][ ][ ]
    \\ [ ][#][ ][#][ ][ ][A][ ][w][ ][ ][$][ ][$][ ]
    \\ [ ][ ][ ][ ][ ][ ][z][y][x][ ][ ][ ][ ][ ][ ]
    \\
;

const Board = struct {
    map: [705]u16,
    path_indexes: [52]usize,
    home_indexes: [16]usize,

    const init: Board = blk: {
        var red_indexes: [52]usize = undefined;

        @setEvalBranchQuota(50_000);
        for ('A'..'Z' + 1, 0..) |c, i| {
            red_indexes[i] = std.mem.indexOfScalar(u8, board_map, c).?;
        }
        for ('a'..'z' + 1, 'Z' + 1 - 'A'..) |c, i| {
            red_indexes[i] = std.mem.indexOfScalar(u8, board_map, c).?;
        }

        var home_indexes: [16]usize = undefined;
        for (.{ '#', '!', '@', '$' }, 0..) |h, offset| {
            var prev: usize = 0;
            for (offset * 4..offset * 4 + 4) |i| {
                home_indexes[i] = std.mem.indexOfScalarPos(u8, board_map, prev + 1, h).?;
                prev = home_indexes[i];
            }
        }

        var map: [705]u16 = undefined;

        _ = std.unicode.utf8ToUtf16Le(&map, board_map) catch unreachable;

        for (red_indexes) |i| map[i] = ' ';
        for (home_indexes) |i| map[i] = ' ';

        break :blk .{
            .map = map,
            .path_indexes = red_indexes,
            .home_indexes = home_indexes,
        };
    };

    fn indexes(self: *@This(), team: *const Team, idx: usize) [4]usize {
        var o: [4]usize = undefined;
        for (team.pieces, 0..) |pos, piece_idx| {
            if (pos == -1) {
                o[piece_idx] = self.home_indexes[(4 * idx) + piece_idx];
            } else {
                o[piece_idx] = self.path_indexes[((13 * idx) + @as(usize, @intCast(pos))) % 52];
            }
        }
        return o;
    }

    fn print(self: *@This(), allocator: std.mem.Allocator) void {
        const map = std.unicode.utf16LeToUtf8Alloc(allocator, &self.map) catch unreachable;
        defer allocator.free(map);

        std.debug.print("{s}", .{map});
    }
};

fn findNextMove() i7 {}
