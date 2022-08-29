using AsmTool.App;
using AsmTool;
using System;
using ImGui;

namespace AsmTool.Gui.Documents
{
	public class AsmEditorDocument : GuiDocumentBase
	{
        append String MapName;

        public this(StringView mapName)
        {
            MapName.Set(mapName);
            HasMenuBar = false;
            NoWindowPadding = true;
            HasCustomOutlinerAndInspector = true;
            UnsavedChanges = true;
        }

        public override void Update(App app, Gui gui)
        {
            ImGui.Text("MapEditorDocument main panel...");
            return;
        }

        public override void Save(App app, Gui gui)
        {
            return;
        }

        public override void OnClose(App app, Gui gui)
        {
            return;
        }

        public override bool CanClose(App app, Gui gui)
        {
            return true;
        }

        public override void Outliner(App app, Gui gui)
        {
            ImGui.Text("MapEditorDocument Outliner...");
            return;
        }

        public override void Inspector(App app, Gui gui)
        {
            ImGui.Text("MapEditorDocument Inspector...");
            return;
        }
	}
}