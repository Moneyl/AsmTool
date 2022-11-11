using AsmTool.Systems;
using AsmTool.Render;
using AsmTool.Misc;
using AsmTool.App;
using AsmTool.Gui;
using AsmTool;
using Win32;
using System;

namespace AsmTool
{
	public class Program
	{
		public static void Main(String[] args)
		{
            //TODO: Fix needing to manually set this. Should auto set using build system
#if DEBUG
            StringView assetsBasePath = "C:/Users/lukem/source/repos/AsmTool/assets/";
#else
            StringView assetsBasePath = "./assets/";
#endif

            App.Build!(AppState.Running)
                ..AddResource<BuildConfig>(new .("AsmTool", assetsBasePath, "v1.1.0", args))
                ..AddSystem<Window>(isResource: true)
                ..AddSystem<Input>(isResource: true)
                ..AddSystem<Renderer>()
                ..AddSystem<Gui>(isResource: true)
                ..AddSystem<AppLogic>()
				.Run();
		}
	}
}