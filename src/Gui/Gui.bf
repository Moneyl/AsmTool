using AsmTool.Gui.Documents;
using System.Collections;
using AsmTool.Gui.Panels;
using System.Threading;
using AsmTool.Math;
using AsmTool.App;
using System.Linq;
using System.IO;
using AsmTool;
using System;
using ImGui;
using AsmTool.Misc;

namespace AsmTool.Gui
{
	[System]
	public class Gui : ISystem
	{
        public List<GuiPanelBase> Panels = new .() ~DeleteContainerAndItems!(_);
        public List<GuiDocumentBase> Documents = new .() ~DeleteContainerAndItems!(_);
        public append Monitor DocumentLock;
        public MainMenuBar MainMenuBar = new MainMenuBar();
        public GuiDocumentBase FocusedDocument = null;
        public bool CloseAppRequested = false;
        //When enabled users are given more freedom to edit things as they please. By default this should be disabled so they don't break their asm_pc and to make editing easier.
        public bool AdvancedModeEnabled = false;

		static void ISystem.Build(App app)
		{

		}

		[SystemInit]
		void Init(App app)
		{
            AddPanel("", true, MainMenuBar);
#if DEBUG
            AddPanel("View/State viewer", false, new StateViewer());

            //Files to auto open in debug builds for dev purposes
            static StringView[?] testAsmPaths =
			.(
                @"C:\I\_AsmToolTesting\wc4\wc4.asm_pc",
                @"C:\I\_AsmToolTesting\mp_crashsite\mp_crashsite.asm_pc",
                @"C:\I\_AsmToolTesting\terr01_l0\terr01_l0.asm_pc",
                @"C:\I\_AsmToolTesting\terr01_l1\terr01_l1.asm_pc",
                @"C:\I\_AsmToolTesting\missions\mission_containers.asm_pc",
                @"C:\I\_AsmToolTesting\interface\In_world_gps_preload.asm_pc",
                @"C:\I\_AsmToolTesting\interface\ui_images.asm_pc",
                @"C:\I\_AsmToolTesting\interface\ui_mp_preload.asm_pc",
                @"C:\I\_AsmToolTesting\interface\vint_doc_containers.asm_pc"
			);
            for (StringView asmPath in testAsmPaths)
            {
                OpenDocument(Path.GetFileName(asmPath, .. scope .()), asmPath, new AsmEditorDocument(asmPath));
            }
#endif

            //Open asm_pc files passed to CLI. Files double clicked in the windows file explorer are also opened this way if file association is set
            BuildConfig config = app.GetResource<BuildConfig>();
            for (String arg in config.Arguments)
            {
                if (!File.Exists(arg))
                    continue;

                String ext = Path.GetExtension(arg, .. scope .());
                if (ext == ".asm_pc")
                {
                    OpenDocument(Path.GetFileName(arg, .. scope .()), arg, new AsmEditorDocument(arg));
                }
                /*else if (ext == ".vint_doc")
                {
                    OpenDocument(Path.GetFileName(arg, .. scope .()), arg, new VintEditorDocument(arg));
                }*/
            }
		}

		[SystemStage(.Update)]
		void Update(App app)
		{
			for (GuiPanelBase panel in Panels)
            {
                if (!panel.Open)
                    continue;

                panel.Update(app, this);
                panel.FirstDraw = false;
            }

            HandleKeybinds(app);

            for (GuiDocumentBase document in Documents.ToList(.. scope .())) //Iterate temporary list to we can delete documents from main list while iterating
            {
                if (document.Open)
                {
                    //Optionally disable window padding for documents that need to flush with the window (map/mesh viewer viewports)
                    if (document.NoWindowPadding)
                        ImGui.PushStyleVar(.WindowPadding, .(0.0f, 0.0f));

                    ImGui.WindowFlags flags = .None;
                    if (document.UnsavedChanges)
                        flags |= .UnsavedDocument;
                    if (document.HasMenuBar)
                        flags |= .MenuBar;

                    //Draw document
                    ImGui.SetNextWindowDockID(MainMenuBar.DockspaceCentralNodeId, .Appearing);
                    ImGui.Begin(document.Title, &document.Open, flags);
                    if (ImGui.IsWindowFocused())
                        FocusedDocument = document;

                    document.Update(app, this);
                    document.FirstDraw = false;
                    ImGui.End();

                    if (document.NoWindowPadding)
                        ImGui.PopStyleVar();

                    //Call OnClose when the user clicks the close button
                    if (!document.Open)
                        document.OnClose(app, this);
                }
                else if (!document.Open && !document.UnsavedChanges && document.CanClose(app, this))
                {
                    //Erase the document if it was closed, has no unsaved changes, and is ready to close (not waiting for worker threads to exit)
                    Documents.Remove(document);
                    if (FocusedDocument == document)
                        FocusedDocument = null;
                    delete document;
                }
            }

            //Draw close confirmation dialogs for documents with unsaved changes
            DrawDocumentCloseConfirmationPopup(app);
		}

        void HandleKeybinds(App app)
        {
            Input input = app.GetResource<Input>();
            if (FocusedDocument != null)
            {
                if (input.KeyDown(.Control) && input.KeyPressed(.S))
                {
                    FocusedDocument.Save(app, this);
                    FocusedDocument.UnsavedChanges = false;
                }
                if (input.KeyPressed(.F5))
                {
                    bool asmDocumentFocused = FocusedDocument.GetType() == typeof(AsmEditorDocument);
                    if (asmDocumentFocused)
                    {
                        AsmEditorDocument asmDoc = (AsmEditorDocument)FocusedDocument;
                        asmDoc.Validate(app, this);
                    }
                }
                if (input.KeyPressed(.F1))
                {
                    bool asmDocumentFocused = FocusedDocument.GetType() == typeof(AsmEditorDocument);
                    if (asmDocumentFocused)
                    {
                        AsmEditorDocument asmDoc = (AsmEditorDocument)FocusedDocument;
                        asmDoc.AutoUpdate(app, this);
                    }
                }
            }
        }

        ///Confirms that the user wants to close documents with unsaved changes
        void DrawDocumentCloseConfirmationPopup(App app)
        {
            int numUnsavedDocs = Documents.Select((doc) => doc).Where((doc) => !doc.Open && doc.UnsavedChanges).Count();
            if (CloseAppRequested && numUnsavedDocs == 0)
            {
                app.Exit = true; //Signal to App it's ok to close the window (any unsaved changes were saved or cancelled)
            }

            if (numUnsavedDocs == 0)
                return;

            if (!ImGui.IsPopupOpen("Save?"))
                ImGui.OpenPopup("Save?");
            if (ImGui.BeginPopupModal("Save?", null, .AlwaysAutoResize))
            {
                ImGui.Text("Save changes to the following file(s)?");
                f32 itemHeight = ImGui.GetTextLineHeightWithSpacing();
                if (ImGui.BeginChildFrame(ImGui.GetID("frame"), .(-f32.Epsilon, 6.25f * itemHeight)))
                {
                    for (GuiDocumentBase doc in Documents)
                        if (!doc.Open && doc.UnsavedChanges)
                            ImGui.Text(doc.Title);

                    ImGui.EndChildFrame();
                }

                ImGui.Vec2 buttonSize = .(ImGui.GetFontSize() * 7.0f, 0.0f);
                if (ImGui.Button("Save", buttonSize))
                {
                    for (GuiDocumentBase doc in Documents)
                    {
                        if (!doc.Open && doc.UnsavedChanges)
                            doc.Save(app, this);

                        doc.UnsavedChanges = false;
                    }
                    //CurrentProject.Save();
                    ImGui.CloseCurrentPopup();
                }

                ImGui.SameLine();
                if (ImGui.Button("Don't save", buttonSize))
                {
                    for (GuiDocumentBase doc in Documents)
                    {
                        if (!doc.Open && doc.UnsavedChanges)
                        {
                            doc.UnsavedChanges = false;
                            doc.ResetOnClose = true;
                        }
                    }

                    ImGui.CloseCurrentPopup();
                }

                ImGui.SameLine();
                if (ImGui.Button("Cancel", buttonSize))
                {
                    for (GuiDocumentBase doc in Documents)
                        if (!doc.Open && doc.UnsavedChanges)
                            doc.Open = true;

                    //Cancel any current operation that checks for unsaved changes when cancelled
                    //showNewProjectWindow_ = false;
                    //showOpenProjectWindow_ = false;
                    //openProjectRequested_ = false;
                    //closeProjectRequested_ = false;
                    //openRecentProjectRequested_ = false;
                    CloseAppRequested = false;
                    ImGui.CloseCurrentPopup();
                }

                ImGui.EndPopup();
            }
        }

        ///Open a new document
        public bool OpenDocument(StringView title, StringView id, GuiDocumentBase newDoc)
        {
            //Make sure only one thread can access Documents at once
            DocumentLock.Enter();
            defer DocumentLock.Exit();

            //Make sure document ID is unique
            for (GuiDocumentBase doc in Documents)
                if (StringView.Equals(doc.UID, id, true))
                    return false;

            newDoc.Title.Set(title);
            newDoc.UID.Set(id);
            Documents.Add(newDoc);
            return true;
        }

        ///Add gui panel and validate its path to make sure its not a duplicate. Takes ownership of panel.
        void AddPanel(StringView menuPos, bool open, GuiPanelBase panel)
        {
            //Make sure there isn't already a panel with the same menuPos
            for (GuiPanelBase existingPanel in Panels)
            {
                if (StringView.Equals(menuPos, existingPanel.MenuPos, true))
                {
                    //Just crash when a duplicate is found. These are set at compile time currently so it'll always happen if theres a duplicate
                    Runtime.FatalError(scope $"Duplicate GuiPanel menu path. Fix this before release. Type = {panel.GetType().ToString(.. scope .())}. Path = '{menuPos}'");
                    delete panel;
                    return;
                }
            }

            panel.MenuPos.Set(menuPos);
            panel.Open = open;
            Panels.Add(panel);
        }
	}
}