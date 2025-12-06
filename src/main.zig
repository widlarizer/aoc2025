const std = @import("std");
const ParseError = error{
    ParseError,
};

fn mode1_1(fr: *std.Io.Reader) !i64 {
    var state: i64 = 50;
    var pings: i64 = 0;
    while (true) {
        const line = fr.takeDelimiterExclusive('\n') catch break;
        const delta: i64 = parseDelta(line).?;
        state += delta;
        state = @mod(state, 100);
        if (state == 0)
            pings += 1;
        _ = fr.takeByte() catch break;
    }
    return pings;
}

fn parseDelta(buf: []const u8) ?i64 {
    var reader = std.io.Reader.fixed(buf);
    const sign = reader.takeByte() catch return null;
    std.debug.assert(sign == 'L' or sign == 'R');
    const magnitude = std.fmt.parseInt(i64, reader.buffered(), 10) catch return null;
    const val: i64 = if (sign == 'R') magnitude else -magnitude;
    return val;
}

fn mode1_2(fr: *std.Io.Reader) !i64 {
    var state: i64 = 50;
    var pings: i64 = 0;
    while (true) {
        const line = fr.takeDelimiterExclusive('\n') catch break;
        const delta: i64 = parseDelta(line).?;
        if (delta == 0) {
            continue;
        }
        const minus = delta < 0;
        const turns_old: i64 = @divFloor(if (minus) state - 1 else state, 100);
        state += delta;
        const turns_new: i64 = @divFloor(if (minus) state - 1 else state, 100);
        pings += @intCast(@abs(turns_old - turns_new));
        // std.debug.print("turns {d} {d} state {d} delta {d} pings {d}\n", .{ turns_old, turns_new, state, delta, pings });
        _ = fr.takeByte() catch break;
    }
    return pings;
}

fn log10(num: usize) usize {
    var tmp = num;
    var cnt: usize = 0;
    while (true) {
        if (tmp == 0) return cnt;
        tmp /= 10;
        cnt += 1;
    }
}
test "log10" {
    try std.testing.expectEqual(log10(0), @as(usize, 1));
    try std.testing.expectEqual(log10(1), @as(usize, 1));
    try std.testing.expectEqual(log10(1000), @as(usize, 3));
}
const DigitIterator = struct {
    remains_length: usize = 0,
    remains: usize = 0,
    fn next(self: *DigitIterator) ?[]const u8 {
        if (self.remains_length == 0)
            return null;
        const ret = self.remains % 10;
        self.remains = self.remains / 10;
        self.remains_length -= 1;
        return ret;
    }
    pub fn init(num: usize) DigitIterator {
        return DigitIterator{
            .remains_length = log10(num) + 1,
            .remains = num,
        };
    }
};

fn Square(comptime T: type) type {
    return struct {
        const Self = @This();
        dim: usize,
        data: []T,
        pub fn init(d: usize, alloc: std.mem.Allocator) Self {
            return Self{
                .dim = d,
                .data = (try alloc.alloc(usize, d * d)).?,
            };
        }
        pub fn set(self: Self, idx1: usize, idx2: usize, val: T) void {
            self.data[self.dim * idx1 + idx2] = val;
        }
        pub fn get(self: Self, idx1: usize, idx2: usize) T {
            return self.data[self.dim * idx1 + idx2];
        }
    };
}

fn goofy(num: usize, alloc: std.mem.Allocator) bool {
    const digits = DigitIterator.init(num);
    const digits2 = digits;
    const length = digits.remains_length;
    const patterns = Square(?u8).init(length, alloc);
    for (0..length) |idx1| {
        for (0..length) |idx2| {
            patterns.set(idx1, idx2, null);
        }
    }
    // const patterns = [length][length]?u8{} ** null;
    var correct = alloc.alloc(bool, length);
    // const correct = [length]bool{} ** true;
    for (digits, 0..) |digit, digit_idx| {
        for (0..length) |pat_len| {
            patterns.set(pat_len, digit_idx, if (digit_idx < pat_len)
                digit
            else
                patterns.get(pat_len, digit_idx % pat_len));
        }
    }
    for (digits2, 0..) |digit, digit_idx| {
        for (0..length) |pat_len| {
            if (patterns[pat_len][digit_idx] != digit)
                correct[digit_idx] = false;
        }
    }
    for (0..length) |pat_len| {
        if (correct[pat_len])
            return true;
    }
    return false;
}
fn mode2_1(fr: *std.Io.Reader, alloc: std.mem.Allocator) !i64 {
    var count: usize = 0;
    while (true) {
        const start_s = fr.takeDelimiterExclusive('-') catch break;
        const start = try std.fmt.parseInt(usize, start_s, 10);
        const end_s = try fr.takeDelimiterExclusive(',');
        const end = std.fmt.parseInt(usize, end_s, 10) catch break;
        for (start..end + 1) |num| {
            if (goofy(num, alloc))
                count += num;
        }
    }
    return @intCast(count);
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();
    var args = try std.process.argsWithAllocator(gpa);
    _ = args.skip();
    const path: []const u8 = args.next().?;
    const day = try std.fmt.parseInt(usize, args.next().?, 10);
    const mode = try std.fmt.parseInt(usize, args.next().?, 10);
    const runs = try std.fmt.parseInt(usize, args.next().?, 10);
    const expect = if (args.next()) |expect_s| try std.fmt.parseInt(i64, expect_s, 10) else null;

    var time: u64 = 0;
    var timer = try std.time.Timer.start();
    for (0..runs) |_| {
        const file = try std.fs.cwd().openFile(path, .{});
        var read_buffer: [1024 * 1024]u8 = undefined;
        var reader = file.reader(&read_buffer);
        const fr = &reader.interface;
        timer.reset();
        const result = if (day == 1 and mode == 1)
            try mode1_1(fr)
        else if (day == 1 and mode == 2)
            try mode1_2(fr)
        else if (day == 2 and mode == 1)
            try mode2_1(fr, gpa)
            // else if (day == 2 and mode == 2)
            //     try mode2_2(fr)
        else {
            unreachable;
        };
        time += timer.read();
        if (expect != null) {
            std.debug.assert(result == expect.?);
        } else {
            std.debug.print("Result: {d}\n", .{result});
        }
        file.close();
    }
    std.debug.print("Time: {d} ns\n", .{time / runs});
}

test "parsing test" {
    try std.testing.expectEqual(parseDelta("L1"), @as(i64, -1));
    try std.testing.expectEqual(parseDelta("R1"), @as(i64, 1));
}
