# View Components

This app uses [ViewComponent](https://viewcomponent.org/) with a custom `ApplicationComponent` base class that provides a `prop` DSL (similar to `dry-initializer` options).

## Structure

Each component lives in its own namespaced directory:

```
app/components/
├── application_component.rb        # Base class — do not render directly
├── copy_button/
│   ├── component.rb                # Ruby class
│   ├── component.html.erb          # Template
│   └── component.js                # Stimulus controller (optional)
└── status_badge/
    ├── component.rb
    └── component.html.erb
```

## Creating a Component

1. Create a directory under `app/components/` matching the component name (snake_case).
2. Add `component.rb` with a namespaced class inheriting from `ApplicationComponent`.
3. Add `component.html.erb` for the template.
4. Optionally add `component.js` for a Stimulus controller.

### Props

Use `prop` instead of manually writing `initialize`, `attr_reader`, and instance variable assignments.

```ruby
module MyComponent
  class Component < ApplicationComponent
    prop :title                                         # required
    prop :subtitle, optional: true                      # optional, defaults to nil
    prop :count,    default: -> { 0 }                   # with default (must be a callable)
    prop :status,   type: proc(&:to_sym)                # with type coercion
    prop :url,      type: proc(&:to_s), optional: true  # combined options
  end
end
```

- Props are **required** by default. Pass `optional: true` to make them optional.
- **Defaults** must be a `Proc` or lambda. They are called when the value is `nil`.
- **Type coercion** accepts any callable (e.g. `proc(&:to_s)`, `proc(&:to_i)`, `->(v) { !!v }`).
- Props automatically generate a public `attr_reader`.
- Props are inherited by subclasses.
- Any keyword arguments **not** declared as props are available via `html_options` for passthrough HTML attributes.

## Rendering

```erb
<%= render MyComponent::Component.new(title: "Hello") %>

<%# With block content: %>
<%= render CopyButton::Component.new(label: "Copy code") do %>
  <%= @code %>
<% end %>

<%# Extra kwargs become html_options: %>
<%= render MyComponent::Component.new(title: "Hello", class: "mt-4", data: { turbo: false }) %>
```

## JavaScript (Stimulus)

Component Stimulus controllers live alongside the component as `component.js`. They are pinned via importmaps and must be explicitly registered in `app/javascript/controllers/index.js`:

```js
import MyController from "components/my_component/component";
application.register("my-controller", MyController);
```

The importmap setup requires three pieces of configuration:

In `config/importmap.rb`, pin the components directory:

```ruby
pin_all_from "app/components", under: "components", to: ""
```

In `config/initializers/assets.rb`, add components to the asset paths so the asset pipeline can serve the JS files:

```ruby
Rails.application.config.assets.paths << Rails.root.join("app/components")
```

In `config/application.rb`, add the cache sweeper so importmap picks up new/changed JS files in development:

```ruby
config.importmap.cache_sweepers << Rails.root.join("app/components")
```
