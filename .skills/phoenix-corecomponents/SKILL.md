# Phoenix CoreComponents

Working with Phoenix 1.8+ CoreComponents for common UI patterns.

## Overview

Phoenix provides a set of core components in `CoreComponents` module that handle common UI patterns like forms, tables, buttons, and navigation. This skill covers how to use them effectively in LiveView applications.

## When to Use

- Building forms with validation
- Displaying tabular data
- Creating navigation links
- Building modal dialogs
- Standard UI elements (buttons, inputs, icons)

## Component Reference

### Button Component

The `<.button>` component intelligently renders as either a `<button>` or `<.link>` based on attributes.

**As a Button (for events):**
```heex
<.button
  phx-click={JS.push("save")}
  class="btn-primary"
>
  Save
</.button>
```

**As a Link (for navigation):**
```heex
<.button
  navigate={~p"/items/new"}
  class="btn-primary"
>
  New Item
</.button>
```

**With Icons:**
```heex
<.button class="btn-ghost btn-sm text-error">
  <.icon name="hero-trash" class="size-4" />
</.button>
```

**Key Points:**
- Use `phx-click` for LiveView events (renders as `<button>`)
- Use `navigate`, `href`, or `patch` for navigation (renders as `<.link>`)
- Supports all standard button/link attributes via `@rest`

### Table Component

Display tabular data with optional actions.

**Basic Table:**
```heex
<.table id="items" rows={@items}>
  <:col :let={item} label="Name">{item.name}</:col>
  <:col :let={item} label="Status">{item.status}</:col>
</.table>
```

**With Actions:**
```heex
<.table id="items" rows={@items}>
  <:col :let={item} label="Name">{item.name}</:col>
  
  <:action :let={item}>
    <.button navigate={~p"/items/#{item.id}"} class="btn-ghost btn-sm">
      <.icon name="hero-eye" class="size-4" />
    </.button>
    
    <.button
      phx-click={JS.push("delete", value: %{id: item.id})}
      data-confirm="Are you sure?"
      class="btn-ghost btn-sm text-error"
    >
      <.icon name="hero-trash" class="size-4" />
    </.button>
  </:action>
</.table>
```

**With Row Click:**
```heex
<.table 
  id="items" 
  rows={@items}
  row_click={fn item -> JS.navigate(~p"/items/#{item.id}") end}
>
  <:col :let={item} label="Name">{item.name}</:col>
</.table>
```

**Table Component Attributes:**
- `id` - Required unique identifier
- `rows` - List of data items
- `row_id` - Function to generate row ID (for streams)
- `row_click` - Function for row click handling
- `:col` slot - Column definitions
- `:action` slot - Action buttons column

### Form Components

**Basic Form:**
```heex
<.form for={@form} phx-change="validate" phx-submit="save">
  <.input field={@form[:name]} type="text" label="Name" />
  <.input field={@form[:email]} type="email" label="Email" />
  <.button type="submit">Submit</.button>
</.form>
```

**With Select:**
```heex
<.input 
  field={@form[:status]} 
  type="select" 
  label="Status"
  options={["active", "inactive"]}
/>
```

**With Error Messages:**
```heex
<.input 
  field={@form[:name]} 
  type="text" 
  label="Name"
  errors={@form[:name].errors}
/>
```

### Link Component

**Navigation:**
```heex
<.link navigate={~p"/items"}>Back to list</.link>
<.link href="https://example.com">External link</.link>
```

**Live Patching:**
```heex
<.link patch={~p"/items?page=2"}>Page 2</.link>
```

**Styling:**
```heex
<.link navigate={~p"/items/new"} class="btn btn-primary">
  <.icon name="hero-plus" class="size-4" />
  New Item
</.link>
```

### Icon Component

```heex
<%!-- Basic icon --%>
<.icon name="hero-check" />

<%!-- With size --%>
<.icon name="hero-trash" class="size-4" />

<%!-- With animation --%>
<.icon name="hero-arrow-path" class="motion-safe:animate-spin" />

<%!-- Solid variant --%>
<.icon name="hero-check-solid" />

<%!-- Mini variant --%>
<.icon name="hero-check-mini" />
```

### Flash Messages

```heex
<%!-- Success flash --%>
<.flash kind={:info} flash={@flash} />

<%!-- Error flash --%>
<.flash kind={:error} flash={@flash} />

<%!-- Flash group (multiple messages) --%>
<.flash_group flash={@flash} />
```

### List Component

```heex
<.list>
  <:item title="Name">{item.name}</:item>
  <:item title="Email">{item.email}</:item>
  <:item title="Status">
    <span class={status_class(item.status)}>{item.status}</span>
  </:item>
</.list>
```

### Modal Component

```heex
<%= if @show_modal do %>
  <div class="modal modal-open">
    <div class="modal-box">
      <h3 class="font-bold text-lg">Modal Title</h3>
      <p class="py-4">Modal content here...</p>
      <div class="modal-action">
        <.button phx-click="close_modal" class="btn-ghost">Cancel</.button>
        <.button phx-click="confirm" class="btn-primary">Confirm</.button>
      </div>
    </div>
  </div>
<% end %>
```

## Common Patterns

### Confirmation Dialogs

Use `data-confirm` attribute on buttons for browser confirmation:

```heex
<.button
  phx-click={JS.push("delete", value: %{id: item.id})}
  data-confirm="Are you sure you want to delete this item? This action cannot be undone."
  class="btn-ghost btn-sm text-error"
>
  <.icon name="hero-trash" class="size-4" />
</.button>
```

**User Experience:**
1. User clicks button
2. Browser shows native confirmation dialog
3. "Cancel" - nothing happens
4. "OK" - LiveView event fires

### Form Validation

```heex
<.form for={@form} phx-change="validate" phx-submit="save">
  <.input 
    field={@form[:email]} 
    type="email" 
    label="Email"
    required
    phx-debounce="blur"
  />
  
  <.button type="submit" disabled={not @form.source.valid?}>
    Submit
  </.button>
</.form>
```

### Conditional Rendering

```heex
<%= if Enum.empty?(@items) do %>
  <.icon name="hero-inbox" class="size-16" />
  <p>No items yet</p>
<% else %>
  <.table id="items" rows={@items}>
    <%!-- table content --%>
  </.table>
<% end %>
```

## Best Practices

### 1. Use Semantic Button Types

```heex
<%!-- For forms --%>
<.button type="submit">Submit</.button>

<%!-- For destructive actions --%>
<.button class="text-error">Delete</.button>

<%!-- For secondary actions --%>
<.button class="btn-ghost">Cancel</.button>
```

### 2. Accessible Icons

Always include text or aria-label with icons:

```heex
<%!-- Good --%>
<.button aria-label="Delete item">
  <.icon name="hero-trash" />
</.button>

<%!-- Better --%>
<.button>
  <.icon name="hero-trash" class="size-4" />
  <span class="sr-only">Delete</span>
</.button>
```

### 3. Consistent Table Actions

Keep action buttons consistent across tables:

```heex
<:action :let={item}>
  <.button navigate={~p"/items/#{item.id}"} class="btn-ghost btn-sm">
    <.icon name="hero-eye" />
  </.button>
  <.button navigate={~p"/items/#{item.id}/edit"} class="btn-ghost btn-sm">
    <.icon name="hero-pencil" />
  </.button>
  <.button 
    phx-click={JS.push("delete", value: %{id: item.id})}
    data-confirm="Are you sure?"
    class="btn-ghost btn-sm text-error"
  >
    <.icon name="hero-trash" />
  </.button>
</:action>
```

### 4. Loading States

```heex
<.button 
  phx-click="submit" 
  disabled={@loading}
  class={[@loading && "opacity-50 cursor-not-allowed"]}
>
  <%= if @loading do %>
    <.icon name="hero-arrow-path" class="animate-spin size-4 mr-1" />
    Saving...
  <% else %>
    Save
  <% end %>
</.button>
```

## Common Issues

### Button Not Triggering Event

**Problem:** `phx-click` doesn't work
**Solution:** Ensure not using `navigate` or `href` attributes:
```heex
<%!-- Wrong - renders as link --%>
<.button navigate={...} phx-click="save">

<%!-- Correct - renders as button --%>
<.button phx-click={JS.push("save")}>
```

### Table Actions Not Aligned

**Problem:** Action buttons are misaligned
**Solution:** All buttons should use consistent sizing:
```heex
<:action :let={item}>
  <div class="flex gap-2">
    <.button class="btn-ghost btn-sm">
      <.icon name="hero-eye" class="size-4" />
    </.button>
    <.button class="btn-ghost btn-sm">
      <.icon name="hero-trash" class="size-4" />
    </.button>
  </div>
</:action>
```

## Customizing

### Custom Button Variants

Add to your `core_components.ex`:

```elixir
def button(%{variant: "danger"} = assigns) do
  ~H"""
  <button class={["btn", "btn-error", "text-white"]} {@rest}>
    {render_slot(@inner_block)}
  </button>
  """
end
```

Usage:
```heex
<.button variant="danger">Delete</.button>
```

## Related Skills

- [Ash Framework](../ash-framework/SKILL.md)
- [Helm Deployment Tokens](../helm-deployment-tokens/SKILL.md)
