using System.Collections;
using RfgTools.Formats;
using AsmTool.App;
using System.IO;
using AsmTool;
using System;
using ImGui;

namespace AsmTool.Gui.Documents
{
    public class AsmEditorDocument : GuiDocumentBase
    {
        append String AsmFilePath; //Path of the asm_pc file
        append String AsmFilename; //The files name
        append String AsmFolderPath; //Path of the folder containing the asm_pc file
        append AsmFileV5 AsmFile;
        private AsmFileV5.Container _selectedContainer = null;
        private AsmFileV5.Primitive _selectedPrimitive = null;
        private List<String> _asmFolderFilesList = new .() ~ DeleteContainerAndItems!(_); //List of other files in the asm_pc files directory

        //Track if name editors are enabled. Requires user to click the edit button first so they don't accidentally change them
        private bool _containerNameEditEnabled = false;
        private String _containerNameEditBuffer = new .() ~delete _;
        private bool _primitiveNameEditEnabled = false;
        private String _primitiveNameEditBuffer = new .() ~delete _;

        //Search bar strings
        private String _containerSearchTerm = new .() ~delete _;
        private bool _containerSearchCaseSensitive = false;
        private bool _containerSearchPrimitives = false; //If true container search also checks if any primitive names match the search
        private append List<AsmFileV5.Container> _filteredContainers; //Filtered list of containers based on search term
        private bool _containerSearchTermChanged = true;

        private String _primitiveSearchTerm = new .() ~delete _;
        private bool _primitiveSearchCaseSensitive = false;
        private append List<AsmFileV5.Primitive> _filteredPrimitives; //Filtered list of primitives based on search term
        private bool _primitiveSearchTermChanged = true;

        ///Heights of the container and primitive tables. Calculated each frame in .Update()
        private f32 _tableHeight = 0.0f;

        public this(StringView asmFilePath)
        {
            AsmFilePath.Set(asmFilePath);
            Path.GetFileName(asmFilePath, AsmFilename);
            Path.GetDirectoryPath(asmFilePath, AsmFolderPath);
            HasMenuBar = false;
            NoWindowPadding = false;
            UnsavedChanges = false;

            //Load asm_pc file
            FileStream stream = scope .()..Open(AsmFilePath, .Read, .Read);
            AsmFile.Read(stream, AsmFilename);

            //Get a list of other files in the asm_pc files folder
            for (var file in Directory.EnumerateFiles(AsmFolderPath))
            {
                String filename = file.GetFileName(.. scope .());
                if (file.GetFileName(.. scope .()) != AsmFilename)
                {
                    _asmFolderFilesList.Add(new .(filename));
                }
            }
        }

        public override void Update(App app, Gui gui)
        {
            //Define columns: Container list, primitive list
            ImGui.Columns(2);
            if (FirstDraw)
            {
                f32 windowWidth = ImGui.GetWindowWidth();
                ImGui.SetColumnWidth(0, (windowWidth - 5.0f) / 2.0f);
                ImGui.SetColumnWidth(1, (windowWidth - 5.0f) / 2.0f);
            }
            _tableHeight = ImGui.GetWindowHeight() * 0.5f;

            //Column headers
            using (ImGui.Font(FontManager.FontL))
            {
                ImGui.Text(scope String(Icons.ICON_FA_DATABASE)..AppendF(" Containers", AsmFilename));
                ImGui.NextColumn();
                ImGui.Text(scope String(Icons.ICON_FA_BOXES)..AppendF(" Primitives", AsmFilename));
            }
            ImGui.Separator();

            //Set custom highlight colors for the tables
            ImGui.Vec4 selectedColor = .(0.157f, 0.350f, 0.588f, 1.0f);
            ImGui.Vec4 highlightColor = .(selectedColor.x * 1.1f, selectedColor.y * 1.1f, selectedColor.z * 1.1f, 1.0f);
            ImGui.ScopedStyleColor!(ImGui.Col.Header, selectedColor); //TODO: Bug requires explicitly specifying ImGui.Col.Header instead of doing .Col. Change once the bug has been fixed.
            ImGui.ScopedStyleColor!(ImGui.Col.HeaderHovered, highlightColor);
            ImGui.ScopedStyleColor!(ImGui.Col.HeaderActive, highlightColor);

            ImGui.NextColumn();
            DrawContainerTable(app, gui);
            DrawContainerEditor(app, gui);

            ImGui.NextColumn();
            DrawPrimitiveTable(app, gui);
            DrawPrimitiveEditor(app, gui);

            ImGui.Columns(1);
        }

        public override void Save(App app, Gui gui)
        {
            FileStream stream = scope .()..Open(AsmFilePath, .Write, .Read);
            AsmFile.Write(stream);
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

        private bool FileInAsmFolder(StringView searchFilename)
        {
            for (String file in _asmFolderFilesList)
            {
                if (StringView.Equals(file, searchFilename, true))
                {
                    return true;
                }
            }

            return false;
        }

#region ContainerEditor
        public void DrawContainerTable(App app, Gui gui)
        {
            UpdateContainerSearchFilter();
            ImGui.SetNextItemWidth(400.0f);
            _containerSearchTermChanged = ImGui.InputText("Search##ContainerSearch", _containerSearchTerm);
            ImGui.SameLine();
            _containerSearchTermChanged |= ImGui.Checkbox("Case sensitive", &_containerSearchCaseSensitive);
            ImGui.SameLine();
            _containerSearchTermChanged |= ImGui.Checkbox("Recursive", &_containerSearchPrimitives);
            ImGui.TooltipOnPrevious("Check if any primitives names contain the search term");
            if (ImGui.BeginTable("Containers", 6, .ScrollY | .RowBg | .BordersOuter | .BordersV | .Resizable | .Reorderable | .Hideable | .SizingStretchProp, .(0.0f, _tableHeight)))
            {
#if DEBUG
                bool hideAdvancedColumnsByDefault = true;
#else
                bool hideAdvancedColumnsByDefault = true;
#endif
                ImGui.TableSetupScrollFreeze(0, 1); //Make first column always visible
                ImGui.TableSetupColumn("Name", .None);
                ImGui.TableSetupColumn("Type", .None);
                ImGui.TableSetupColumn("Flags", .None);
                ImGui.TableSetupColumn("# Primitives", hideAdvancedColumnsByDefault ? .DefaultHide : .None);
                ImGui.TableSetupColumn("Data offset", hideAdvancedColumnsByDefault ? .DefaultHide : .None);
                ImGui.TableSetupColumn("Compressed size", hideAdvancedColumnsByDefault ? .DefaultHide : .None);
                ImGui.TableHeadersRow();

                //Use list clipper to only render a subset of the items. Performance on large asms like terr01_l0.asm_pc is terrible if we render every single line
                ImGui.ListClipper clipper = .();
                clipper.Begin((i32)_filteredContainers.Count);
                while (clipper.Step())
                {
                    for (i32 row = clipper.DisplayStart; row < clipper.DisplayEnd; row++)
                    {
                        AsmFileV5.Container container = _filteredContainers[row];
                        bool selected = (container == _selectedContainer);
                        String containerNameWithExt = scope $"{container.Name}.str2_pc";

                        //TODO: Calculate this once ahead of time instead of every frame
                        //TODO: Consider making all name strings in this document and those of RfgTools.Formats.AsmFileV5.Container lowercase to avoid needing to explicitly do caseless comparisons.
                        //      Have had some many nanoforge bugs from inconsistent casing between an asm_pc and vpp_pc file

                        //Check if container has a corresponding str2_pc file.
                        bool inAsmFolder = FileInAsmFolder(containerNameWithExt);

                        //See if the container has the flags we'd expect of a virtual container (container that doesn't have it's own str2_pc file).
                        //Still don't know if there's a flag that identifies this or if it has to be brute forced.
                        bool virtualFlag = ((u16)container.Flags & 512) != 0;
                        bool passive = ((u16)container.Flags & 256) != 0;
                        bool real = ((u16)container.Flags & 128) != 0;

                        //Change text color in certain cases
                        /*if (!inAsmFolder)
                        {
                            if (virtualFlag && passive)
                                ImGui.PushStyleColor(.Text, .(1.0f, 0.8f, 0.0f, 1.0f)); //Indicate when container doesn't have a matching str2_pc but has flags that indicate it's files are in this vpp_pc
                            else if (virtualFlag)
                                ImGui.PushStyleColor(.Text, .(1.0f, 0.4f, 0.0f, 1.0f)); //File is in the precache vpp_pc
                            else
                                ImGui.PushStyleColor(.Text, .(0.8f, 0.0f, 0.0f, 1.0f)); //Files that don't have their own vpp_pc should have the passive flag
                        }*/

                        //Name
                        ImGui.TableNextRow();
                        ImGui.TableNextColumn();

                        if (ImGui.Selectable(container.Name, selected, .SpanAllColumns)) //, .(0.0f, ImGui.TableGetHeaderRowHeight())))//, .(0, ImGui.GetTextLineHeight() * 2 + 2 * ImGui.GetStyle().FramePadding.y)))
                        {
                            if (container == _selectedContainer)
                            {
                                //TODO: Make SetX() functions that handle this, or put it in the properties (prefer the former since it's more obvious logic to follow)
            					_selectedContainer = null; //Clicking the already selected container deselects it
                                _selectedPrimitive = null;
                                _containerNameEditEnabled = false;
                                _primitiveNameEditEnabled = false;
                                _containerNameEditBuffer.Clear();
                                _primitiveNameEditBuffer.Clear();
                            }
                            else
                            {
            					_selectedContainer = container;
                                _containerNameEditEnabled = false;
                                _containerNameEditBuffer.Clear();
                                if (_selectedContainer.Primitives.Count > 0)
                                {
                                    _selectedPrimitive = _selectedContainer.Primitives[0];
                                    _primitiveNameEditEnabled = false;
                                    _primitiveNameEditBuffer.Clear();
                                }
            				}
                            //Reset primitive search bar
                            _primitiveSearchTermChanged = true;
                            _primitiveSearchTerm.Set("");
                        }
                        /*if (!inAsmFolder || virtualFlag)
                        {
                            ImGui.PopStyleColor();
                        }*/

                        //Right click context menu
                        if (ImGui.BeginPopupContextItem())
                        {
                            if (ImGui.Selectable("Copy name to clipboard"))
                            {
                                ImGui.SetClipboardText(container.Name);
                            }

                            ImGui.EndPopup();
                        }
                        if (container.Primitives.Count == 0)
                        {
                            ImGui.SameLine();
                            ImGui.TextColored("(Empty)", ImGui.SecondaryTextColor);
                            //ImGui.TextDisabled("(Empty)");
                        }
                        if (virtualFlag && passive)
                        {
                            ImGui.SameLine();
                            ImGui.TextColored("(Virtual)", .(1.0f, 0.8f, 0.0f, 1.0f));
                        }
                        else if (virtualFlag)
                        {
                            ImGui.SameLine();
                            ImGui.TextColored("(Remote)", .(1.0f, 0.4f, 0.0f, 1.0f));
                        }

                        //Type
                        ImGui.TableNextColumn();
                        ImGui.Text(container.Type.ToString(.. scope .()));

                        //Flags
                        ImGui.TableNextColumn();
                        ImGui.Text(((u16)container.Flags).ToString(.. scope .()));

                        //# of primitives
                        ImGui.TableNextColumn();
                        ImGui.Text(container.PrimitiveCount.ToString(.. scope .()));

                        //Data offset
                        ImGui.TableNextColumn();
                        ImGui.Text(container.DataOffset.ToString(.. scope .()));

                        //Compressed size
                        ImGui.TableNextColumn();
                        ImGui.Text(container.CompressedSize.ToString(.. scope .()));
                    }
                }

                ImGui.EndTable();
            }
        }

        ///Make filtered list of containers based on search term and options
        private void UpdateContainerSearchFilter()
        {
            if (!_containerSearchTermChanged && !FirstDraw)
            {
                return;
            }
            _filteredContainers.Clear();

            if (_containerSearchTerm == "")
            {
                _containerSearchTermChanged = false;
                _filteredContainers.AddRange(AsmFile.Containers);
                return;
            }

            for (AsmFileV5.Container container in AsmFile.Containers)
            {
                //Search primitive names if that option is selected
                bool primitiveSearchResult = false;
                if (_containerSearchPrimitives)
                {
                    for (AsmFileV5.Primitive primitive in container.Primitives)
                    {
                        if (primitive.Name.Contains(_containerSearchTerm, !_containerSearchCaseSensitive))
                        {
                            primitiveSearchResult = true;
                            break;
                        }
                    }
                }

                if (primitiveSearchResult || container.Name.Contains(_containerSearchTerm, !_containerSearchCaseSensitive))
                {
                    _filteredContainers.Add(container);
                }
            }
            _containerSearchTermChanged = false;
        }

        public void DrawContainerEditor(App app, Gui gui)
        {
            //Container editor
            if (_selectedContainer == null)
            {
                ImGui.Text(scope String(Icons.ICON_FA_EXCLAMATION_TRIANGLE)..Append(" Select a container to edit it"));
                return;
            }

            if (ImGui.BeginChild("ContainerEditor"))
            {
                ImGui.PushItemWidth(400.0f);
                if (_containerNameEditEnabled)
                {
                	if (ImGui.InputText("##ContainerName", _containerNameEditBuffer, .EnterReturnsTrue))
                    {
                        _selectedContainer.Name.Set(_containerNameEditBuffer);
                        _containerNameEditEnabled = false;
                        UnsavedChanges = true;
                    }

                    ImGui.SameLine();
                    if (ImGui.Button("Set"))
                    {
                        _selectedContainer.Name.Set(_containerNameEditBuffer);
                        _containerNameEditEnabled = false;
                        UnsavedChanges = true;
                    }
                    ImGui.SameLine();
                    if (ImGui.Button("Cancel"))
                    {
                        _containerNameEditEnabled = false;
                        _containerNameEditBuffer.Clear();
                    }
                }
                else
                {
                    using (ImGui.Font(FontManager.FontL))
                    {
                        ImGui.Text(_selectedContainer.Name);
                    }

                    ImGui.SameLine();
                    if (ImGui.Button("Edit name"))
                    {
                        _containerNameEditEnabled = true;
                        _containerNameEditBuffer.Set(_selectedContainer.Name);
                    }
                }

                const StringView[38] containerTypes =
                .(
                	"Glass", "EffectsEnv", "EffectsPreload", "EffectsDlc", "MpEffects", "LayerSmall", "LayerLarge", "Audio", "ClothSim", "Decals", "DecalsPreload", "Fsm", "Ui",
                    "Env", "Chunk", "ChunkPreload", "Stitch", "World", "HumanHead", "Human", "Player", "Items", "ItemsPreload", "ItemsMpPreload", "ItemsDlc", "WeaponLarge",
                    "WeaponSmall", "Skybox", "Vehicle", "VoicePersona", "AlwaysLoadedVoicePersona", "Foliage", "UiPeg", "MaterialEffect", "MaterialPreload", "SharedBackpack",
                    "LandmarkLod", "GpsPreload"
                );
                char8* selectedType = _selectedContainer.Type.ToString(.. scope .());
                if (ImGui.BeginCombo("Type", selectedType))
                {
                    int index = 0;
                    for (StringView type in containerTypes)
                    {
                        bool selected = type.Equals(.(selectedType));
                        if (ImGui.Selectable(type, selected))
                        {
                            _selectedContainer.Type = (ContainerType)(index + 1);
                        }
                        index++;
                    }
                    ImGui.EndCombo();
                }

                if (gui.AdvancedModeEnabled)
                {
                    ImGui.InputScalar("Data offset", .U32, &_selectedContainer.DataOffset);
                    ImGui.InputScalar("Compressed size", .U32, &_selectedContainer.CompressedSize);
                }
                ImGui.PopItemWidth();

                if (ImGui.CollapsingHeader("Flags##ContainerFlags", .DefaultOpen))
                {
                    mixin GetBitflag(u16 flags, int index)
                    {
                        (flags & (1 << index)) != 0
                    }

                    //Extract bitflags
                    u16 flags = (u16)_selectedContainer.Flags;
                    bool loaded = GetBitflag!(flags, 0);
                    bool flag1 = GetBitflag!(flags, 1); //Runtime flag. Set right after the container is loaded
                    bool flag2 = GetBitflag!(flags, 2);
                    bool flag3 = GetBitflag!(flags, 3); //Possibly a runtime only flag that means the container + primitives have been read into memory. Not yet confirmed.
                    bool flag4 = GetBitflag!(flags, 4);
                    bool flag5 = GetBitflag!(flags, 5);
                    bool releaseError = GetBitflag!(flags, 6); //Runtime flag. Set if stream2_container::req_release fails
                    bool real = GetBitflag!(flags, 7);
                    bool passive = GetBitflag!(flags, 8); //If it's true the container is placed into the passive stream queue. It's unknown what "passive" means in this case.
                    bool virtualFlag = GetBitflag!(flags, 9);
                    bool flag10 = GetBitflag!(flags, 10);
                    bool flag11 = GetBitflag!(flags, 11);
                    bool flag12 = GetBitflag!(flags, 12);
                    bool flag13 = GetBitflag!(flags, 13);
                    bool flag14 = GetBitflag!(flags, 14);
                    bool flag15 = GetBitflag!(flags, 15);

                    //Flag editors
                    bool changed = false;
                    const f32 indent = 15.0f;
                    ImGui.Indent(indent);
                    if (ImGui.Checkbox("Loaded", &loaded))                      changed = true;
                    if (ImGui.Checkbox("Flag1", &flag1))                        changed = true;
                    if (ImGui.Checkbox("Flag2", &flag2))                        changed = true;
                    if (ImGui.Checkbox("Flag3", &flag3))                        changed = true;
                    if (ImGui.Checkbox("Flag4", &flag4))                        changed = true;
                    if (ImGui.Checkbox("Flag5", &flag5))                        changed = true;

                    if (ImGui.Checkbox("ReleaseError", &releaseError))          changed = true;
                    ImGui.SameLine();
                    ImGui.HelpMarker("Believed to be runtime only.");

                    if (ImGui.Checkbox("Real", &real))
					{
						changed = true;
                        if (real && !gui.AdvancedModeEnabled)
                        {
                            passive = false;
                            virtualFlag = false;
                        }
                    }
                    ImGui.SameLine();
                    ImGui.HelpMarker("Has a str2_pc file with its name. When this is checked Passive and Virtual shouldn't be checked.");

                    bool disablePassiveAndVirtual = !gui.AdvancedModeEnabled && real; //Passive and virtual shouldn't be modified when real is set
                    if (disablePassiveAndVirtual) ImGui.BeginDisabled();
                    if (ImGui.Checkbox("Passive", &passive))                    changed = true;
                    ImGui.SameLine();
                    ImGui.HelpMarker("The primitives of this container are inside this vpp_pc. Only should be checked for virtual containers.");

                    if (ImGui.Checkbox("Virtual", &virtualFlag))                changed = true;
                    ImGui.SameLine();
                    ImGui.HelpMarker("The container doesn't have a str2_pc file. Its primitives are stored in a different str2_pc (commonly ns_base.str2_pc in MP/WC maps) or in the precache vpp_pc.");

                    if (disablePassiveAndVirtual) ImGui.EndDisabled();

                    if (ImGui.Checkbox("Flag10", &flag10))                      changed = true;
                    if (ImGui.Checkbox("Flag11", &flag11))                      changed = true;
                    if (ImGui.Checkbox("Flag12", &flag12))                      changed = true;
                    if (ImGui.Checkbox("Flag13", &flag13))                      changed = true;
                    if (ImGui.Checkbox("Flag14", &flag14))                      changed = true;
                    if (ImGui.Checkbox("Flag15", &flag15))                      changed = true;
                    ImGui.Text(""); //Extra whitespace on the bottom since the last checkbox was getting cut off when the window wasn't maximized
                    ImGui.Unindent(indent);

                    //Recreate merged bitflags
                    if (changed)
                    {
                        u16 newFlags = 0;
                        if (loaded)                     newFlags |= (1 << 0);
                        if (flag1)                      newFlags |= (1 << 1);
                        if (flag2)                      newFlags |= (1 << 2);
                        if (flag3)                      newFlags |= (1 << 3);
                        if (flag4)                      newFlags |= (1 << 4);
                        if (flag5)                      newFlags |= (1 << 5);
                        if (releaseError)               newFlags |= (1 << 6);
                        if (real)                      newFlags |= (1 << 7);
                        if (passive)                    newFlags |= (1 << 8);
                        if (virtualFlag)                      newFlags |= (1 << 9);
                        if (flag10)                     newFlags |= (1 << 10);
                        if (flag11)                     newFlags |= (1 << 11);
                        if (flag12)                     newFlags |= (1 << 12);
                        if (flag13)                     newFlags |= (1 << 13);
                        if (flag14)                     newFlags |= (1 << 14);
                        if (flag15)                     newFlags |= (1 << 15);

                        _selectedContainer.Flags = (ContainerFlags)newFlags;
                        UnsavedChanges = true;
                    }
                }
            }
            ImGui.EndChild();
        }
#endregion ContainerEditor

#region PrimitiveEditor
        public void DrawPrimitiveTable(App app, Gui gui)
        {
            if (_selectedContainer == null)
            {
                ImGui.Text(scope String(Icons.ICON_FA_EXCLAMATION_TRIANGLE)..Append(" Select a primitive to see its contents."));
                return;
            }

            UpdatePrimitiveSearchFilter();
            ImGui.SetNextItemWidth(400.0f);
            _primitiveSearchTermChanged = ImGui.InputText("Search##PrimitiveSearch", _primitiveSearchTerm);
            ImGui.SameLine();
            _primitiveSearchTermChanged |= ImGui.Checkbox("Case sensitive##Prim", &_primitiveSearchCaseSensitive);
            if (ImGui.BeginTable("Primitives", 7, .ScrollY | .RowBg | .BordersOuter | .BordersV | .Resizable | .Reorderable | .Hideable | .SizingStretchProp, .(0.0f, _tableHeight)))
            {
                #if DEBUG
                bool hideAdvancedColumnsByDefault = true;
#else
                bool hideAdvancedColumnsByDefault = true;
#endif

                ImGui.TableSetupScrollFreeze(0, 1); //Make first column always visible
                ImGui.TableSetupColumn("Name", .None);
                ImGui.TableSetupColumn("Type", .None);
                ImGui.TableSetupColumn("Allocator", .None);
                ImGui.TableSetupColumn("Flags", .None);
                ImGui.TableSetupColumn("Header size", hideAdvancedColumnsByDefault ? .DefaultHide : .None);
                ImGui.TableSetupColumn("Data size", hideAdvancedColumnsByDefault ? .DefaultHide : .None);
                ImGui.TableSetupColumn("SplitExtIndex", .DefaultHide);
                ImGui.TableHeadersRow();

                ImGui.ListClipper clipper = .();
                clipper.Begin((i32)_filteredPrimitives.Count);
                while (clipper.Step())
                {
                    for (i32 row = clipper.DisplayStart; row < clipper.DisplayEnd; row++)
                    {
                        AsmFileV5.Primitive primitive = _filteredPrimitives[row];
                        bool selected = (primitive == _selectedPrimitive);

                        //Name
                        ImGui.TableNextRow();
                        ImGui.TableNextColumn();
                        if (ImGui.Selectable(primitive.Name, selected, .SpanAllColumns))
                        {
                            if (primitive == _selectedPrimitive)
                            {
            					_selectedPrimitive = null; //Double clicking clears selection
                            }
                            else
                            {
            					_selectedPrimitive = primitive;
            				}
                            _primitiveNameEditEnabled = false;
                            _primitiveNameEditBuffer.Clear();
                        }
                        //Right click context menu
                        if (ImGui.BeginPopupContextItem())
                        {
                            if (ImGui.Selectable("Copy name to clipboard"))
                            {
                                ImGui.SetClipboardText(primitive.Name);
                            }

                            ImGui.EndPopup();
                        }

                        //Type
                        ImGui.TableNextColumn();
                        ImGui.Text(primitive.Type.ToString(.. scope .()));

                        //Allocator
                        ImGui.TableNextColumn();
                        ImGui.Text(primitive.Allocator.ToString(.. scope .()));

                        //Flags
                        ImGui.TableNextColumn();
                        ImGui.Text(((u8)primitive.Flags).ToString(.. scope .()));

                        //Header size
                        ImGui.TableNextColumn();
                        ImGui.Text(primitive.HeaderSize.ToString(.. scope .()));

                        //Data size
                        ImGui.TableNextColumn();
                        ImGui.Text(primitive.DataSize.ToString(.. scope .()));

                        //SplitExtIndex
                        ImGui.TableNextColumn();
                        ImGui.Text(primitive.SplitExtIndex.ToString(.. scope .()));
                    }
                }

                ImGui.EndTable();
            }
        }

        ///Make filtered list of primitives based on search term and options
        private void UpdatePrimitiveSearchFilter()
        {
            if (!_primitiveSearchTermChanged && !FirstDraw)
                return;

            _filteredPrimitives.Clear();
            if (_selectedContainer == null)
            {
                _primitiveSearchTermChanged = false;
            	return;
            }
            if (_primitiveSearchTerm == "")
            {
                _primitiveSearchTermChanged = false;
                _filteredPrimitives.AddRange(_selectedContainer.Primitives);
                return;
            }
            for (AsmFileV5.Primitive primitive in _selectedContainer.Primitives)
            {
                if (primitive.Name.Contains(_primitiveSearchTerm, !_primitiveSearchCaseSensitive))
                    _filteredPrimitives.Add(primitive);
            }

            _primitiveSearchTermChanged = false;
        }

        public void DrawPrimitiveEditor(App app, Gui gui)
        {
            if (_selectedPrimitive == null)
            {
                if (_selectedContainer != null)
                {
					ImGui.Text(scope String(Icons.ICON_FA_EXCLAMATION_TRIANGLE)..Append(" Select a primitive to edit it"));
				}
                return;
            }

            if (ImGui.BeginChild("PrimitiveEditor"))
            {
                ImGui.PushItemWidth(400.0f);
                if (_primitiveNameEditEnabled)
                {
                	if (ImGui.InputText("##PrimitiveName", _primitiveNameEditBuffer, .EnterReturnsTrue))
                    {
                        _selectedPrimitive.Name.Set(_primitiveNameEditBuffer);
                        _primitiveNameEditEnabled = false;
                        UnsavedChanges = true;
                    }

                    ImGui.SameLine();
                    if (ImGui.Button("Set"))
                    {
                        _selectedPrimitive.Name.Set(_primitiveNameEditBuffer);
                        _primitiveNameEditEnabled = false;
                        UnsavedChanges = true;
                    }
                    ImGui.SameLine();
                    if (ImGui.Button("Cancel"))
                    {
                        _primitiveNameEditEnabled = false;
                        _primitiveNameEditBuffer.Clear();
                    }
                }
                else
                {
                    using (ImGui.Font(FontManager.FontL))
                    {
                        ImGui.ScopedFont!(FontManager.FontL);
                        ImGui.Text(_selectedPrimitive.Name);
                    }

                    ImGui.SameLine();
                    if (ImGui.Button("Edit name"))
                    {
                        _primitiveNameEditEnabled = true;
                        _primitiveNameEditBuffer.Set(_selectedPrimitive.Name);
                    }
                }

                const StringView[22] primitiveTypes =
                .(
                	"Peg", "Chunk", "Zone", "Terrain", "StaticMesh", "CharacterMesh", "FoliageMesh", "Material", "ClothSim", "Vehicle", "VehicleAudio",
                    "Vfx", "Wavebank", "FoleyBank", "MeshMorph", "VoicePersona", "AnimFile", "Vdoc", "LuaScript", "Localization", "TerrainHighLod", "LandmarkLod"
                );
                char8* selectedType = _selectedPrimitive.Type.ToString(.. scope .());
                if (ImGui.BeginCombo("Type", selectedType))
                {
                    int index = 0;
                    for (StringView type in primitiveTypes)
                    {
                        bool selected = type.Equals(.(selectedType));
                        if (ImGui.Selectable(type, selected))
                        {
                           _selectedPrimitive.Type = (PrimitiveType)(index + 1);
                        }
                        index++;
                    }
                    ImGui.EndCombo();
                }

                StringView[30] allocatorTypes =
                .(
                    "World", "ChunkPreload", "EffectPreload", "EffectCutscene", "ItemPreload", "DecalPreload", "ClothSimPreload", "Tod", "MpEffectPreload", "MpItemPreload",
                	"Player", "Human", "LargeWeapon", "SmallWeapon", "Vehicle", "LargeLayer", "SmallLayer", "HumanVoicePersona", "AlwaysLoadedHumanVoicePersona", "Audio",
                	"Interface", "Fsm", "InterfaceStack", "InterfaceSlot", "InterfaceMpPreload", "InterfaceMpSlot", "MaterialEffect", "Permanent", "DlcEffectPreload", "DlcItemPreload"
                );
                char8* selectedAllocatorType = _selectedPrimitive.Allocator.ToString(.. scope .());
                if (ImGui.BeginCombo("Allocator", selectedAllocatorType))
                {
                    int index = 0;
                    for (StringView type in allocatorTypes)
                    {
                        bool selected = type.Equals(.(selectedType));
                        if (ImGui.Selectable(type, selected))
                        {
                            _selectedPrimitive.Allocator = (AllocatorType)(index + 1);
                        }
                        index++;
                    }
                    ImGui.EndCombo();
                }

                if (gui.AdvancedModeEnabled)
                {
                    ImGui.InputScalar("Header size", .S32, &_selectedPrimitive.HeaderSize);
                    ImGui.InputScalar("Data size", .S32, &_selectedPrimitive.DataSize);
                    ImGui.InputScalar("SplitExtIndex", .U8, &_selectedPrimitive.SplitExtIndex);
                }
                ImGui.PopItemWidth();

                if (ImGui.CollapsingHeader("Flags", .DefaultOpen))
                {
                    mixin GetBitflag(u8 flags, int index)
                    {
                        (flags & (1 << index)) != 0
                    }

                    //Extract bitflags
                    u8 flags = (u8)_selectedPrimitive.Flags;
                    bool flag0 = GetBitflag!(flags, 0);
                    bool flag1 = GetBitflag!(flags, 1);
                    bool split = GetBitflag!(flags, 2);
                    bool flag3 = GetBitflag!(flags, 3);
                    bool flag4 = GetBitflag!(flags, 4);
                    bool flag5 = GetBitflag!(flags, 5);
                    bool flag6 = GetBitflag!(flags, 6);
                    bool flag7 = GetBitflag!(flags, 7);

                    //Flag editors
                    bool changed = false;
                    const f32 indent = 15.0f;
                    ImGui.Indent(indent);
                    if (ImGui.Checkbox("Flag0", &flag0))                        changed = true;
                    if (ImGui.Checkbox("Flag1", &flag1))                        changed = true;
                    if (ImGui.Checkbox("Split", &split))                        changed = true;
                    ImGui.SameLine();
                    ImGui.HelpMarker("This primitive is split into two files. E.g. textures are typically a pair of files, a .cpeg_pc file and a .gpeg_pc file.");

                    if (ImGui.Checkbox("Flag3", &flag3))                        changed = true;
                    if (ImGui.Checkbox("Flag4", &flag4))                        changed = true;
                    if (ImGui.Checkbox("Flag5", &flag5))                        changed = true;
                    if (ImGui.Checkbox("Flag6", &flag6))                        changed = true;
                    if (ImGui.Checkbox("Flag7", &flag7))                        changed = true;
                    ImGui.Text(""); //Extra whitespace on the bottom since the last checkbox was getting cut off when the window wasn't maximized
                    ImGui.Unindent(indent);

                    //Recreate merged bitflags
                    if (changed)
                    {
                        u8 newFlags = 0;
                        if (flag0)                      newFlags |= (1 << 0);
                        if (flag1)                      newFlags |= (1 << 1);
                        if (split)                      newFlags |= (1 << 2);
                        if (flag3)                      newFlags |= (1 << 3);
                        if (flag4)                      newFlags |= (1 << 4);
                        if (flag5)                      newFlags |= (1 << 5);
                        if (flag6)                      newFlags |= (1 << 6);
                        if (flag7)                      newFlags |= (1 << 7);

                        _selectedPrimitive.Flags = (PrimitiveFlags)newFlags;
                        UnsavedChanges = true;
                    }
                }
            }
            ImGui.EndChild();
        }
#endregion PrimitiveEditor

        public void Validate()
        {

        }
    }
}