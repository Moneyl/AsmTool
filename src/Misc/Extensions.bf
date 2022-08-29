using System;
using AsmTool;
using AsmTool.App;

namespace System
{
	extension Enum
	{
		//The number of values the enum has
		[Comptime]
		public static u32 Count<T>() where T : enum
		{
			return (u32)typeof(T).FieldCount;
		}

        public static String ValueToString(Type type, String str, int value)
        {
            Runtime.Assert(type.IsEnum);
            for (var enumField in type.GetFields())
            {
                if (enumField.[Friend]mFieldData.mData == value)
                    return str..Set(enumField.[Friend]mFieldData.mName);
            }
            return str;
        }

        public static String ValueToString<T>(String str, T value) where T : operator explicit int, enum
        {
            int val = (int)value;
            Type type = typeof(T);
            Runtime.Assert(type.IsEnum);
            for (var enumField in type.GetFields())
            {
                if (enumField.[Friend]mFieldData.mData == *(int*)(void*)&val)
                    return str..Set(enumField.[Friend]mFieldData.mName);
            }
            return str;
        }
	}

    extension StringView
    {
        public static bool Equals(StringView a, StringView b, bool ignoreCase = false)
        {
            return StringView.Compare(a, b, ignoreCase) == 0;
        }
    }

    extension Span<T>
    {
        public static Span<T> Empty = .(null, 0);
    }

    namespace IO
    {
        extension FileFindEntry
        {
            public void GetExtension(String outExt)
            {
                String fileName = this.GetFileName(.. scope .());
                Path.GetExtension(fileName, outExt);
                return;
            }
        }
    }
}

static
{
    public static mixin ClearDictionaryAndDeleteValues(var container)
    {
        for (var kv in container)
            delete kv.value;

        container.Clear();
    }

    public static void ZeroMemory<T>(T* value) where T : struct
    {
        Internal.MemSet(value, 0, sizeof(T));
    }

    public static mixin ScopedLock(System.Threading.Monitor monitor)
    {
        monitor.Exit();
        defer:: monitor.Exit();
    }
}