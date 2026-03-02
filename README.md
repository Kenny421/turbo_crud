# TurboCrud (v0.4.7)

TurboCrud is a small, opinionated helper layer for Rails + Turbo that makes CRUD feel like you're speedrunning.

## Quick start (choose one path)

If you are starting new CRUD screens:

```bash
bin/rails g turbo_crud:scaffold Post title body:text published:boolean --container=both
```

If you already have a Rails scaffold/app and want to integrate TurboCrud:
1. Add layout frames (`turbo_crud_flash_frame`, `turbo_crud_modal_frame`, `turbo_crud_drawer_frame`)
2. Update controller create/update/destroy to `turbo_create`, `turbo_update`, `turbo_destroy`
3. Render index list with `turbo_list_id(Model)` + a row partial collection
4. Ensure row partial exists (`_row` or existing model partial like `_blog`)
5. Wrap `new/edit` pages with `turbo_crud_container`

If your modal shows `Content missing`, `new/edit` is not wrapped/rendered for Turbo frame requests.

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

## Existing app integration (step-by-step)

You can keep your existing model, routes, and form partials.

### 1) Add layout frames once

In `app/views/layouts/application.html.erb` (near end of `<body>`):

```erb
<%= turbo_crud_flash_frame %>
<%= turbo_crud_modal_frame %>
<%= turbo_crud_drawer_frame %>
```

### 2) Update controller actions to TurboCrud responders

Example for an existing `BlogsController`:

```ruby
class BlogsController < ApplicationController
  include TurboCrud::Controller
  before_action :set_blog, only: %i[show edit update destroy]

  def index
    @blogs = Blog.order(created_at: :desc)
  end

  def new
    @blog = Blog.new
    render(**turbo_crud_template_for(:new))
  end

  def edit
    render(**turbo_crud_template_for(:edit))
  end

  def create
    @blog = Blog.new(blog_params)
    turbo_create(@blog, list: Blog, row_partial: "blogs/blog", success_message: "Blog created!")
  end

  def update
    @blog.assign_attributes(blog_params)
    turbo_update(@blog, row_partial: "blogs/blog", success_message: "Blog updated!")
  end

  def destroy
    turbo_destroy(@blog, list: Blog, success_message: "Blog deleted.")
  end
end
```

Note: keep your preferred strong params style (`require/permit` or Rails 8 `expect`).

### 3) Update index to use Turbo list id + row partial collection

Replace the classic scaffold loop:

```erb
<div id="blogs">
  <% @blogs.each do |blog| %>
    <%= render blog %>
  <% end %>
</div>
<%= link_to "New blog", new_blog_path %>
```

with:

```erb
<%= turbo_crud_modal_link "New blog", new_blog_path %>

<div id="<%= turbo_list_id(Blog) %>">
  <%= render partial: "blogs/blog", collection: @blogs, as: :blog %>
</div>
```

Use `turbo_crud_drawer_link` instead if your app prefers drawers.

### 4) Reuse your existing `_blog` partial as the row partial

If you already have `app/views/blogs/_blog.html.erb`, you can use it directly:

```erb
<div id="<%= dom_id blog %>">
  <div>
    <strong>Title:</strong>
    <%= blog.title %>
  </div>

  <div>
    <strong>Content:</strong>
    <%= blog.content %>
  </div>

  <div class="mt-3">
    <%= turbo_crud_modal_link "Edit", edit_blog_path(blog),
      class: "rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-sm font-semibold text-slate-900 hover:bg-slate-50" %>
  </div>
</div>
```

### 5) Wrap `new/edit` pages so frame requests render container UI

`app/views/blogs/new.html.erb`:

```erb
<%= turbo_crud_container title: "New Blog" do %>
  <%= render "form", blog: @blog %>
<% end %>
```

`app/views/blogs/edit.html.erb`:

```erb
<%= turbo_crud_container title: "Edit Blog" do %>
  <%= render "form", blog: @blog %>
<% end %>
```

If you see "Content missing", it usually means your `new/edit` templates are not rendering inside TurboCrud container/frame markup.

### Drawer `Content missing` quick fix

If this happens when clicking `turbo_crud_drawer_link`:

1. Confirm your layout includes `<%= turbo_crud_drawer_frame %>`.
2. Confirm `new/edit` use `turbo_crud_container` (or drawer frame wrapper).
3. Confirm the link uses drawer target:
   - `<%= turbo_crud_drawer_link "New", new_blog_path %>`
4. Update to latest TurboCrud and restart Rails server (new frame auto-detection logic is included).

### 6) Common integration mistakes

- Index list container uses `id="blogs"` instead of `id="<%= turbo_list_id(Blog) %>"`
- Controller `create/update` does not pass `list: Blog`
- No row partial available (`blogs/_row` or `blogs/_blog`)
- `new/edit` renders plain form page instead of `turbo_crud_container`
- Using wrong route helper in row partial (example: `edit_dan_path` instead of `edit_blog_path`)

### Row partial auto-detection (if you don't pass `row_partial`)

TurboCrud tries:
1) `blogs/_row.html.erb`
2) `blogs/_blog.html.erb`

You can also set globally:

```ruby
TurboCrud.configure do |c|
  c.row_partial = "blogs/blog"
end
```

## Full scaffold generator (model + migration + routes + TurboCrud views)

TurboCrud now includes a “batteries included” generator that creates:

- Model + migration (like `rails g model ...`)
- Routes (`resources :things`)
- TurboCrud controller + views (modal/drawer/both)

Run it like:

```bash
bin/rails g turbo_crud:full_scaffold Post title body:text published:boolean --container=both
```

Notes:
- TurboCrud does not run `db:migrate` unless you opt in with `--migrate`.
- If routes already exist, TurboCrud won’t double-inject them.

## One generator to remember: `turbo_crud:scaffold`

By default it generates **controller + views** (no model, no routes):

```bash
bin/rails g turbo_crud:scaffold Post title body:text published:boolean --container=both
```

If you want **FULL scaffold** (model + migration + routes + controller + views), add `--full`:

```bash
bin/rails g turbo_crud:scaffold Post title body:text published:boolean --container=both --full
```

`--full` does not run `db:migrate` by default.
Use `--migrate` to run migrations automatically.

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
