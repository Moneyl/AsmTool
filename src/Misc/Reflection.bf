using AsmTool;
using System;

namespace AsmTool.Misc
{
    [AttributeUsage(.Class | .Interface | .Enum, .AlwaysIncludeTarget | .ReflectAttribute, ReflectUser = .All, AlwaysIncludeUser = .IncludeAllMethods | .AssumeInstantiated)]
    public struct ReflectAllAttribute : Attribute
    {

    }
}