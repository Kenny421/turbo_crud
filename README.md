# TurboCrud (v0.4.5)

TurboCrud is a small, opinionated helper layer for Rails + Turbo that makes CRUD feel like you're speedrunning.

## What you get
- Consistent **Turbo Stream** responses for create/update/destroy
- Drop-in **modal frame** + **drawer frame** + **flash frame**
- `turbo_save` helper (create/update with one method)
- Generator scaffold that **auto-builds form fields from attributes**
- Test skeleton + a tiny dummy app (so you can extend it later)

---

## Install

Add to your Gemfile:

```ruby
gem 'turbo_crud'
```

Then:

```bash
bundle install
```

---

## Layout setup (required)

Put these in `app/views/layouts/application.html.erb`:

```erb
<%= turbo_crud_flash_frame %>

<%= turbo_crud_modal_frame %>
<%= turbo_crud_drawer_frame %>
```

Put modal/drawer frames near the end of `<body>`.

---

## Optional initializer

If you want to customize TurboCrud defaults, create:

- `config/initializers/turbo_crud.rb` (optional)

```ruby
TurboCrud.configure do |c|
  c.default_container = :modal   # or :drawer
  c.default_insert    = :prepend # or :append

  # Row partial auto-detect is default (:auto)
  # If your app uses a custom partial path, set it:
  # c.row_partial = "posts/post"
end
```

---

## CSS (Sprockets)
Add:

```css
/*
 *= require turbo_crud
 *= require turbo_crud_modal
 *= require turbo_crud_drawer
 */
```

(If you're on cssbundling/importmap, copy these CSS files into your app or import them.)

---

## Controller usage

```ruby
class PostsController < ApplicationController
  include TurboCrud::Controller

  def create
    @post = Post.new(post_params)
    turbo_create(@post, list: Post, success_message: "Post created!")
  end

  def update
    @post = Post.find(params[:id])
    @post.assign_attributes(post_params)
    turbo_update(@post, success_message: "Post updated!")
  end

  def destroy
    @post = Post.find(params[:id])
    turbo_destroy(@post, list: Post, success_message: "Post deleted.")
  end
end
```

### One-liner save (create OR update)

```ruby
turbo_save(@post, list: Post, success_message: "Saved!")
```

TurboCrud will decide whether to insert (create) or replace (update).

---

## Validation and error behavior

TurboCrud now validates key options early with clear errors:

- `turbo_create` and create-path `turbo_respond` require `list:`
- `insert:` must be `:prepend`, `:append`, or `nil`
- `replace:` must be `:row`, a DOM id (`String`/`Symbol`), or `nil`

If row partial rendering fails, TurboCrud raises:

- `TurboCrud::MissingRowPartialError`

This error includes the model name and the partial candidates TurboCrud tried.

---

## Modal vs Drawer

Links:
- `turbo_crud_modal_link "New", new_post_path`
- `turbo_crud_drawer_link "New", new_post_path`

Forms:
- `turbo_crud_form_with ...` (defaults to your configured container)
- or explicitly: `turbo_crud_form_with ..., frame: TurboCrud.config.drawer_frame_id`

---

## Generator

```bash
rails g turbo_crud:scaffold Post title body:text published:boolean views:integer
```

It generates:
- controller wired to TurboCrud
- views: index/new/edit/_row/_form
- `_form` will contain inputs for each attribute you passed.

---

## Notes
This gem stays small on purpose.
Big gems become “frameworks”.
Frameworks become “why is this broken?”. 😄

## Generator options

By default the scaffold generates **modal** `new/edit` views.

You can switch to **drawer** views:

```bash
rails g turbo_crud:scaffold Post title body:text --container=drawer
```

Or generate **both** (modal files + extra drawer files as `new.drawer.html.erb` / `edit.drawer.html.erb`):

```bash
rails g turbo_crud:scaffold Post title body:text --container=both
```

`--container` is validated strictly and must be one of:

- `modal`
- `drawer`
- `both`

Tip: if you want the whole app to prefer drawers, set:

```ruby
TurboCrud.configure do |c|
  c.default_container = :drawer
end
```

## Using TurboCrud with existing apps (existing forms, existing views)

You do **not** have to rewrite your forms.

### Step 1: open new/edit in a frame (modal or drawer)

```erb
<%= turbo_crud_modal_link "New", new_post_path %>
<%= turbo_crud_modal_link "Edit", edit_post_path(@post) %>
```

Or drawer:

```erb
<%= turbo_crud_drawer_link "New", new_post_path %>
```

### Step 2: wrap your current new/edit views (keep your form partial!)

In your existing `new.html.erb`:

```erb
<%= turbo_crud_container title: "New Post" do %>
  <%= render "form" %>
<% end %>
```

In your existing `edit.html.erb`:

```erb
<%= turbo_crud_container title: "Edit Post" do %>
  <%= render "form" %>
<% end %>
```

### Step 3: use `turbo_respond` in your controller

```ruby
def create
  @post = Post.new(post_params)
  turbo_respond(@post, list: Post, success_message: "Created!")
end

def update
  @post = Post.find(params[:id])
  @post.assign_attributes(post_params)
  turbo_respond(@post, list: Post, success_message: "Updated!")
end
```

### Row partial auto-detection

TurboCrud will try:
1) `posts/_row.html.erb`
2) `posts/_post.html.erb` (common existing Rails partial)

You can override globally:

```ruby
TurboCrud.configure do |c|
  c.row_partial = "posts/post" # or "shared/post_row"
end
```

Or per-call:

```ruby
turbo_respond(@post, list: Post, row_partial: "posts/post")
```

## Full scaffold generator (model + migration + routes + TurboCrud views)

TurboCrud now includes a “batteries included” generator that creates:

- Model + migration (like `rails g model ...`)
- Routes (`resources :things`)
- TurboCrud controller + views (modal/drawer/both)

Run it like:

```bash
bin/rails g turbo_crud:full_scaffold Post title body:text published:boolean --container=both
bin/rails db:migrate
```

Notes:
- Rails generators don’t run migrations automatically (Rails is polite like that).
- If routes already exist, TurboCrud won’t double-inject them.

## One generator to remember: `turbo_crud:scaffold`

By default it generates **controller + views** (no model, no routes):

```bash
bin/rails g turbo_crud:scaffold Post title body:text published:boolean --container=both
```

If you want **FULL scaffold** (model + migration + routes + controller + views), add `--full`:

```bash
bin/rails g turbo_crud:scaffold Post title body:text published:boolean --container=both --full
bin/rails db:migrate
```

You can control parts:

```bash
bin/rails g turbo_crud:scaffold Post title body:text --full --skip-model
bin/rails g turbo_crud:scaffold Post title body:text --full --skip-routes
```

## Install helper (`--install`)

You can ask the scaffold generator to also wire up your app layout + CSS.

```bash
bin/rails g turbo_crud:scaffold Post title body:text --container=both --install
```

What `--install` does (idempotent):
- injects these frames near the end of `app/views/layouts/application.html.erb` (before `</body>`):
  - `turbo_crud_flash_frame`
  - `turbo_crud_modal_frame`
  - `turbo_crud_drawer_frame`
- tries to add Sprockets requires to `app/assets/stylesheets/application.css`:
  - `*= require turbo_crud`
  - `*= require turbo_crud_modal`
  - `*= require turbo_crud_drawer`

If it can’t find those files, it will print a warning with what to add manually.

---

## CI / Security

This repo includes separate GitHub Actions workflows:

- `Test` workflow: runs `bundle exec rake test`
- `Security` workflow: runs `brakeman` and `bundle-audit`

Run locally:

```bash
bundle exec rake test
bundle exec brakeman --force --no-pager -q
bundle exec bundle-audit check
```
