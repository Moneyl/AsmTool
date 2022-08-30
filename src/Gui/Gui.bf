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

		static void ISystem.Build(App app)
		{

		}

		[SystemInit]
		void Init(App app)
		{
            AddPanel("", true, MainMenuBar);
            AddPanel("View/State viewer", true, new StateViewer());

            //Hardcoded to open test file for the moment. Will remove later or give it a keybind
            StringView testAsmPath = @"I:\_AsmToolTesting\interface\In_world_gps_preload.asm_pc";
            OpenDocument(Path.GetFileName(testAsmPath, .. scope .()), testAsmPath, new AsmEditorDocument(testAsmPath));
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