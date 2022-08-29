using System;

namespace AsmTool
{
	typealias u8 = uint8;
	typealias u16 = uint16;
	typealias u32 = uint32;
	typealias u64 = uint64;

	typealias i8 = int8;
	typealias i16 = int16;
	typealias i32 = int32;
	typealias i64 = int64;

	typealias f32 = float;
	typealias f64 = double;
}

static
{
    //Ensure sized types are the expected size. If any of these fail you're either on a weird platform or there are serious problems
    [Comptime]
	static void ValidateNanoforgeTypeSizes()
    {
        Compiler.Assert(sizeof(AsmTool.u8) == 1);
        Compiler.Assert(sizeof(AsmTool.u16) == 2);
        Compiler.Assert(sizeof(AsmTool.u32) == 4);
        Compiler.Assert(sizeof(AsmTool.u64) == 8);

        Compiler.Assert(sizeof(AsmTool.i8) == 1);
        Compiler.Assert(sizeof(AsmTool.i16) == 2);
        Compiler.Assert(sizeof(AsmTool.i32) == 4);
        Compiler.Assert(sizeof(AsmTool.i64) == 8);

        Compiler.Assert(sizeof(AsmTool.f32) == 4);
        Compiler.Assert(sizeof(AsmTool.f64) == 8);
    }
}
