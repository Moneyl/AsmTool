using AsmTool.Misc;
using AsmTool.Gui;
using AsmTool.App;
using AsmTool;
using Direct3D;
using System;
using ImGui;
using Win32;

namespace AsmTool.Render.ImGui
{
    public class ImGuiRenderer
    {
        private append ImGuiImplWin32 ImplWin32;
        private append ImGuiImplDX11 ImplDX11;
        private ID3D11DeviceContext* _context = null;
        private ID3D11Device* _device = null;
        private IDXGIFactory* _factory = null;
        private HWND _hwnd = 0;
        private u32 _drawCount = 0;

        public void Shutdown()
        {
            ImplDX11.Shutdown();
            ImplWin32.Shutdown();
            ImGui.DestroyContext();
        }

        public void BeginFrame(App app)
        {
            ImplDX11.NewFrame();
            ImplWin32.NewFrame();
            ImGui.NewFrame();
        }

        public void Render(App app)
        {
            ImGui.Render();
            ImplDX11.RenderDrawData(ImGui.GetDrawData());

            //Clear font texture data after a few frames. Uses a ton of memory.
            //Cleared after 60 frames since that ensures the font atlas was built and sent to the gpu so we can delete the cpu-side copy.
#if !DEBUG  //Don't do it in debug builds because it causes a crash
            if (_drawCount < 60)
            {
                if (_drawCount == 59)
                {
                    var io = ImGui.GetIO();
                    io.Fonts.ClearTexData();
                }

                _drawCount++;
            }
#endif
        }

        public void EndFrame(App app)
        {
            ImGui.EndFrame();
        }

        public bool Init(App app, ID3D11DeviceContext* context, ID3D11Device* device, IDXGIFactory* factory)
        {
            BuildConfig buildConfig = app.GetResource<BuildConfig>();
            Window window = app.GetResource<Window>();

            _device = device;
            _context = context;
            _factory = factory;
            _hwnd = window.Handle;

            if (!ImGui.CHECKVERSION())
                return false;
            if (ImGui.CreateContext() == null)
                return false;
            //ImplWin32.EnableDpiAwareness();

            ImGui.IO* io = ImGui.GetIO();
            io.DisplaySize = .(window.Width, window.Height);
            io.DisplayFramebufferScale = .(1.0f, 1.0f);
            io.ConfigFlags |= ImGui.ConfigFlags.NavEnableKeyboard;
            io.ConfigFlags |= ImGui.ConfigFlags.DockingEnable;
            //io.ConfigFlags |= ImGui.ConfigFlags.DpiEnableScaleFonts;
            //io.ConfigFlags |= ImGui.ConfigFlags.DpiEnableScaleViewports;

            if (!ImplWin32.Init(window))
                return false;
            if (!ImplDX11.Init(_context, _device, _factory))
                return false;

            SetupStyles(app);
            FontManager.LoadFonts(buildConfig);
            return true;
        }

        private void SetupStyles(App app)
        {
            //Set dark theme colors and style
            ImGui.StyleColorsDark();
            var style = ImGui.GetStyle();
            style.WindowPadding = .(8.0f, 8.0f);
            style.FramePadding = .(5.0f, 5.0f);
            style.ItemSpacing = .(8.0f, 8.0f);
            style.ItemInnerSpacing = .(8.0f, 6.0f);
            style.IndentSpacing = 25.0f;
            style.ScrollbarSize = 18.0f;
            style.GrabMinSize = 12.0f;
            style.WindowBorderSize = 1.0f;
            style.ChildBorderSize = 1.0f;
            style.PopupBorderSize = 1.0f;
            style.FrameBorderSize = 1.0f;
            style.TabBorderSize = 0.0f;
            style.WindowRounding = 4.0f;
            style.ChildRounding = 0.0f;
            style.FrameRounding = 4.0f;
            style.PopupRounding = 4.0f;
            style.ScrollbarRounding = 4.0f;
            style.GrabRounding = 4.0f;
            style.TabRounding = 0.0f;
            ImGui.SetThemePreset(.Orange);
        }
    }
}