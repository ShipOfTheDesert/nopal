# Nopal

Nopal aims to be a cross-platform UI framework for OCaml.

## Component Library

`nopal_ui` provides high-level UI components built as pure `Element.t`
compositions. Each component is a plain function returning framework-agnostic
element trees — no platform dependency, no mutable state. Components that
have interactive or semantic roles include appropriate ARIA attributes for
accessibility.

| Component | Description |
|---|---|
| Button | Button with variants (Primary, Secondary, Destructive, Ghost, Icon), loading and disabled states |
| Checkbox | Labelled checkbox input |
| Data_table | Sortable table with column headers and cell content |
| Modal | Dialog overlay with backdrop, Escape-key dismissal, and focus cycling |
| Navigation_bar | Tab-style navigation bar with active/inactive states |
| Radio_group | Labelled radio button group with disabled state support |
| Select_input | Labelled select dropdown with optional placeholder |
| Slug | URL-safe slug generation from human-readable strings |
| Text_input | Labelled text input with placeholder, error display, and aria-describedby linkage |
| Toast | Dismissible notification with variant-based styling and aria-live regions |
