using AsmTool.Misc;
using AsmTool.App;
using AsmTool;
using System;

namespace AsmTool.Systems
{
	[System]
	class AppLogic : ISystem
	{
        //TODO: De-hardcode this. Add a data folder selector UI + auto game detection like the C++ version had.
        public static StringView DataFolderPath = "G:/GOG/Games/Red Faction Guerrilla Re-Mars-tered/data/";

		static void ISystem.Build(App app)
		{

		}

		[SystemInit]
		void Init(App app)
		{

		}

		[SystemStage]
		void Update(App app)
		{

		}

        [SystemStage(.EndFrame)]
        void EndFrame(App app)
        {
            Events.EndFrame();
        }
	}
}