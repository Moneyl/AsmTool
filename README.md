
# AsmTool

WIP Tool for modifying asm_pc files used by Red Faction Guerrilla. This is meant to replace hand editing them, which is very error prone and tedious. The planned features for this tool are as follows:

- Display contents of asm_pc files in GUI
- Detect out of date asm_pc data by scanning str2_pc files in the same folder or other specified folder
- Detect issues with asm_pc files
- Auto update the contents of asm_pc files using str2_pc files in the same folder
- Compare the contents of two asm_pc files.
- Transfer entries between asm_pc two asm_pc files
- Indicate if asm_pc containers have a matching str2_pc file or if they're a "ghost container" (no str2_pc, consists of primitives shared by other containers)
- Indicate when containers share primitives
- Indicate when primitives/containers reside in a different vpp_pc than the asm_pc file.

## Notes on the codebase

- A stripped down version of the Nanoforge rewrite was used as a starting point for this app to save time. So there's still some code that mentions Nanoforge and some of the code is overkill for this editor.
- Eventually the functionality of this app will be moved into Nanoforge. I'm not doing it quite yet because the rewrite is still in progress and I don't want to deal with the extra complication of integrating this editor with projects and edit tracking.
- If I end up using Nanoforge as a base for any other apps I'll probably move the general app/window/UI setup code into a library. That way it's not being duplicated with each project.
