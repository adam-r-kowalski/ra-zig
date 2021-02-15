const parser = @import("parser.zig");
pub const parse = parser.parse;
pub const astString = parser.astString;
pub const lower = @import("lower.zig").lower;
pub const irString = @import("lower.zig").irString;
const module = @import("module.zig");
pub const codegen = @import("codegen.zig").codegen;
pub const x86String = @import("codegen.zig").x86String;
pub const data = @import("data.zig");
