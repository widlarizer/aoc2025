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

fn digit_len(num: usize) usize {
    var tmp = num;
    var cnt: usize = 0;
    while (true) {
        if (tmp == 0) break;
        tmp /= 10;
        cnt += 1;
    }
    if (cnt == 0)
        cnt = 1;
    return cnt;
}

test "digit_len" {
    try std.testing.expectEqual(1, digit_len(0));
    try std.testing.expectEqual(1, digit_len(1));
    try std.testing.expectEqual(4, digit_len(1000));
    try std.testing.expectEqual(4, digit_len(2121));
}

const DigitIterator = struct {
    remains_length: usize = 0,
    remains: usize = 0,
    fn next(self: *DigitIterator) ?u8 {
        if (self.remains_length == 0)
            return null;
        const ret: u8 = @intCast(self.remains % 10);
        self.remains = self.remains / 10;
        self.remains_length -= 1;
        return ret;
    }
    pub fn init(num: usize) DigitIterator {
        return DigitIterator{
            .remains_length = digit_len(num),
            .remains = num,
        };
    }
};

fn Square(comptime T: type) type {
    return struct {
        const Self = @This();
        dim: usize,
        data: []T,
        pub fn init(d: usize, alloc: std.mem.Allocator) !Self {
            return Self{
                .dim = d,
                .data = try alloc.alloc(T, d * d),
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

fn goofy(num: usize, alloc: std.mem.Allocator, second_lvl: bool) !bool {
    var digits = DigitIterator.init(num);
    var digits2 = digits;
    const length = digits.remains_length;
    const patterns = try Square(?u8).init(length, alloc);
    defer alloc.free(patterns.data);
    for (0..length) |idx1| {
        for (0..length) |idx2| {
            patterns.set(idx1, idx2, null);
        }
    }
    // const patterns = [length][length]?u8{} ** null;
    var correct = try alloc.alloc(bool, length);
    // std.debug.print("{} num\n", .{num});
    defer alloc.free(correct);
    // const correct = [length]bool{} ** true;
    for (0..length) |pat_idx| {
        correct[pat_idx] = true;
    }
    var digit_idx: usize = 0;
    while (digits.next()) |digit| {
        for (1..length + 1) |pat_len| {
            patterns.set(pat_len - 1, digit_idx, if (digit_idx < pat_len)
                digit
            else
                patterns.get(pat_len - 1, digit_idx % pat_len));
        }
        digit_idx += 1;
    }
    digit_idx = 0;
    while (digits2.next()) |digit| {
        for (1..length + 1) |pat_len| {
            // std.debug.print("sniff {} {} = {} , {}\n", .{ pat_len - 1, digit_idx, patterns.get(pat_len - 1, digit_idx).?, digit });
            if (patterns.get(pat_len - 1, digit_idx) != digit) {
                // std.debug.print("false {}\n", .{pat_len - 1});
                correct[pat_len - 1] = false;
            }
        }
        digit_idx += 1;
    }
    // for (correct) |c| {
    //     std.debug.print("correct {}\n", .{c});
    // }
    for (0..length - 1) |pat_idx| {
        const pat_len = pat_idx + 1;
        if (!second_lvl and correct[pat_idx] and length % pat_len == 0 and length / pat_len == 2) {
            // std.debug.print("win {}\n", .{pat_len});
            return true;
        }
        if (second_lvl and correct[pat_idx] and length % pat_len == 0) {
            // std.debug.print("win {}\n", .{pat_len});
            return true;
        }
    }
    return false;
}
fn goofy_in_range(alloc: std.mem.Allocator, start: usize, end: usize, second_lvl: bool) !i64 {
    // std.debug.print("in range {} {}?\n", .{ start, end });
    var count: usize = 0;
    var sum: usize = 0;
    for (start..end + 1) |num| {
        if (try goofy(num, alloc, second_lvl)) {
            // std.debug.print("goofy {}\n", .{num});
            count += 1;
            sum += num;
        }
    }
    // std.debug.print("in range {} sum {}\n", .{ count, sum });
    return @intCast(sum);
}

fn mode2(fr: *std.Io.Reader, alloc: std.mem.Allocator, second_lvl: bool) !i64 {
    var count: i64 = 0;
    while (true) {
        const start_s = fr.takeDelimiterExclusive('-') catch break;
        _ = try fr.takeByte();
        const start = try std.fmt.parseInt(usize, start_s, 10);
        const end_s = try fr.takeDelimiterExclusive(',');
        const end = std.fmt.parseInt(usize, end_s, 10) catch break;
        count += @intCast(try goofy_in_range(alloc, start, end, second_lvl));
        _ = fr.takeByte() catch break;
    }
    return count;
}

test "goofy" {
    const alloc = std.testing.allocator;
    // const inp: []u8 = "1000-1111";
    try std.testing.expectEqual(true, goofy(2121, alloc, false));
    try std.testing.expectEqual(false, goofy(1091, alloc, false));
    try std.testing.expectEqual(2121, goofy_in_range(alloc, 1000, 1111, false));
}

// , alloc: std.mem.Allocator
fn joltage(line: []const u8, length: usize) ?usize {
    // std.debug.print("jolting {s} {}\n", .{ line, length });
    if (length == 0) return null;
    const trim = length - 1;
    const first_idx = std.sort.argMax(u8, line[0 .. line.len - trim], {}, std.sort.asc(u8)).?;
    const first = line[first_idx] - '0';
    // const second = std.sort.max(u8, line[first_idx + 1 ..], {}, std.sort.asc(u8)).? - '0';

    const rest = joltage(line[first_idx + 1 ..], length - 1);
    const ret = if (rest != null) first * std.math.pow(usize, 10, length - 1) + rest.? else first;
    // std.debug.print("first {} ret {}\n", .{ first, ret });
    return ret;
}
pub fn mode3(fr: *std.Io.Reader, second_lvl: bool) !i64 {
    var sum: usize = 0;
    while (true) {
        const line = fr.takeDelimiterExclusive('\n') catch break;
        _ = fr.takeByte() catch break;
        sum += joltage(line, if (second_lvl) 12 else 2).?;
    }
    return @intCast(sum);
}
test "joltage" {
    try std.testing.expectEqual(45, joltage("41115", 2));
    try std.testing.expectEqual(415, joltage("41115", 3));
    try std.testing.expectEqual(89, joltage("11189", 2));
    try std.testing.expectEqual(1189, joltage("11189", 4));
}

fn remove(rolls: *std.ArrayList(bool), neighbors: *[]usize, dim1: usize, dim2: usize) i64 {
    var removed: i64 = 0;
    for (0..dim1) |idx1| {
        for (0..dim2) |idx2| {
            if (rolls.items[idx1 * dim2 + idx2]) {
                if (neighbors.*[idx1 * dim2 + idx2] < 4) {
                    removed += 1;
                    rolls.items[idx1 * dim2 + idx2] = false;
                }
            }
        }
    }
    return removed;
}
fn update(rolls: *std.ArrayList(bool), neighbors: *[]usize, dim1: usize, dim2: usize) void {
    for (0..dim1) |idx1| {
        for (0..dim2) |idx2| {
            neighbors.*[idx1 * dim2 + idx2] = 0;
        }
    }
    for (0..dim1) |idx1| {
        for (0..dim2) |idx2| {
            const start1 = if (idx1 > 0) idx1 - 1 else 0;
            const start2 = if (idx2 > 0) idx2 - 1 else 0;
            const end1 = @min(idx1 + 1, dim1 - 1);
            const end2 = @min(idx2 + 1, dim2 - 1);
            if (!rolls.items[idx1 * dim2 + idx2])
                continue;
            for (start1..end1 + 1) |it1| {
                for (start2..end2 + 1) |it2| {
                    if ((it1 != idx1 or it2 != idx2) and rolls.items[idx1 * dim2 + idx2]) {
                        neighbors.*[it1 * dim2 + it2] += 1;
                    }
                }
            }
        }
    }
}
pub fn mode4(alloc: std.mem.Allocator, fr: *std.Io.Reader, second_lvl: bool) !i64 {
    var sum: i64 = 0;
    var rolls = try std.ArrayList(bool).initCapacity(alloc, 1000);
    var dim1_check: ?usize = null;
    var dim2: usize = 0;
    while (true) {
        const line = fr.takeDelimiterExclusive('\n') catch break;
        _ = try fr.takeByte();
        if (line.len == 0) break;
        if (dim1_check == null) {
            dim1_check = line.len;
        } else {
            std.debug.assert(dim1_check.? == line.len);
        }
        for (line) |c| {
            try rolls.append(alloc, c == '@');
        }
        dim2 += 1;
    }
    const dim1: usize = dim1_check.?;
    var neighbors = try alloc.alloc(usize, dim1 * dim2);
    while (true) {
        update(&rolls, &neighbors, dim1, dim2);
        const added = remove(&rolls, &neighbors, dim1, dim2);
        sum += added;
        if (!second_lvl or added == 0)
            return sum;
    }
}
const Inventory = struct {
    const Range = struct {
        first: usize,
        last: usize,
        node: std.DoublyLinkedList.Node,
        fn edge_in_other(self: *Range, other: Range) bool {
            return ((other.first <= self.first and self.first <= other.last) or (other.first <= self.last and self.last <= other.last));
        }
        fn merge(self: *Range, other: Range) Range {
            return Range{
                .first = @min(self.first, other.first),
                .last = @max(self.last, other.last),
                .node = self.node,
            };
        }
    };
    ranges: std.DoublyLinkedList,

    fn add_range(self: *Inventory, alloc: std.mem.Allocator, first: usize, last: usize) !void {
        var new_range = try alloc.create(Range);
        new_range.* = Range{ .first = first, .last = last, .node = .{} };
        var it = self.ranges.first;
        while (it) |node| : (it = node.next) {
            const range: *Range = @fieldParentPtr("node", node);
            if (range.edge_in_other(new_range.*) or new_range.edge_in_other(range.*)) {
                const new_new_range = range.merge(new_range.*);
                self.ranges.remove(node);
                alloc.destroy(range);
                alloc.destroy(new_range);
                try self.add_range(alloc, new_new_range.first, new_new_range.last);
                return;
            }
        }
        self.ranges.prepend(&new_range.node);
    }
    fn total_count(self: *Inventory) usize {
        var sum: usize = 0;
        var it = self.ranges.first;
        while (it) |node| : (it = node.next) {
            const range: *Range = @fieldParentPtr("node", node);
            sum += range.last - range.first + 1;
        }
        return sum;
    }
    fn is_fresh(self: *Inventory, item: usize) bool {
        var it = self.ranges.first;
        while (it) |node| : (it = node.next) {
            const range: *Inventory.Range = @fieldParentPtr("node", node);
            if (item >= range.first and item <= range.last)
                return true;
        }
        return false;
    }
    fn free(self: *Inventory, alloc: std.mem.Allocator) !void {
        var it = self.ranges.first;
        while (it) |node| {
            it = node.next;
            const range: *Inventory.Range = @fieldParentPtr("node", node);
            alloc.destroy(range);
        }
    }
};
test "inventory" {
    // std.testing.allocator
    const alloc = std.testing.allocator;
    var inv = Inventory{ .ranges = .{} };
    try inv.add_range(alloc, 3, 6);
    try inv.add_range(alloc, 10, 11);
    try inv.add_range(alloc, 11, 15);
    try inv.add_range(alloc, 2, 4);
    try std.testing.expectEqual(true, inv.is_fresh(11));
    try std.testing.expectEqual(true, inv.is_fresh(4));
    try std.testing.expectEqual(false, inv.is_fresh(200));
    try std.testing.expectEqual(11, inv.total_count());
    try inv.free(alloc);
}
pub fn mode5(alloc: std.mem.Allocator, fr: *std.Io.Reader, second_lvl: bool) !i64 {
    var sum: i64 = 0;
    var inv = Inventory{ .ranges = .{} };
    while (true) {
        if (try fr.peekByte() == '\n') {
            _ = try fr.takeByte();
            break;
        }
        const first_s = try fr.takeDelimiterExclusive('-');
        _ = try fr.takeByte();
        const first = try std.fmt.parseInt(usize, first_s, 10);
        const last_s = try fr.takeDelimiterExclusive('\n');
        _ = try fr.takeByte();
        const last = try std.fmt.parseInt(usize, last_s, 10);
        try inv.add_range(alloc, first, last);
    }
    if (second_lvl) {
        return @intCast(inv.total_count());
    }
    while (true) {
        const item_s = fr.takeDelimiterExclusive('\n') catch break;
        _ = try fr.takeByte();
        // std.debug.print("_{s}_\n", .{item_s});
        const item = try std.fmt.parseInt(usize, item_s, 10);
        if (inv.is_fresh(item))
            sum += 1;
    }
    try inv.free(alloc);
    return sum;
}

pub fn mode6(alloc: std.mem.Allocator, fr: *std.Io.Reader, second_lvl: bool) !i64 {
    std.debug.assert(!second_lvl);
    var nums = try std.ArrayList(std.ArrayList(usize)).initCapacity(alloc, 1);
    var ops = try std.ArrayList(u8).initCapacity(alloc, 1);
    var sum: usize = 0;
    var row: usize = 0;
    var col: usize = 0;
    while (true) : (row += 1) {
        col = 0;
        // std.debug.print("row start {}\n", .{row});
        while ((fr.peekByte() catch break) != '\n') {
            while (try fr.peekByte() == ' ') {
                _ = try fr.takeByte();
            }
            var buf = try std.ArrayList(u8).initCapacity(alloc, 0);
            while (!std.ascii.isWhitespace(try fr.peekByte())) {
                try buf.append(alloc, try fr.takeByte());
            }
            if (buf.items.len == 0) {} else if (std.ascii.isAlphanumeric(buf.items[0])) {
                const num = try std.fmt.parseInt(usize, buf.items, 10);
                if (row == 0)
                    try nums.append(alloc, try std.ArrayList(usize).initCapacity(alloc, 1));
                // std.debug.print("nums {} append {}\n", .{ col, num });
                try nums.items[col].append(alloc, num);
                try ops.append(alloc, '.');
            } else {
                std.debug.assert(buf.items.len == 1);
                // std.debug.print("op {c} col {}\n", .{buf.items[0]});
                ops.items[col] = buf.items[0];
            }
            while (try fr.peekByte() == ' ') {
                // std.debug.print("skip _{c}_\n", .{try fr.peekByte()});
                _ = try fr.takeByte();
            }
            col += 1;
        }
        if (try fr.takeByte() != '\n')
            break;
        if (col == 0) {
            // std.debug.print("boom\n", .{});
            break;
        }
    }
    // for (nums.items) |num_col| {
    //     for (num_col.items) |num| {
    //         std.debug.print("{} ", .{num});
    //     }
    //     std.debug.print("\n", .{});
    // }
    for (nums.items, 0..) |num_col, i| {
        var acc: usize = if (ops.items[i] == '*') 1 else 0;
        for (num_col.items) |num| {
            if (ops.items[i] == '*') {
                acc *= num;
            } else {
                acc += num;
            }
        }
        sum += acc;
    }
    for (nums.items) |*num_col| {
        num_col.clearAndFree(alloc);
    }
    nums.clearAndFree(alloc);
    return @intCast(sum);
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
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
        else if (day == 2)
            try mode2(fr, gpa, mode == 2)
        else if (day == 3)
            try mode3(fr, mode == 2)
        else if (day == 4)
            try mode4(gpa, fr, mode == 2)
        else if (day == 5)
            try mode5(gpa, fr, mode == 2)
        else if (day == 6)
            try mode6(gpa, fr, mode == 2)
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
