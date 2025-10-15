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

    const safeIndexes = blk: {
        var p: @Vector(8, i7) = @splat(0);
        for (1..8) |i| {
            p[i] = p[i - 1] + if (i % 2 == 0) 8 else 5;
        }
        break :blk p;
    };

    const Self = @This();

    pub fn init(teams: []*Team) Game {
        assert(teams.len >= 2 and teams.len <= 4);
        return .{ .teams = teams, .curr_team = teams[0] };
    }

    pub fn rollDice(self: *Self) void {
        self.dice_num = std.crypto.random.intRangeAtMost(u3, 1, 6);
        self.dice_rolled = true;
    }

    pub fn availableMoves(self: *Self) @Vector(4, bool) {
        if (!self.dice_rolled) return @splat(false);

        var moves: [4]bool = undefined;
        for (self.curr_team.pieces, 0..) |piece, i| {
            moves[i] =
                (piece != -1 or self.dice_num == 6) and
                (piece + self.dice_num < total_available_moves);
        }
        return moves;
    }

    pub fn next(self: *Self) void {
        assert(self.dice_num != 0 and self.dice_rolled == true);
        self.dice_rolled = false;

        const curr_team_idx = std.mem.indexOfScalar(*Team, self.teams, self.curr_team).?;
        self.curr_team = self.teams[(curr_team_idx + 1) % self.teams.len];
    }

    pub fn move(self: *Self, piece_idx: Piece) void {
        const curr_piece: i7 = self.curr_team.pieces[@intFromEnum(piece_idx)];

        assert(self.dice_num != 6 or curr_piece == -1);
        assert(self.dice_num != 0 and self.dice_rolled == true);
        assert(curr_piece + self.dice_num < total_available_moves);

        if (curr_piece == -1) {
            self.curr_team.pieces[@intFromEnum(piece_idx)] = 0;
        } else {
            self.curr_team.pieces[@intFromEnum(piece_idx)] += self.dice_num;
        }

        const new_pos = self.curr_team.pieces[@intFromEnum(piece_idx)];
        if (isSafe(new_pos)) {
            std.debug.print("safe place\n", .{});
        }
    }

    pub fn isSafe(pos: i7) bool {
        return std.simd.firstIndexOfValue(safeIndexes, pos) != null;
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

    const board: Board = .init;

    game.teams[0].pieces = .{ -1, -1, -1, -1 };
    game.teams[1].pieces = .{ -1, -1, -1, -1 };
    game.teams[2].pieces = .{ -1, -1, -1, -1 };
    game.teams[3].pieces = .{ -1, -1, -1, -1 };

    var print_buf: [2048]u8 = undefined;
    // for (teams) |team| {
    //     for (0..56) |i| {
    //         team.pieces[3] = @intCast(i);
    try board.print(&print_buf, game.teams);
    //     }
    // }
}

const board_map =
    \\ [ ][ ][ ][ ][ ][ ][X][Y][Z][ ][ ][ ][ ][ ][ ]
    \\ [ ][!][ ][!][ ][ ][W][.][a][ ][ ][@][ ][@][ ]
    \\ [ ][ ][ ][ ][ ][ ][V][.][b][ ][ ][ ][ ][ ][ ]
    \\ [ ][!][ ][!][ ][ ][U][.][c][ ][ ][@][ ][@][ ]
    \\ [ ][ ][ ][ ][ ][ ][T][.][d][ ][ ][ ][ ][ ][ ]
    \\ [ ][ ][ ][ ][ ][ ][S][.][e][ ][ ][ ][ ][ ][ ]
    \\ [M][N][O][P][Q][R][ ][.][ ][f][g][h][i][j][k]
    \\ [L][.][.][.][.][.][.][ ][.][.][.][.][.][.][l]
    \\ [K][J][I][H][G][F][ ][.][ ][r][q][p][o][n][m]
    \\ [ ][ ][ ][ ][ ][ ][E][.][s][ ][ ][ ][ ][ ][ ]
    \\ [ ][ ][ ][ ][ ][ ][D][.][t][ ][ ][ ][ ][ ][ ]
    \\ [ ][#][ ][#][ ][ ][C][.][u][ ][ ][$][ ][$][ ]
    \\ [ ][ ][ ][ ][ ][ ][B][.][v][ ][ ][ ][ ][ ][ ]
    \\ [ ][#][ ][#][ ][ ][A][.][w][ ][ ][$][ ][$][ ]
    \\ [ ][ ][ ][ ][ ][ ][z][y][x][ ][ ][ ][ ][ ][ ]
    \\
;

pub const Board = struct {
    map: [board_map.len]u8,
    path_indexes: [52]usize,
    home_indexes: [16]usize,
    in_indexes: [24]usize,

    pub const init: Board = blk: {
        @setEvalBranchQuota(50_000);

        var red_indexes: [52]usize = undefined;
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

        var in_indexes: [24]usize = undefined;
        for (0..24) |i| {
            const prev: usize = if (i == 0) 0 else in_indexes[i - 1] + 1;
            in_indexes[i] = std.mem.indexOfScalarPos(u8, board_map, prev, '.').?;
        }

        var map: [board_map.len]u8 = board_map.*;

        for (red_indexes) |i| map[i] = ' ';
        for (home_indexes) |i| map[i] = ' ';
        for (in_indexes) |i| map[i] = ' ';

        break :blk .{
            .map = map,
            .path_indexes = red_indexes,
            .home_indexes = home_indexes,
            .in_indexes = in_indexes,
        };
    };

    fn indexes(self: *const @This(), team: *const Team, idx: usize) [4]usize {
        var o: [4]usize = undefined;
        for (team.pieces, 0..) |pos, piece_idx| {
            if (pos == -1) {
                o[piece_idx] = self.home_indexes[(4 * idx) + piece_idx];
            } else if (pos >= 0 and pos <= 50) {
                o[piece_idx] = self.path_indexes[((13 * idx) + @as(usize, @intCast(pos))) % 52];
            } else {
                o[piece_idx] = switch (idx) {
                    0 => self.in_indexes[self.in_indexes.len - 6 ..][55 - @as(usize, @intCast(pos))],
                    1 => self.in_indexes[6 .. 6 + 6][@as(usize, @intCast(pos)) - 50],
                    2 => self.in_indexes[0..6][@as(usize, @intCast(pos)) - 50],
                    3 => self.in_indexes[2 * 6 .. 2 * 6 + 6][55 - @as(usize, @intCast(pos))],
                    else => unreachable,
                };
            }
        }
        return o;
    }

    const Printable = struct {
        marker: []const u8,
        pos: usize,
    };

    pub fn print(self: *const @This(), buf: []u8, teams: []*Team) !void {
        var printables: [16 + 8]Printable = undefined;

        for (teams, 0..) |team, i| {
            for (self.indexes(team, i), 0..) |pos, offset| {
                printables[i * teams.len + offset] = .{
                    .marker = colored("◉", team.color),
                    .pos = pos,
                };
            }
        }

        var p: usize = 0;
        for (0..8) |i| {
            const color: Color = switch (i) {
                0...1 => .red,
                2...3 => .green,
                4...5 => .blue,
                else => .yellow,
            };
            if (i % 2 == 0) {
                printables[16 + i] = .{
                    .marker = colored("⌂", color),
                    .pos = self.path_indexes[p],
                };
            } else {
                printables[16 + i] = .{
                    .marker = "☆",
                    .pos = self.path_indexes[p],
                };
            }
            p += if (i % 2 == 0) 8 else 5;
        }

        std.mem.sort(Printable, &printables, {}, sortPosColor);

        var last_pos: usize = 0;
        var written: usize = 0;

        for (printables) |pr| {
            if (last_pos > pr.pos) continue;

            const board_part = self.map[last_pos..pr.pos];
            written += try dimmed(buf[written..], board_part);

            @memcpy(buf[written .. written + pr.marker.len], pr.marker);
            written += pr.marker.len;

            last_pos = pr.pos + 1;
        }

        const board_part = self.map[last_pos..self.map.len];
        written += try dimmed(buf[written..], board_part);

        std.debug.print("{s}\n", .{buf[0..written]});
    }

    fn sortPosColor(_: void, a: Printable, b: Printable) bool {
        return std.sort.asc(usize)({}, a.pos, b.pos);
    }

    fn dimmed(buf: []u8, s: []const u8) !usize {
        var w: std.Io.Writer = .fixed(buf);
        var r: std.Io.Reader = .fixed(s);

        var size: usize = 0;

        while (true) {
            size += try w.write("\x1b[2m");
            size += try r.streamDelimiterEnding(&w, '\n');
            size += try w.write("\x1b[0m");

            if ((r.peekByte() catch break) == '\n') {
                try r.streamExact(&w, 1);
                size += 1;
            }
        }

        return size;
    }

    fn colored(comptime s: []const u8, color: Color) []const u8 {
        return switch (color) {
            .red => std.fmt.comptimePrint("\x1b[31m{s}\x1b[0m", .{s}),
            .green => std.fmt.comptimePrint("\x1b[32m{s}\x1b[0m", .{s}),
            .yellow => std.fmt.comptimePrint("\x1b[33m{s}\x1b[0m", .{s}),
            .blue => std.fmt.comptimePrint("\x1b[34m{s}\x1b[0m", .{s}),
        };
    }
};
