using AsmTool.App;
using AsmTool;
using System;

namespace AsmTool.Gui
{
    ///A single UI window for a file editor or viewer. Unlike panels these can have multiple instances as long as each is a different file
    public interface IGuiDocument
    {
    	///Per-frame update
    	public void Update(App app, Gui gui);

        ///Save state of the document
        public void Save(App app, Gui gui);

        ///Called when the user clicks the close button.
        public void OnClose(App app, Gui gui);

        ///Returns true if the document can be closed immediately. Used to ensure worker threads are stopped before deleting the document.
        public bool CanClose(App app, Gui gui);
    }

    ///Base class for all gui documents. Has fields and functions that all documents should have
    public class GuiDocumentBase : IGuiDocument
    {
        public append String Title;
        public append String UID; //Unique ID for the document. Usually will be the document path if its a real file
        public bool FirstDraw = true;
        public bool Open = true;
        public bool UnsavedChanges = false;
        public bool HasMenuBar = false;
        public bool NoWindowPadding = false;
        public bool ResetOnClose = false;

        public virtual void Update(App app, Gui gui)
        {
            return;
        }

        public virtual void Save(App app, Gui gui)
        {
            return;
        }

        public virtual void OnClose(App app, Gui gui)
        {
            return;
        }

        public virtual bool CanClose(App app, Gui gui)
        {
            return true;
        }
    }
}