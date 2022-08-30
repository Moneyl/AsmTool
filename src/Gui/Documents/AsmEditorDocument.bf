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
        private List<String> _asmFolderFilesList = new .() ~DeleteContainerAndItems!(_); //List of other files in the asm_pc files directory

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
                ImGui.SetColumnWidth(0, (windowWidth - 5.0f) / 2.0f);//900.0f);
                ImGui.SetColumnWidth(1, (windowWidth - 5.0f) / 2.0f);//900.0f);
            }

            //Set custom highlight colors for the table
            ImGui.Vec4 selectedColor = .(0.157f, 0.350f, 0.588f, 1.0f);
            ImGui.Vec4 highlightColor = .(selectedColor.x * 1.1f, selectedColor.y * 1.1f, selectedColor.z * 1.1f, 1.0f);
            ImGui.PushStyleColor(.Header, selectedColor);
            ImGui.PushStyleColor(.HeaderHovered, highlightColor);
            ImGui.PushStyleColor(.HeaderActive, highlightColor);

            //Column headers
            FontManager.FontL.Push();
            ImGui.Text(scope String(Icons.ICON_FA_DATABASE)..AppendF(" Containers", AsmFilename));
            ImGui.NextColumn();
            ImGui.Text(scope String(Icons.ICON_FA_BOXES)..AppendF(" Primitives", AsmFilename));
            FontManager.FontL.Pop();
            ImGui.Separator();

            //Container list
            ImGui.NextColumn();
            if (ImGui.BeginTable("Containers", 6, .ScrollY | .RowBg | .BordersOuter | .BordersV | .Resizable | .Reorderable | .Hideable | .SizingStretchProp))
            {
                ImGui.TableSetupScrollFreeze(0, 1); //Make first column always visible
                ImGui.TableSetupColumn("Name", .None);
                ImGui.TableSetupColumn("Type", .None);
                ImGui.TableSetupColumn("Flags", .None);
                ImGui.TableSetupColumn("# Primitives", .None);
                ImGui.TableSetupColumn("Data offset", .None);
                ImGui.TableSetupColumn("Compressed size", .None);
                ImGui.TableHeadersRow();

                //Use list clipper to only render a subset of the items. Performance on large asms like terr01_l0.asm_pc is terrible if we render every single line
                ImGui.ListClipper clipper = .();
                clipper.Begin((i32)AsmFile.Containers.Count);
                while (clipper.Step())
                {
                    for (i32 row = clipper.DisplayStart; row < clipper.DisplayEnd; row++)
                    {
                        AsmFileV5.Container container = AsmFile.Containers[row];
                        bool selected = (container == _selectedContainer);
                        String containerNameWithExt = scope $"{container.Name}.str2_pc";

                        //TODO: Calculate this once ahead of time instead of every frame
                        //TODO: Consider making all name strings in this document and those of RfgTools.Formats.AsmFileV5.Container lowercase to avoid needing to explicitly do caseless comparisons.
                        //      Have had some many nanoforge bugs from inconsistent casing between an asm_pc and vpp_pc file

                        //Check if container has a corresponding str2_pc file.
                        bool inAsmFolder = FileInAsmFolder(containerNameWithExt);

                        //See if the container has the flags we'd expect of a virtual container (container that doesn't have it's own str2_pc file).
						//Still don't know if there's a flag that identifies this or if it has to be brute forced.
                        bool hasExpectedVirtualFlags = ((u16)container.Flags & 512) != 0;

                        //Change text color in certain cases
                        if (!inAsmFolder)
                        {
                            if (hasExpectedVirtualFlags)
                                ImGui.PushStyleColor(.Text, .(1.0f, 0.8f, 0.0f, 1.0f)); //Indicate when container doesn't have a matching str2_pc
                            else
                                ImGui.PushStyleColor(.Text, .(0.8f, 0.0f, 0.0f, 1.0f)); //Virtual container but doesn't have the flag that is suspected to indicate when one is virtual
                        }

                        //Name
                        ImGui.TableNextRow();
                        ImGui.TableNextColumn();
                        if (ImGui.Selectable(container.Name, selected, .SpanAllColumns))
                        {
                            if (container == _selectedContainer)
                                _selectedContainer = null; //Clicking the already selected container deselects it
                            else
                                _selectedContainer = container;
                        }

                        if (!inAsmFolder)
                        {
                            ImGui.PopStyleColor();
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

            //Primitive list
            ImGui.NextColumn();
            if (_selectedContainer != null)
            {
                if (ImGui.BeginTable("Primitives", 7, .ScrollY | .RowBg | .BordersOuter | .BordersV | .Resizable | .Reorderable | .Hideable | .SizingStretchProp))
                {
                    ImGui.TableSetupScrollFreeze(0, 1); //Make first column always visible
                    ImGui.TableSetupColumn("Name", .None);
                    ImGui.TableSetupColumn("Type", .None);
                    ImGui.TableSetupColumn("Allocator", .None);
                    ImGui.TableSetupColumn("Flags", .None);
                    ImGui.TableSetupColumn("Header size", .None);
                    ImGui.TableSetupColumn("Data size", .None);
                    ImGui.TableSetupColumn("SplitExtIndex", .None);
                    ImGui.TableHeadersRow();

                    ImGui.ListClipper clipper = .();
                    clipper.Begin((i32)_selectedContainer.Primitives.Count);
                    while (clipper.Step())
                    {
                        for (i32 row = clipper.DisplayStart; row < clipper.DisplayEnd; row++)
                        {
                            AsmFileV5.Primitive primitive = _selectedContainer.Primitives[row];
                            bool selected = (primitive == _selectedPrimitive);

                            //Name
                            ImGui.TableNextRow();
                            ImGui.TableNextColumn();
                            if (ImGui.Selectable(primitive.Name, selected, .SpanAllColumns))
                            {
                                if (primitive == _selectedPrimitive)
                                    _selectedPrimitive = null; //Double clicking clears selection
                                else
                                    _selectedPrimitive = primitive;
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
            else
            {
                ImGui.Text(scope String(Icons.ICON_FA_EXCLAMATION_TRIANGLE)..Append(" Select a container to see its contents."));
            }

            ImGui.PopStyleColor(3);
            ImGui.Columns(1);
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
	}
}