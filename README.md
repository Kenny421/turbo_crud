# TurboCrud (v0.4.9)

TurboCrud is a small Rails + Turbo helper that makes CRUD screens easier to build and maintain.

## Quick start

If you are starting new CRUD screens:

```bash
bin/rails g turbo_crud:scaffold Post title body:text published:boolean --container=both
```

If you already have a Rails app and want to integrate TurboCrud:
1. Add layout frames (`turbo_crud_flash_frame`, `turbo_crud_modal_frame`, `turbo_crud_drawer_frame`)
2. Update controller create/update/destroy to `turbo_create`, `turbo_update`, `turbo_destroy`
3. Render index list with `turbo_list_id(Model)` + a row partial collection
4. Ensure row partial exists (`_row` or existing model partial like `_blog`)
5. Wrap `new/edit` pages with `turbo_crud_container`

If you see `Content missing`, your `new/edit` templates are probably not rendering inside the expected Turbo frame/container.

## What you get
- Consistent **Turbo Stream** responses for create/update/destroy
- Built-in **modal frame** + **drawer frame** + **flash frame**
- `turbo_save` helper (create/update with one method)
- Generator scaffold that **auto-builds form fields from attributes**
- Test coverage + a small dummy app you can extend

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

  # Optional per-model overrides (safer than one global row_partial):
  # key can be model class, class name, or model symbol/string.
  c.model_defaults = {
    "Blog" => { row_partial: "blogs/blog", container: :drawer, insert: :append }
  }
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

### Single helper for create/update

```ruby
turbo_save(@post, list: Post, success_message: "Saved!")
```

TurboCrud will decide whether to insert (create) or replace (update).

---

## Resource DSL (`turbo_crud_resource`)

You can generate standard CRUD actions with one declaration:

```ruby
class PostsController < ApplicationController
  include TurboCrud::Controller

  turbo_crud_resource Post,
    scope: -> { Post.order(created_at: :desc) },
    permit: %i[title body published],
    authorize_with: :pundit, # :pundit, :cancancan, :nil, or omit for auto-detect
    container: :drawer
end
```

What this sets up:
- `index/new/create/edit/update/destroy` actions
- strong params via `permit:`
- `create/update/destroy` wired to TurboCrud responders
- optional authorization adapter hooks (`authorize` / `authorize!`)
- model-level default container (`container:`) used by `turbo_crud_form_with`

Notes:
- `permit:` is required.
- `only:` / `except:` are supported to limit generated actions.
- If `authorize_with:` is omitted, TurboCrud auto-detects in this order:
  1. `authorize!` => CanCanCan
  2. `authorize` => Pundit
  3. none => no authorization call
- `authorize_with: :pundit` expects `authorize`.
- `authorize_with: :cancancan` expects `authorize!`.
- `authorize_with: nil` explicitly disables authorization calls.
- Your normal Rails controller permissions still apply (for example `before_action` checks in `ApplicationController`), because your controller inherits from it.

If you use your own controller permissions (no Pundit/CanCanCan):

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :enforce_permissions!

  private

  def enforce_permissions!
    # your app's permission logic
  end
end

# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  include TurboCrud::Controller
  before_action :authenticate_user!, only: %i[show edit update destroy]
  before_action :enforce_permissions!

  turbo_crud_resource Post,
    scope: -> { Post.order(created_at: :desc) },
    permit: %i[title body published],
    authorize_with: nil

  private

  def enforce_permissions!
    # your app's permission logic
  end
end
```

Full controller examples:

```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  include TurboCrud::Controller
  include Pundit::Authorization

  # Auto-detect would also pick Pundit because `authorize` exists,
  # but this keeps intent explicit.
  turbo_crud_resource Post,
    scope: -> { policy_scope(Post).order(created_at: :desc) },
    permit: %i[title body published],
    authorize_with: :pundit,
    container: :drawer
end

# app/controllers/admin/posts_controller.rb
class Admin::PostsController < ApplicationController
  include TurboCrud::Controller
  include CanCan::ControllerAdditions

  # Omitted `authorize_with:` -> auto-detects CanCanCan (`authorize!`)
  turbo_crud_resource Post,
    scope: -> { Post.order(created_at: :desc) },
    permit: %i[title body published featured]
end

# app/controllers/internal/posts_controller.rb
class Internal::PostsController < ApplicationController
  include TurboCrud::Controller

  # Explicitly disable authorization calls from the DSL.
  turbo_crud_resource Post,
    scope: -> { Post.order(created_at: :desc) },
    permit: %i[title body published],
    authorize_with: nil
end
```

Equivalent generated action behavior:

```ruby
class PostsController < ApplicationController
  include TurboCrud::Controller

  # This declaration generates the CRUD actions.
  turbo_crud_resource Post, permit: %i[title body published], authorize_with: :pundit

  # Rough equivalent of generated update:
  # def update
  #   @post = Post.find(params[:id])
  #   authorize(@post)
  #   @post.assign_attributes(params.require(:post).permit(:title, :body, :published))
  #   turbo_update(@post)
  # end
  #
  # Rough equivalent of generated destroy:
  # def destroy
  #   @post = Post.find(params[:id])
  #   authorize(@post)
  #   turbo_destroy(@post, list: Post)
  # end
end
```

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
- submit buttons auto-disable during Turbo submit (opt out: `data: { turbo_crud_auto_disable: false }`)
- `Escape` closes active modal/drawer and `Tab` focus stays inside the open container

Example submit button loading text:

```erb
<%= turbo_crud_form_with model: @post do |f| %>
  <%= f.text_field :title %>
  <%= f.submit "Save", data: { turbo_crud_loading_text: "Saving..." } %>
<% end %>
```

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
TurboCrud is intentionally small. The goal is to keep behavior predictable and integration simple, especially in existing Rails apps.

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

### Drawer `Content missing` fix

If this happens when clicking `turbo_crud_drawer_link`:

1. Confirm your layout includes `<%= turbo_crud_drawer_frame %>`.
2. Confirm `new/edit` use `turbo_crud_container` (or drawer frame wrapper).
3. Confirm the link uses drawer target:
   - `<%= turbo_crud_drawer_link "New", new_blog_path %>`
4. Update to the latest TurboCrud and restart the Rails server (includes frame auto-detection improvements).

### Flash message does not update until refresh

If create/update/delete works but the message stays on an older value:

1. Ensure `application.html.erb` has exactly one `<%= turbo_crud_flash_frame %>`.
2. Remove legacy layout flash blocks like `<%= notice %>` and `<%= alert %>`.
3. Ensure your flash partial uses key checks so explicit Turbo locals are respected:

```erb
<% notice_message = local_assigns.key?(:notice) ? local_assigns[:notice] : flash[:notice] %>
<% alert_message  = local_assigns.key?(:alert)  ? local_assigns[:alert]  : flash[:alert] %>
```

4. Use a TurboCrud version where flash stream updates use `update` (not `replace`), so the `turbo_flash` frame id remains targetable across requests.

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
3) `TurboCrud.config.row_partial` (only if path looks compatible with current model)

You can also set globally:

```ruby
TurboCrud.configure do |c|
  c.row_partial = "blogs/blog"
end
```

Tip: if your app has multiple resources, prefer passing `row_partial:` per action/controller instead of a single global path.

### Per-model defaults (recommended for multi-resource apps)

Instead of a global `c.row_partial`, use:

```ruby
TurboCrud.configure do |c|
  c.model_defaults = {
    "Blog" => { row_partial: "blogs/blog", container: :drawer, insert: :append },
    "Post" => { container: :modal, insert: :prepend }
  }
end
```

Per-model defaults apply to:
- `row_partial` (create/update rendering)
- `container` (default modal/drawer for `turbo_crud_form_with` / `turbo_crud_container`)
- `insert` (default append/prepend for create)

## Full scaffold generator (model + migration + routes + TurboCrud views)

`full_scaffold` creates:

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

## Main generator: `turbo_crud:scaffold`

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

What `--install` does:
- injects these frames near the end of `app/views/layouts/application.html.erb` (before `</body>`):
  - `turbo_crud_flash_frame`
  - `turbo_crud_modal_frame`
  - `turbo_crud_drawer_frame`
- tries to add Sprockets requires to `app/assets/stylesheets/application.css`:
  - `*= require turbo_crud`
  - `*= require turbo_crud_modal`
  - `*= require turbo_crud_drawer`

If it can’t find those files, it prints a warning with the manual steps.

---

## Doctor command

TurboCrud includes a diagnostic generator for existing apps:

```bash
bin/rails g turbo_crud:doctor
```

It checks:
- layout frames (`flash`, `modal`, `drawer`)
- controller inclusion of `TurboCrud::Controller`
- presence of view partials for stream rendering

Use strict mode (non-zero exit on issues):

```bash
bin/rails g turbo_crud:doctor --strict
```

---

## CI / Security

This repo includes separate GitHub Actions workflows:

- `Test` workflow: runs `bundle exec rake test` across Ruby/Rails matrix
- `Security` workflow: runs `brakeman` and `bundle-audit`

Run locally:

```bash
bundle exec rake test
bundle exec brakeman --force --no-pager -q
bundle exec bundle-audit check
```

---

## Observability events

TurboCrud emits `ActiveSupport::Notifications` events:

- `turbo_crud.create`
- `turbo_crud.update`
- `turbo_crud.destroy`
- `turbo_crud.row_partial_missing`

Payload includes controller/action, model/id, format, and success/error metadata.

Subscribe example:

```ruby
ActiveSupport::Notifications.subscribe("turbo_crud.create") do |_name, _start, _finish, _id, payload|
  Rails.logger.info("[turbo_crud.create] #{payload.inspect}")
end
```

In most apps, put this in an initializer for centralized logging/metrics.
