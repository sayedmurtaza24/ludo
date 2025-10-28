const std = @import("std");
const assert = std.debug.assert;
const bitset = std.bit_set;

const moves_per_player_ground = 13;
const total_moves_play_area = 4 * moves_per_player_ground;
const total_moves = total_moves_play_area + 6;

pub const Piece = enum(u2) { _ };
pub const Color = enum { red, green, blue, yellow };

pub const Team = struct {
    pieces: std.EnumArray(Piece, i7),
    ended_at: isize = -1,
    num: u2,

    const Self = @This();

    const safe_positions = blk: {
        var p: [8]i7 = @splat(0);
        for (1..8) |i| p[i] = p[i - 1] + if (i % 2 != 0) 8 else 5;
        break :blk p;
    };

    inline fn isSafePos(pos: i7) bool {
        return if (pos > total_moves_play_area - 1) return true else {
            return std.mem.indexOfScalar(i7, &safe_positions, pos) != null;
        };
    }

    pub fn init(num: u2) Team {
        return .{ .num = num, .pieces = .initFill(-1) };
    }

    pub fn calcPieceUnsafeGlobalPos(self: Self, piece: Piece) ?i7 {
        const piece_pos = self.pieces.get(piece);

        if (isSafePos(piece_pos)) return null;

        const team_offset: i7 = self.num;
        const piece_global_pos: i7 = @mod(
            piece_pos + team_offset * moves_per_player_ground,
            total_moves_play_area,
        );
        return piece_global_pos;
    }

    pub fn hasPieceAtUnsafeGlobalPos(self: *Self, global_pos: i7) ?Piece {
        var it = self.pieces.iterator();
        while (it.next()) |entry| {
            if (entry.value.* == -1) continue;
            if (entry.value.* > total_moves_play_area) continue;

            const team_offset: i7 = self.num;
            const piece_global_pos: i7 = @mod(
                entry.value.* + team_offset * moves_per_player_ground,
                total_moves_play_area,
            );

            if (piece_global_pos == global_pos) return entry.key;
        }
        return null;
    }

    pub fn movePiece(self: *Self, piece: Piece, new_pos: i7) void {
        self.pieces.set(piece, new_pos);
    }

    pub fn calcEnded(self: *Self, move_num: isize) void {
        if (self.ended_at > 0) return;

        var it = self.pieces.iterator();

        var has_won: bool = true;
        while (it.next()) |item| {
            if (item.value.* != total_moves) {
                has_won = false;
                break;
            }
        }

        if (has_won) self.ended_at = move_num;
    }
};

pub const Dice = struct {
    num: u3 = 0,
    mod: enum { NotRolled, Rolled, Used },
    rng: std.Random,

    const Self = @This();

    pub fn init(prng: std.Random) Dice {
        return .{ .rng = prng, .mod = .NotRolled };
    }

    pub fn roll(self: *Self) error{NotRollable}!u3 {
        if (self.mod != .NotRolled) return error.NotRollable;
        self.mod = .Rolled;
        self.num = self.rng.intRangeAtMost(u3, 1, 6);
        return self.num;
    }

    pub fn setUsed(self: *Self) error{NotUsable}!u3 {
        if (self.mod != .Rolled) return error.NotUsable;
        self.mod = .Used;
        return self.num;
    }

    pub fn reset(self: *Self) error{NotResettable}!void {
        if (self.mod != .Used) return error.NotResettable;
        self.mod = .NotRolled;
        self.num = 0;
        return;
    }
};

pub const Game = struct {
    teams: *std.EnumMap(Color, Team),
    dice: Dice,
    curr: Color,

    move_num: isize = 0,
    ended: bool = false,

    const Self = @This();

    pub fn init(random: std.Random, teams: *std.EnumMap(Color, Team)) error{NotEnoughPlayers}!Game {
        if (teams.count() < 2) return error.NotEnoughPlayers;

        var it = teams.iterator();

        return .{
            .curr = it.next().?.key,
            .dice = .init(random),
            .teams = teams,
        };
    }

    pub fn availableMoves(self: *Self, team_color: Color) bitset.IntegerBitSet(4) {
        if (team_color != self.curr) return .initEmpty();

        var curr = self.teams.getAssertContains(team_color);
        var iter = curr.pieces.iterator();

        var moves: bitset.IntegerBitSet(4) = .initEmpty();
        var i: usize = 0;

        while (iter.next()) |entry| : (i += 1) {
            const piece_pos = entry.value.*;
            const can_move = piece_pos != -1 or self.dice.num == 6;
            const has_room = piece_pos + self.dice.num <= total_moves_play_area;

            if (can_move and has_room) moves.set(i);
        }

        return moves;
    }

    pub fn move(self: *Self, piece: Piece) !void {
        const log = std.log.scoped(.move);

        const moves = self.availableMoves(self.curr);
        if (moves.count() == 0) return error.NoAvailableMove;
        if (!moves.isSet(@intFromEnum(piece))) return error.IllegalMove;

        var curr_team = self.teams.getPtrAssertContains(self.curr);

        const curr_pos: i7 = curr_team.pieces.get(piece);
        const diceNum = try self.dice.takeNext();

        if (curr_pos == -1) {
            curr_team.movePiece(piece, 0);
            log.info("moved piece out", .{});
        } else {
            curr_team.movePiece(piece, curr_pos + diceNum);
            log.info("moved piece by {}", .{diceNum});
        }

        if (curr_team.calcPieceUnsafeGlobalPos(piece)) |go| {
            log.info("piece has unsafe global pos {}", .{go});

            var it = self.teams.iterator();

            while (it.next()) |entry| {
                if (entry.key == self.curr) continue;

                if (entry.value.hasPieceAtUnsafeGlobalPos(go)) |p| {
                    log.info("piece has hit another piece {s}", .{@tagName(entry.key)});
                    entry.value.movePiece(p, -1);
                }
            }
        }
    }

    pub fn forward(self: *Self) !void {
        const log = std.log.scoped(.move);

        if (self.ended) return error.GameEnded;

        if (!self.dice.used) {
            const moves = self.availableMoves(self.curr).count();
            if (moves != 0) return error.DicePreparedNotUsed;
            _ = self.dice.takeNext() catch {};
        }

        if (self.dice.num != 6) {
            const curr: u4 = @intFromEnum(self.curr);
            self.curr = @enumFromInt((curr + 1) % self.teams.count());

            log.info("dice != 6, switching team to {}", .{self.curr});
        } else {
            log.info("dice == 6, keeping team as {}", .{self.curr});
        }

        if (self.dice.used) return error.DiceNotRolled;

        self.move_num += 1;

        self.teams.getPtrAssertContains(self.curr).calcEnded(self.move_num);

        var count_team_won: u2 = 0;
        var it = self.teams.iterator();

        while (it.next()) |entry| {
            if (entry.value.ended_at != -1) count_team_won += 1;
        }

        if (count_team_won >= 3) self.ended = true;
    }
};

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

    fn indexes(self: *const @This(), team: *const Team) [4]usize {
        const idx: usize = team.num;

        var o: [4]usize = undefined;
        for (team.pieces.values, 0..) |pos, piece_idx| {
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

    pub fn print(self: *const @This(), buf: []u8, teams: *std.EnumMap(Color, Team)) !void {
        var printables: [16 + 8]Printable = undefined;

        var it = teams.iterator();

        while (it.next()) |entry| {
            for (self.indexes(entry.value), 0..) |pos, offset| {
                printables[entry.value.num * teams.count() + offset] = .{
                    .marker = colored("◉", entry.key),
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
                    .marker = colored("☆", color),
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
