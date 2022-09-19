using AsmTool.Math;
using AsmTool.Gui;
using AsmTool;
using System;

namespace ImGui
{
    extension ImGui
    {
        public static Vec4<f32> SecondaryTextColor = .(0.32f, 0.67f, 1.0f, 1.00f);//.(0.2f, 0.7f, 1.0f, 1.00f) * 0.92f; //Light blue;
        public static Vec4<f32> TertiaryTextColor = .(0.64f, 0.67f, 0.69f, 1.00f); //Light grey;
        public static Vec4<f32> Red = .(0.784f, 0.094f, 0.035f, 1.0f);
        public static Vec4<f32> Yellow = .(0.784f, 0.682f, 0.035f, 1.0f);

        [Comptime]
        private static void ComptimeChecks()
        {
            //I'm using Mirror vector types on some ImGui extension methods for convenience. These need to match up with ImGui vectors to work
            //This doesn't check that the fields are stored in the same order, but I'm not too worried about that since I think it's unlikely that either codebase will reorder x,y,z,w
            Compiler.Assert(sizeof(Vec4<f32>) == sizeof(ImGui.Vec4));
        }

        //Version of text that takes StringView & doesn't need to be null terminated
        public static void Text(StringView text)
        {
            ImGui.TextEx(text.Ptr, text.EndPtr);
        }

        public static void TextColored(StringView text, Vec4<f32> color)
        {
            ImGui.PushStyleColor(.Text, .(color.x, color.y, color.z, color.w));
            ImGui.Text(text);
            ImGui.PopStyleColor();
        }

        public static bool Begin(StringView name, bool* p_open = null, WindowFlags flags = (WindowFlags)0)
        {
            String nameNullTerminated = scope $"{name}\0"; //Needs to be null terminated to work correctly since its written in C++, which uses null terminated strings
            return Begin(nameNullTerminated.Ptr, p_open, flags);
        }

        public static bool TreeNode(StringView label)
        {
            String str = scope .(label)..Append('\0');
            return ImGui.TreeNode(str.Ptr);
        }

        public static bool TreeNodeEx(StringView label, TreeNodeFlags flags = .None)
        {
            String str = scope .(label)..Append('\0');
            return ImGui.TreeNodeEx(str.Ptr, flags);
        }

        public static bool MenuItem(StringView label, char* shortcut, bool* p_selected, bool enabled = true)
        {
            String str = scope .(label)..Append('\0');
            return ImGui.MenuItem(str.Ptr, shortcut, p_selected, enabled);
        }

        public static bool BeginMenu(StringView label, bool enabled = true)
        {
            String str = scope .(label)..Append('\0');
            return ImGui.BeginMenu(str.Ptr, enabled);
        }

        public static void DockBuilderDockWindow(StringView window_name, ID node_id)
        {
            String str = scope .(window_name)..Append('\0');
            ImGui.DockBuilderDockWindow(str.Ptr, node_id);
        }

        //Draw label and value next to each other with value using secondary color
        public static void LabelAndValue(StringView label, StringView value, Vec4<f32> color)
        {
        	ImGui.Text(label);
        	ImGui.SameLine();
        	ImGui.SetCursorPosX(ImGui.GetCursorPosX() - 4.0f);
        	ImGui.TextColored(value, color);
        }

        //Add mouse-over tooltip to previous ui element. Returns true if the target is being hovered
        public static bool TooltipOnPrevious(StringView description, ImGui.Font* Font = null)
        {
        	var font = Font;
        	if(font == null)
        		font = FontManager.FontDefault.Font;

        	bool hovered = ImGui.IsItemHovered();
            if (hovered)
            {
                ImGui.PushFont(Font);
                ImGui.BeginTooltip();
                ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0f);
                ImGui.TextUnformatted(description.Ptr, description.EndPtr);
                ImGui.PopTextWrapPos();
                ImGui.EndTooltip();
                ImGui.PopFont();
            }
        	return hovered;
        }

        public static bool HelpMarker(StringView tooltip)
        {
            ImGui.TextDisabled("(?)");
            return ImGui.TooltipOnPrevious(tooltip);
        }

        public static bool Selectable(StringView label, bool selected = false, SelectableFlags flags = (SelectableFlags)0, Vec2 size = Vec2.Zero)
        {
            String labelNullTerminated = scope .(label)..Append('\0');
            return Selectable(labelNullTerminated.Ptr, selected, flags, size);
        }

        struct InputTextCallback_UserData
        {
            public String Buffer;
            public ImGui.InputTextCallback ChainCallback;
            public void* ChainCallbackUserData;
        }

        //Adds extra logic so we can use beef strings with ImGui.InputText
        private static int InputTextCallback(ImGui.InputTextCallbackData* data)
        {
            InputTextCallback_UserData* userData = (InputTextCallback_UserData*)data.UserData;
            if (data.EventFlag == .CallbackResize)
            {
                //Resize string + update length so the string knows that characters were added/removed
                String buffer = userData.Buffer;
                buffer.Reserve(data.BufSize);
                buffer.[Friend]mLength = data.BufTextLen;
                data.Buf = (char8*)buffer.Ptr;
            }
            if (userData.ChainCallback != null)
            {
                data.UserData = userData.ChainCallbackUserData;
                return userData.ChainCallback(data);
            }

            return 0;
        }

        public static bool InputText(StringView label, String buffer, ImGui.InputTextFlags flags = .None, ImGui.InputTextCallback callback = null, void* userData = null)
        {
            String labelNullTerminated = scope .(label)..Append('\0');

            ImGui.InputTextFlags flagsFinal = flags | .CallbackResize;
            ImGui.InputTextCallback_UserData cbUserData = .();
            cbUserData.Buffer = buffer;
            cbUserData.ChainCallback = callback;
            cbUserData.ChainCallbackUserData = userData;
            buffer.EnsureNullTerminator();
            return ImGui.InputText(labelNullTerminated.Ptr, buffer.CStr(), (u64)buffer.Length + 1, flagsFinal, => InputTextCallback, &cbUserData);
        }

        public static void SetClipboardText(StringView str)
        {
            String strNullTerminated = scope .(str, .NullTerminate);
            ImGui.SetClipboardText(strNullTerminated.Ptr);
        }

        public static bool Button(StringView label, ImGui.Vec2 size = .Zero)
        {
            String strNullTerminated = scope .(label, .NullTerminate);
            return ImGui.Button(strNullTerminated.Ptr, size);
        }

        public static bool ToggleButton(StringView label, bool* value, ImGui.Vec2 size = .Zero)
        {
            ImGui.PushStyleVar(.FrameBorderSize, *value ? 1.0f : 0.0f);
            ImGui.PushStyleColor(.Button, *value ? ImGui.GetColorU32(.ButtonHovered) : ImGui.GetColorU32(.WindowBg));
            bool buttonClicked = ImGui.Button(label, size);
            ImGui.PopStyleColor();
            ImGui.PopStyleVar();
            if (buttonClicked)
                *value = !(*value);

            return buttonClicked;
        }

        public enum ThemePreset
        {
            DarkBlue,
            Orange,
            Dark,
            Light,
            Classic
        }

        public static ThemePreset _currentTheme = .DarkBlue;
        public static ThemePreset CurrentTheme()
        {
            return _currentTheme;
        }

        public static void SetThemePreset(ThemePreset theme)
        {
            _currentTheme = theme;
            switch (theme)
            {
                case .DarkBlue:
                    ImGui.StyleColorsDarkBlue();
                case .Orange:
                    ImGui.StyleColorsOrange();
                case .Dark:
                    ImGui.StyleColorsDark();
                    SecondaryTextColor = ImGui.GetStyle().Colors[(int)ImGui.Col.Text];
                    SecondaryTextColor *= 1.1f;
                case .Light:
                    ImGui.StyleColorsLight();
                    SecondaryTextColor = .(0.04f, 0.04f, 0.01f, 1.00f);
                case .Classic:
                    ImGui.StyleColorsClassic();
                    SecondaryTextColor = .(0.10f, 0.10f, 0.07f, 1.00f);
            }
        }

        public static void StyleColorsDarkBlue()
        {
            ImGui.Style* style = ImGui.GetStyle();
            ImGui.StyleColorsDark();
            SecondaryTextColor = .(0.32f, 0.67f, 1.0f, 1.00f);
            style.Colors[(int)ImGui.Col.Text] = .(0.96f, 0.96f, 0.99f, 1.00f);
            style.Colors[(int)ImGui.Col.TextDisabled] = .(0.50f, 0.50f, 0.50f, 1.00f);
            style.Colors[(int)ImGui.Col.WindowBg] = .(0.1f, 0.1f, 0.1f, 1.0f);
            style.Colors[(int)ImGui.Col.ChildBg] = .(0.1f, 0.1f, 0.1f, 1.0f);
            style.Colors[(int)ImGui.Col.PopupBg] = .(0.04f, 0.04f, 0.05f, 1.00f);
            style.Colors[(int)ImGui.Col.Border] = .(0.216f, 0.216f, 0.216f, 1.0f);
            style.Colors[(int)ImGui.Col.BorderShadow] = .(0.00f, 0.00f, 0.00f, 0.00f);
            style.Colors[(int)ImGui.Col.FrameBg] = .(0.161f, 0.161f, 0.176f, 1.00f);
            style.Colors[(int)ImGui.Col.FrameBgHovered] = .(0.27f, 0.27f, 0.27f, 1.00f);
            style.Colors[(int)ImGui.Col.FrameBgActive] = .(0.255f, 0.255f, 0.275f, 1.00f);
            style.Colors[(int)ImGui.Col.TitleBg] = .(0.18f, 0.18f, 0.18f, 1.0f);
            style.Colors[(int)ImGui.Col.TitleBgActive] = .(0.18f, 0.18f, 0.18f, 1.0f);
            style.Colors[(int)ImGui.Col.TitleBgCollapsed] = .(0.18f, 0.18f, 0.18f, 1.0f);
            style.Colors[(int)ImGui.Col.MenuBarBg] = .(0.18f, 0.18f, 0.18f, 1.0f);
            style.Colors[(int)ImGui.Col.ScrollbarBg] = .(0.074f, 0.074f, 0.074f, 1.0f);
            style.Colors[(int)ImGui.Col.ScrollbarGrab] = .(0.31f, 0.31f, 0.32f, 1.00f);
            style.Colors[(int)ImGui.Col.ScrollbarGrabHovered] = .(0.41f, 0.41f, 0.42f, 1.00f);
            style.Colors[(int)ImGui.Col.ScrollbarGrabActive] = .(0.51f, 0.51f, 0.53f, 1.00f);
            style.Colors[(int)ImGui.Col.CheckMark] = .(0.44f, 0.44f, 0.47f, 1.00f);
            style.Colors[(int)ImGui.Col.SliderGrab] = .(0.44f, 0.44f, 0.47f, 1.00f);
            style.Colors[(int)ImGui.Col.SliderGrabActive] = .(0.59f, 0.59f, 0.61f, 1.00f);
            style.Colors[(int)ImGui.Col.Button] = .(0.20f, 0.20f, 0.22f, 1.00f);
            style.Colors[(int)ImGui.Col.ButtonHovered] = .(0.44f, 0.44f, 0.47f, 1.00f);
            style.Colors[(int)ImGui.Col.ButtonActive] = .(0.59f, 0.59f, 0.61f, 1.00f);
            style.Colors[(int)ImGui.Col.Header] = .(0.20f, 0.20f, 0.22f, 1.00f);
            style.Colors[(int)ImGui.Col.HeaderHovered] = .(0.44f, 0.44f, 0.47f, 1.00f);
            style.Colors[(int)ImGui.Col.HeaderActive] = .(0.59f, 0.59f, 0.61f, 1.00f);
            style.Colors[(int)ImGui.Col.Separator] = .(1.00f, 1.00f, 1.00f, 0.20f);
            style.Colors[(int)ImGui.Col.SeparatorHovered] = .(0.44f, 0.44f, 0.47f, 0.39f);
            style.Colors[(int)ImGui.Col.SeparatorActive] = .(0.44f, 0.44f, 0.47f, 0.59f);
            style.Colors[(int)ImGui.Col.ResizeGrip] = .(0.26f, 0.59f, 0.98f, 0.00f);
            style.Colors[(int)ImGui.Col.ResizeGripHovered] = .(0.26f, 0.59f, 0.98f, 0.00f);
            style.Colors[(int)ImGui.Col.ResizeGripActive] = .(0.26f, 0.59f, 0.98f, 0.00f);
            style.Colors[(int)ImGui.Col.Tab] = .(0.18f, 0.18f, 0.18f, 1.00f);
            style.Colors[(int)ImGui.Col.TabHovered] = .(0.00f, 0.48f, 0.80f, 1.0f);
            style.Colors[(int)ImGui.Col.TabActive] = .(0.00f, 0.48f, 0.80f, 1.0f);
            style.Colors[(int)ImGui.Col.TabUnfocused] = .(0.18f, 0.18f, 0.18f, 1.00f);
            style.Colors[(int)ImGui.Col.TabUnfocusedActive] = .(0.00f, 0.48f, 0.80f, 1.0f);
            style.Colors[(int)ImGui.Col.DockingPreview] = .(0.00f, 0.48f, 0.80f, 0.776f);
            style.Colors[(int)ImGui.Col.DockingEmptyBg] = .(0.114f, 0.114f, 0.125f, 1.0f);
            style.Colors[(int)ImGui.Col.PlotLines] = .(0.96f, 0.96f, 0.99f, 1.00f);
            style.Colors[(int)ImGui.Col.PlotLinesHovered] = .(0.12f, 1.00f, 0.12f, 1.00f);
            style.Colors[(int)ImGui.Col.PlotHistogram] = .(0.23f, 0.51f, 0.86f, 1.00f);
            style.Colors[(int)ImGui.Col.PlotHistogramHovered] = .(0.12f, 1.00f, 0.12f, 1.00f);
            style.Colors[(int)ImGui.Col.TextSelectedBg] = .(0.26f, 0.59f, 0.98f, 0.35f);
            style.Colors[(int)ImGui.Col.DragDropTarget] = .(0.26f, 0.59f, 0.98f, 0.00f);
            style.Colors[(int)ImGui.Col.NavHighlight] = .(0.26f, 0.59f, 0.98f, 1.00f);
            style.Colors[(int)ImGui.Col.NavWindowingHighlight] = .(1.00f, 1.00f, 1.00f, 0.70f);
            style.Colors[(int)ImGui.Col.NavWindowingDimBg] = .(0.80f, 0.80f, 0.80f, 0.20f);
            style.Colors[(int)ImGui.Col.ModalWindowDimBg] = .(0.80f, 0.80f, 0.80f, 0.35f);
            style.Colors[(int)ImGui.Col.TableRowBgAlt] = .(0.12f, 0.12f, 0.14f, 1.00f);
        }

        public static void StyleColorsOrange()
        {
            ImGui.Style* style = ImGui.GetStyle();
            ImGui.StyleColorsDark();
            SecondaryTextColor = .(0.773f, 0.463f, 0.021f, 1.000f);
            style.Colors[(int)ImGui.Col.Text] = .(0.96f, 0.96f, 0.99f, 1.00f);
            style.Colors[(int)ImGui.Col.TextDisabled] = .(0.50f, 0.50f, 0.50f, 1.00f);
            style.Colors[(int)ImGui.Col.WindowBg] = .(0.114f, 0.114f, 0.125f, 1.0f);
            style.Colors[(int)ImGui.Col.ChildBg] = .(0.106f, 0.106f, 0.118f, 1.0f);
            style.Colors[(int)ImGui.Col.PopupBg] = .(0.06f, 0.06f, 0.07f, 1.00f);
            style.Colors[(int)ImGui.Col.Border] = .(0.216f, 0.216f, 0.216f, 1.0f);
            style.Colors[(int)ImGui.Col.BorderShadow] = .(0.00f, 0.00f, 0.00f, 0.00f);
            style.Colors[(int)ImGui.Col.FrameBg] = .(0.161f, 0.161f, 0.176f, 1.00f);
            style.Colors[(int)ImGui.Col.FrameBgHovered] = .(0.216f, 0.216f, 0.235f, 1.00f);
            style.Colors[(int)ImGui.Col.FrameBgActive] = .(0.255f, 0.255f, 0.275f, 1.00f);
            style.Colors[(int)ImGui.Col.TitleBg] = .(0.157f, 0.157f, 0.157f, 1.0f);
            style.Colors[(int)ImGui.Col.TitleBgActive] = .(0.216f, 0.216f, 0.216f, 1.0f);
            style.Colors[(int)ImGui.Col.TitleBgCollapsed] = .(0.157f, 0.157f, 0.157f, 1.0f);
            style.Colors[(int)ImGui.Col.MenuBarBg] = .(0.157f, 0.157f, 0.157f, 1.0f);
            style.Colors[(int)ImGui.Col.ScrollbarBg] = .(0.074f, 0.074f, 0.074f, 1.0f);
            style.Colors[(int)ImGui.Col.ScrollbarGrab] = .(0.31f, 0.31f, 0.32f, 1.00f);
            style.Colors[(int)ImGui.Col.ScrollbarGrabHovered] = .(0.41f, 0.41f, 0.42f, 1.00f);
            style.Colors[(int)ImGui.Col.ScrollbarGrabActive] = .(0.51f, 0.51f, 0.53f, 1.00f);
            style.Colors[(int)ImGui.Col.CheckMark] = .(0.44f, 0.44f, 0.47f, 1.00f);
            style.Colors[(int)ImGui.Col.SliderGrab] = .(0.44f, 0.44f, 0.47f, 1.00f);
            style.Colors[(int)ImGui.Col.SliderGrabActive] = .(0.59f, 0.59f, 0.61f, 1.00f);
            style.Colors[(int)ImGui.Col.Button] = .(0.20f, 0.20f, 0.22f, 1.00f);
            style.Colors[(int)ImGui.Col.ButtonHovered] = .(0.44f, 0.44f, 0.47f, 1.00f);
            style.Colors[(int)ImGui.Col.ButtonActive] = .(0.59f, 0.59f, 0.61f, 1.00f);
            style.Colors[(int)ImGui.Col.Header] = .(0.20f, 0.20f, 0.22f, 1.00f);
            style.Colors[(int)ImGui.Col.HeaderHovered] = .(0.44f, 0.44f, 0.47f, 1.00f);
            style.Colors[(int)ImGui.Col.HeaderActive] = .(0.59f, 0.59f, 0.61f, 1.00f);
            style.Colors[(int)ImGui.Col.Separator] = .(1.00f, 1.00f, 1.00f, 0.20f);
            style.Colors[(int)ImGui.Col.SeparatorHovered] = .(0.44f, 0.44f, 0.47f, 0.39f);
            style.Colors[(int)ImGui.Col.SeparatorActive] = .(0.44f, 0.44f, 0.47f, 0.59f);
            style.Colors[(int)ImGui.Col.ResizeGrip] = .(0.773f, 0.463f, 0.021f, 1.000f);
            style.Colors[(int)ImGui.Col.ResizeGripHovered] = .(0.773f, 0.463f, 0.021f, 1.000f);
            style.Colors[(int)ImGui.Col.ResizeGripActive] = .(0.773f, 0.463f, 0.021f, 1.000f);
            style.Colors[(int)ImGui.Col.Tab] = .(0.21f, 0.21f, 0.24f, 1.00f);
            style.Colors[(int)ImGui.Col.TabHovered] = .(0.773f, 0.463f, 0.021f, 1.000f);
            style.Colors[(int)ImGui.Col.TabActive] = .(0.773f, 0.463f, 0.021f, 1.000f);
            style.Colors[(int)ImGui.Col.TabUnfocused] = .(0.21f, 0.21f, 0.24f, 1.00f);
            style.Colors[(int)ImGui.Col.TabUnfocusedActive] = .(0.773f, 0.463f, 0.021f, 1.000f);
            style.Colors[(int)ImGui.Col.DockingPreview] = .(0.773f, 0.463f, 0.021f, 1.000f);
            style.Colors[(int)ImGui.Col.DockingEmptyBg] = .(0.114f, 0.114f, 0.125f, 1.0f);
            style.Colors[(int)ImGui.Col.PlotLines] = .(0.96f, 0.96f, 0.99f, 1.00f);
            style.Colors[(int)ImGui.Col.PlotLinesHovered] = .(0.12f, 1.00f, 0.12f, 1.00f);
            style.Colors[(int)ImGui.Col.PlotHistogram] = .(0.773f, 0.463f, 0.021f, 1.000f);
            style.Colors[(int)ImGui.Col.PlotHistogramHovered] = .(0.793f, 0.493f, 0.05f, 1.000f);
            style.Colors[(int)ImGui.Col.TextSelectedBg] = .(0.773f, 0.463f, 0.021f, 1.000f);
            style.Colors[(int)ImGui.Col.DragDropTarget] = .(0.773f, 0.463f, 0.021f, 1.000f);
            style.Colors[(int)ImGui.Col.NavHighlight] = .(0.773f, 0.463f, 0.021f, 1.000f);
            style.Colors[(int)ImGui.Col.NavWindowingHighlight] = .(1.00f, 1.00f, 1.00f, 0.70f);
            style.Colors[(int)ImGui.Col.NavWindowingDimBg] = .(0.80f, 0.80f, 0.80f, 0.20f);
            style.Colors[(int)ImGui.Col.ModalWindowDimBg] = .(0.80f, 0.80f, 0.80f, 0.35f);
            style.Colors[(int)ImGui.Col.TableRowBgAlt] = .(0.12f, 0.12f, 0.14f, 1.00f);
        }

        public struct DisposableImGuiFont : IDisposable
        {
            ImGui.Font* _font = null;
            public this(ImGui.Font* font)
            {
                _font = font;
                ImGui.PushFont(_font);
            }

            public void Dispose()
            {
                ImGui.PopFont();
            }
        }

        public static DisposableImGuiFont Font(FontManager.ImGuiFont font)
        {
            return .(font.Font);
        }

        public static mixin ScopedFont(FontManager.ImGuiFont font)
        {
            DisposableImGuiFont disposable = .(font.Font);
            defer disposable.Dispose();
        }

        public struct DisposableStyleColor : IDisposable
        {
            ImGui.Col _idx;
            ImGui.Vec4 _color;

            public this(Col idx, Vec4 color)
            {
                _idx = idx;
                _color = color;
                ImGui.PushStyleColor(idx, color);
            }

            public void Dispose()
            {
                ImGui.PopStyleColor();
            }
        }

        public static mixin ScopedStyleColor(ImGui.Col idx, Vec4 color)
        {
            DisposableStyleColor styleColor = .(idx, color);
            defer styleColor.Dispose();
        }

        extension Vec4
        {
            //Conversion from Mirror.Math.Vec4<f32> to ImGui.Vec4
            public static operator ImGui.Vec4(Vec4<f32> value)
            {
                return .(value.x, value.y, value.z, value.w);
            }

            public static operator Vec4<f32>(ImGui.Vec4 value)
            {
                return .(value.x, value.y, value.z, value.w);
            }
        }
    }
}