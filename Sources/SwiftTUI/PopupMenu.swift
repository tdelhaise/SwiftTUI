import Foundation

@MainActor
open class PopupMenu: MenuBox {
    // PopupMenu largely reuses MenuBox's functionality.
    // The main difference is how it's positioned and dismissed.
    // It's typically created at a specific screen coordinate (e.g., mouse click location)
    // and automatically dismisses when an item is selected or focus is lost.

    // No additional properties or overrides needed for now, as MenuBox provides the core logic.
    // Future enhancements might include:
    // - Automatic positioning based on screen bounds.
    // - Handling clicks outside the menu for dismissal.
}
