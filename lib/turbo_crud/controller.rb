# frozen_string_literal: true

module TurboCrud
  module Controller
    extend ActiveSupport::Concern

    included do
      # 👋 Hello controller! I will:
      # - keep your CRUD actions tiny
      # - make Turbo Stream responses consistent
      # - and reduce copy/paste tears
      helper TurboCrud::Helpers if respond_to?(:helper)
    end

    # ------------------------------------------------------------
    # turbo_respond (NEW in v0.4)
    # ------------------------------------------------------------
    # Drop-in responder for existing apps/controllers.
    #
    # You can keep your existing form partials + views.
    # TurboCrud will:
    # - create => insert row into list
    # - update => replace row/target
    # - errors => render new/edit with 422
    # - always => update flash + close modal + close drawer
    #
    # Example:
    #   @post.assign_attributes(post_params)
    #   turbo_respond(@post, list: Post, success_message: "Saved!")
    #
    # Options:
    # - list: required for create (to know which list DOM id to insert into)
    # - replace: :row (default) or "custom_target" or nil
    # - row_partial: override partial lookup (e.g. "posts/post")
    def turbo_respond(record, list: nil, insert: TurboCrud.config.default_insert, success_message: nil,
                      failure_status: :unprocessable_entity, redirect_to: nil, replace: :row, row_partial: nil)
      was_new_record = record.new_record?
      validate_insert_option!(insert)
      validate_replace_option!(replace)
      validate_list_option!(list, method_name: :turbo_respond) if was_new_record

      if record.save
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_success_streams(
              record,
              list: list,
              insert: insert,
              replace: was_new_record ? nil : replace,
              success_message: success_message,
              updating: !was_new_record,
              row_partial: row_partial
            )
          end
          format.html { redirect_to(redirect_to || record, notice: success_message, allow_other_host: false) }
        end
      else
        # 😬 Validation errors. Record said: "Nope. Try again, human."
        respond_to do |format|
          # If record is new, render :new; else render :edit.
          action = record.persisted? ? :edit : :new
          format.turbo_stream { render action: action, status: failure_status }
          format.html { render action, status: failure_status }
        end
      end
    end

    # ------------------------------------------------------------
    # turbo_save (v0.3)
    # ------------------------------------------------------------
    # Convenience wrapper: calls turbo_create or turbo_update.
    def turbo_save(record, list:, insert: TurboCrud.config.default_insert, success_message: nil,
                   failure_status: :unprocessable_entity, redirect_to: nil, replace: :row, row_partial: nil)
      if record.persisted?
        turbo_update(record, success_message: success_message, failure_status: failure_status, redirect_to: redirect_to, replace: replace, row_partial: row_partial)
      else
        turbo_create(record, list: list, insert: insert, success_message: success_message, failure_status: failure_status, redirect_to: redirect_to, row_partial: row_partial)
      end
    end

    # ------------------------------------------------------------
    # turbo_create
    # ------------------------------------------------------------
    def turbo_create(record, list:, insert: TurboCrud.config.default_insert, success_message: nil,
                     failure_status: :unprocessable_entity, redirect_to: nil, row_partial: nil)
      validate_list_option!(list, method_name: :turbo_create)
      validate_insert_option!(insert)

      if record.save
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_success_streams(
              record,
              list: list,
              insert: insert,
              replace: nil, # create inserts; we don't replace by default
              success_message: success_message,
              updating: false,
              row_partial: row_partial
            )
          end
          format.html { redirect_to(redirect_to || record, notice: success_message, allow_other_host: false) }
        end
      else
        respond_to do |format|
          format.turbo_stream { render action: :new, status: failure_status }
          format.html { render :new, status: failure_status }
        end
      end
    end

    # ------------------------------------------------------------
    # turbo_update
    # ------------------------------------------------------------
    def turbo_update(record, success_message: nil, failure_status: :unprocessable_entity, redirect_to: nil, replace: :row, row_partial: nil)
      validate_replace_option!(replace)

      if record.save
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_success_streams(
              record,
              list: nil,
              insert: nil,
              replace: replace,
              success_message: success_message,
              updating: true,
              row_partial: row_partial
            )
          end
          format.html { redirect_to(redirect_to || record, notice: success_message, allow_other_host: false) }
        end
      else
        respond_to do |format|
          format.turbo_stream { render action: :edit, status: failure_status }
          format.html { render :edit, status: failure_status }
        end
      end
    end

    # ------------------------------------------------------------
    # turbo_destroy
    # ------------------------------------------------------------
    def turbo_destroy(record, list:, success_message: nil, redirect_to: nil)
      validate_list_option!(list, method_name: :turbo_destroy)
      record.destroy

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove(view_context.dom_id(record)),
            turbo_flash_stream(notice: success_message)
          ].compact
        end
        format.html { redirect_to(redirect_to || polymorphic_url(list), notice: success_message, allow_other_host: false) }
      end
    end

    private

    # ------------------------------------------------------------
    # turbo_success_streams
    # ------------------------------------------------------------
    def turbo_success_streams(record, list:, insert:, replace:, success_message:, updating:, row_partial:)
      streams = []

      # 🧩 Insert new row into list container when creating.
      if !updating && list && insert
        streams << turbo_stream_action_for_insert(insert, list, record, row_partial: row_partial)
      end

      # 🔁 Replace target when updating (or when caller wants it).
      streams << turbo_replace_stream(record, replace: replace, row_partial: row_partial) if replace

      # 🍞 Update flash
      streams << turbo_flash_stream(notice: success_message)

      # 🚪 Close BOTH containers. Whichever one is open will disappear.
      streams << turbo_stream.update(TurboCrud.config.modal_frame_id, "")
      streams << turbo_stream.update(TurboCrud.config.drawer_frame_id, "")

      streams.compact
    end

    # ------------------------------------------------------------
    # Row partial lookup (v0.4)
    # ------------------------------------------------------------
    # We try (in order):
    # 1) row_partial argument (if provided)
    # 2) TurboCrud.config.row_partial (if not :auto)
    # 3) "<collection>/row"
    # 4) "<collection>/<element>"   (ex: "posts/post") — common existing Rails partial
    #
    # This lets TurboCrud work with existing apps without forcing `_row`.
    def turbo_row_partial_for(record, preferred: nil)
      turbo_row_partial_candidates(record, preferred: preferred).first
    end

    # ------------------------------------------------------------
    # turbo_replace_stream
    # ------------------------------------------------------------
    def turbo_replace_stream(record, replace:, row_partial:)
      target = (replace == :row) ? view_context.dom_id(record) : replace
      partial = turbo_row_partial_for(record, preferred: row_partial)
      locals  = { record.model_name.element.to_sym => record }

      turbo_stream.replace(target, partial: partial, locals: locals)
    rescue ActionView::MissingTemplate
      raise_missing_row_partial!(record, preferred: row_partial)
    end

    # ------------------------------------------------------------
    # turbo_flash_stream
    # ------------------------------------------------------------
    def turbo_flash_stream(notice: nil, alert: nil)
      turbo_stream.replace(
        TurboCrud.config.flash_frame_id,
        partial: "turbo_crud/shared/flash",
        locals: { notice: notice, alert: alert }
      )
    end

    # ------------------------------------------------------------
    # turbo_stream_action_for_insert
    # ------------------------------------------------------------
    def turbo_stream_action_for_insert(insert, list, record, row_partial:)
      list_id = view_context.turbo_list_id(list)
      partial = turbo_row_partial_for(record, preferred: row_partial)
      locals  = { record.model_name.element.to_sym => record }

      case insert.to_sym
      when :append
        turbo_stream.append(list_id, partial: partial, locals: locals)
      when :prepend
        turbo_stream.prepend(list_id, partial: partial, locals: locals)
      else
        raise ArgumentError, "Invalid `insert:` #{insert.inspect}. Use :prepend, :append, or nil."
      end
    rescue ActionView::MissingTemplate
      raise_missing_row_partial!(record, preferred: row_partial)
    end

    def turbo_row_partial_candidates(record, preferred:)
      collection = record.model_name.collection
      element = record.model_name.element

      candidates = []
      candidates << preferred if preferred.present?

      config_pref = TurboCrud.config.row_partial
      if config_pref.present? && config_pref.to_sym != :auto
        candidates << config_pref.to_s
      end

      candidates << "#{collection}/row"
      candidates << "#{collection}/#{element}"
      candidates.uniq
    end

    def raise_missing_row_partial!(record, preferred:)
      candidates = turbo_row_partial_candidates(record, preferred: preferred)
      raise TurboCrud::MissingRowPartialError,
            "Could not find a row partial for #{record.class.name}. Tried: #{candidates.join(', ')}. " \
            "Set `row_partial:` or configure `TurboCrud.config.row_partial`."
    end

    def validate_list_option!(list, method_name:)
      return if list.present?

      raise ArgumentError, "`#{method_name}` requires `list:` for create/destroy list targeting."
    end

    def validate_insert_option!(insert)
      return if insert.nil?
      return if %i[prepend append].include?(insert.to_sym)

      raise ArgumentError, "Invalid `insert:` #{insert.inspect}. Use :prepend, :append, or nil."
    rescue NoMethodError
      raise ArgumentError, "Invalid `insert:` #{insert.inspect}. Use :prepend, :append, or nil."
    end

    def validate_replace_option!(replace)
      return if replace.nil? || replace == :row || replace.is_a?(String) || replace.is_a?(Symbol)

      raise ArgumentError, "Invalid `replace:` #{replace.inspect}. Use :row, a DOM id String/Symbol, or nil."
    end
  end
end
