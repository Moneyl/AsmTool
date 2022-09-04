using AsmTool.App;
using AsmTool;
using System;
using ImGui;
using System.Collections;
using AsmTool.Gui.Documents;
using System.IO;
using Win32;

namespace AsmTool.Gui.Panels
{
    public class MainMenuBar : GuiPanelBase
    {
        private ImGui.DockNodeFlags dockspaceFlags = 0;
        public List<MenuItem> MenuItems = new .() ~ DeleteContainerAndItems!(_);
        public ImGui.ID DockspaceId = 0;
        public ImGui.ID DockspaceCentralNodeId = 0;
        bool ShowImGuiDemo = true;
        public bool ShowFrameTime = true;

        public override void Update(App app, Gui gui)
        {
            static bool firstDraw = true;
            if (firstDraw)
            {
                GenerateMenus(gui);
                firstDraw = false;
            }

            DrawMainMenuBar(app, gui);
            DrawDockspace(app, gui);
            if (ShowImGuiDemo)
	            ImGui.ShowDemoWindow(&ShowImGuiDemo);
        }

        private void DrawMainMenuBar(App app, Gui gui)
        {
            FrameData frameData = app.GetResource<FrameData>();

            if (ImGui.BeginMainMenuBar())
            {
                if (ImGui.BeginMenu("File"))
                {
                    if (ImGui.MenuItem("Open file...")) { }
                    if (ImGui.MenuItem("Save file...")) { }
                    if (ImGui.MenuItem("Exit"))
					{
                        gui.CloseAppRequested = true;
                        for (GuiDocumentBase doc in gui.Documents)
                            doc.Open = false; //Close all documents so save confirmation modal appears for them
				    }
                    ImGui.EndMenu();
                }
                if (ImGui.BeginMenu("Edit"))
                {
                    ImGui.EndMenu();
                }

                //Draw menu item for each panel (e.g. file explorer, properties, log, etc) so user can toggle visibility
                for (MenuItem item in MenuItems)
                    item.Draw();

                if (ImGui.BeginMenu("View"))
                {
                    if (ImGui.MenuItem("Show frametime", "", &ShowFrameTime))
                    {

                    }
                    ImGui.EndMenu();
                }
                if (ImGui.BeginMenu("Tools"))
                {
                    if (ImGui.MenuItem("Open test asm_pc"))
                    {
                        StringView testAsmPath = @"I:\_AsmToolTesting\mpdlc_division\mpdlc_division.asm_pc";
                        gui.OpenDocument(Path.GetFileName(testAsmPath, .. scope .()), testAsmPath, new AsmEditorDocument(testAsmPath));
                    }
                    if (ImGui.MenuItem("Validate"))
                    {
                        Win32.MessageBoxA(0, "This feature hasn't been implemented yet.", "Not implemented", .OK);
                    }
                    ImGui.EndMenu();
                }
                if (ImGui.BeginMenu("Theme"))
                {
                    bool darkBlueSelected = ImGui.CurrentTheme() == .DarkBlue;
                    bool orangeSelected = ImGui.CurrentTheme() == .Orange;
                    bool darkSelected = ImGui.CurrentTheme() == .Dark;
                    bool lightSelected = ImGui.CurrentTheme() == .Light;
                    bool classicSelected = ImGui.CurrentTheme() == .Classic;
                    if (ImGui.MenuItem("Dark blue", null, darkBlueSelected))
                    {
                        ImGui.SetThemePreset(.DarkBlue);
                    }
                    if (ImGui.MenuItem("Orange", null, orangeSelected))
                    {
                        ImGui.SetThemePreset(.Orange);
                    }
                    if (ImGui.MenuItem("Dark", null, darkSelected))
                    {
                        ImGui.SetThemePreset(.Dark);
                    }
                    if (ImGui.MenuItem("Light", null, lightSelected))
                    {
                        ImGui.SetThemePreset(.Light);
                    }
                    if (ImGui.MenuItem("Classic", null, classicSelected))
                    {
                        ImGui.SetThemePreset(.Classic);
                    }
                    ImGui.EndMenu();
                }
                if (ImGui.BeginMenu("Help"))
                {
                    if (ImGui.MenuItem("Welcome")) { }
                    if (ImGui.MenuItem("Metrics")) { }
                    if (ImGui.MenuItem("About")) { }
                    ImGui.EndMenu();
                }

                var drawList = ImGui.GetWindowDrawList();
                if (ShowFrameTime)
                {
                    uint32 primaryTextColor = ImGui.ColorConvertFloat4ToU32(ImGui.GetStyle().Colors[(int)ImGui.Col.Text]);
                    uint32 secondaryTextColor = ImGui.ColorConvertFloat4ToU32(ImGui.SecondaryTextColor);
                    String realFrameTime = scope String()..AppendF("{0:G3}", frameData.AverageFrameTime * 1000.0f);
                    String totalFrameTime = scope String()..AppendF("/  {0:G4}", frameData.DeltaTime * 1000.0f);

                    drawList.AddText(.(ImGui.GetCursorPosX(), 5.0f), primaryTextColor, "|    Frametime (ms): ");
                    var textSize = ImGui.CalcTextSize("|    Frametime (ms): ");
                    drawList.AddText(.(ImGui.GetCursorPosX() + (f32)textSize.x, 5.0f), secondaryTextColor, realFrameTime.CStr());
                    drawList.AddText(.(ImGui.GetCursorPosX() + (f32)textSize.x + 42.0f, 5.0f), secondaryTextColor, totalFrameTime.CStr());
                }

                ImGui.EndMainMenuBar();
            }
        }

        private void DrawDockspace(App app, Gui gui)
        {
            //Dockspace flags
            dockspaceFlags = ImGui.DockNodeFlags.None;

            //Parent window flags
            ImGui.WindowFlags windowFlags = .NoDocking | .NoTitleBar | .NoCollapse | .NoResize | .NoMove | .NoBringToFrontOnFocus | .NoNavFocus | .NoBackground;
            var viewport = ImGui.GetMainViewport();

            //Set dockspace size and params
            ImGui.SetNextWindowPos(viewport.WorkPos);
            var dockspaceSize = viewport.Size;
            ImGui.SetNextWindowSize(dockspaceSize);
            ImGui.SetNextWindowViewport(viewport.ID);

            ImGui.PushStyleVar(ImGui.StyleVar.WindowRounding, 0.0f);
            ImGui.PushStyleVar(ImGui.StyleVar.WindowBorderSize, 0.0f);
            ImGui.PushStyleVar(ImGui.StyleVar.WindowPadding, .(0.0f, 0.0f));
            ImGui.Begin("Dockspace parent window", null, windowFlags);
            ImGui.PopStyleVar(3);

            //Create dockspace
            var io = ImGui.GetIO();
            if ((io.ConfigFlags & .DockingEnable) != 0)
            {
                bool firstDraw = DockspaceId == 0;
                DockspaceId = ImGui.GetID("Editor dockspace");
                if (firstDraw)
                {
                    ImGui.DockBuilderRemoveNode(DockspaceId);
                    ImGui.DockBuilderAddNode(DockspaceId, (ImGui.DockNodeFlags)ImGui.DockNodeFlagsPrivate.DockNodeFlags_DockSpace);
                    ImGui.DockNode* dockspaceNode = ImGui.DockBuilderGetNode(DockspaceId);
                    dockspaceNode.LocalFlags |= (ImGui.DockNodeFlags)(ImGui.DockNodeFlagsPrivate.DockNodeFlags_NoWindowMenuButton | ImGui.DockNodeFlagsPrivate.DockNodeFlags_NoCloseButton); //Disable extra close button on dockspace. Tabs will still have their own.
                    ImGui.DockBuilderFinish(DockspaceId);
                }
                ImGui.DockSpace(DockspaceId, .(0.0f, 0.0f), dockspaceFlags);
            }

            ImGui.End();

            //Set default docking positions on first draw
            if (FirstDraw)
            {
                ImGui.ID dockLeftId = ImGui.DockBuilderSplitNode(DockspaceId, .Left, 0.20f, var outIdLeft, out DockspaceId);
                ImGui.ID dockRightId = ImGui.DockBuilderSplitNode(DockspaceId, .Right, 0.28f, var outIdRight, out DockspaceId);
                ImGui.ID dockRightUp = ImGui.DockBuilderSplitNode(dockRightId, .Up, 0.35f, var outIdRightUp, out dockRightId);
                DockspaceCentralNodeId = ImGui.DockBuilderGetCentralNode(DockspaceId).ID;
                ImGui.ID dockCentralDownSplitId = ImGui.DockBuilderSplitNode(DockspaceCentralNodeId, .Down, 0.20f, var outIdCentralDown, out DockspaceCentralNodeId);

                //Todo: Tie panel titles to these calls so both copies of the strings don't need to be updated every time the code changes
                ImGui.DockBuilderDockWindow("Start page", DockspaceCentralNodeId);
                ImGui.DockBuilderDockWindow("File explorer", dockLeftId);
                ImGui.DockBuilderDockWindow("Dear ImGui Demo", dockLeftId);
                ImGui.DockBuilderDockWindow(StateViewer.ID.Ptr, dockLeftId);
                ImGui.DockBuilderDockWindow("Render settings", dockRightId);
                ImGui.DockBuilderDockWindow("Scriptx viewer", DockspaceCentralNodeId);
                ImGui.DockBuilderDockWindow("Log", dockCentralDownSplitId);
            }
        }

        private MenuItem GetMenu(StringView text)
        {
            for (MenuItem item in MenuItems)
                if (StringView.Equals(item.Text, text, true))
                    return item;

            return null;
        }

        private void GenerateMenus(Gui gui)
        {
            for (GuiPanelBase panel in gui.Panels)
            {
                //No menu entry if it's left blank. The main menu itself also doesn't have an entry
                if (panel.MenuPos == "" || panel == this)
                {
                    panel.Open = true;
                    continue;
                }

                //Split menu path into components
                StringView[] pathSplit = panel.MenuPos.Split!('/');
                StringView menuName = pathSplit[0];

                //Get or create menu
                MenuItem curMenuItem = GetMenu(menuName);
                if (curMenuItem == null)
                {
                    curMenuItem = new MenuItem(menuName);
                    MenuItems.Add(curMenuItem);
                }

                //Iterate through path segmeents to create menu tree
                for (int i = 1; i < pathSplit.Count; i++)
                {
                    StringView nextPart = pathSplit[i];
                    MenuItem nextItem = curMenuItem.GetChild(nextPart);
                    if (nextItem == null)
                    {
                        nextItem = new MenuItem(nextPart);
                        curMenuItem.Items.Add(nextItem);
                    }

                    curMenuItem = nextItem;
                }

                curMenuItem.Panel = panel;
            }
        }
    }

    //Entry in the main menu bar
    public class MenuItem
    {
        public String Text = new .() ~ delete _;
        public List<MenuItem> Items = new .() ~ DeleteContainerAndItems!(_);
        public GuiPanelBase Panel = null;

        public this(StringView text)
        {
            Text.Set(text);
        }

        public void Draw()
        {
            if (Panel != null)
            {
                ImGui.MenuItem(Text, "", &Panel.Open);
                return;
            }

            if (ImGui.BeginMenu(Text))
            {
                for (MenuItem item in Items)
                {
                    item.Draw();
                }
                ImGui.EndMenu();
            }
        }

        public MenuItem GetChild(StringView text)
        {
            for (MenuItem item in Items)
                if (StringView.Equals(item.Text, text, true))
                    return item;

            return null;
        }
    }
}