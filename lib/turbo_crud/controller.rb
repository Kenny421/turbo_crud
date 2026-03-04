# frozen_string_literal: true

module TurboCrud
  module Controller
    extend ActiveSupport::Concern
    DEFAULT_OPTION = Object.new
    AUTO_AUTHORIZE = Object.new
    RESOURCE_ACTIONS = %i[index new create edit update destroy].freeze

    included do
      # 👋 Hello controller! I will:
      # - keep your CRUD actions tiny
      # - make Turbo Stream responses consistent
      # - and reduce copy/paste tears
      helper TurboCrud::Helpers if respond_to?(:helper)
    end

    class_methods do
      def turbo_crud_resource(model_class, scope: nil, permit:, authorize_with: AUTO_AUTHORIZE, container: nil, list: nil, only: nil, except: nil)
        raise ArgumentError, "turbo_crud_resource requires a model class" unless model_class.respond_to?(:model_name)

        permits = Array(permit).map(&:to_sym)
        raise ArgumentError, "turbo_crud_resource requires `permit:` with at least one attribute" if permits.empty?

        normalized_auth = normalize_turbo_crud_authorizer(authorize_with)
        normalized_container = normalize_turbo_crud_container(container)

        config = {
          model: model_class,
          scope: scope,
          permit: permits,
          authorize_with: normalized_auth,
          container: normalized_container,
          list: list || model_class
        }.freeze

        class_attribute :turbo_crud_resource_config, instance_writer: false unless respond_to?(:turbo_crud_resource_config)
        self.turbo_crud_resource_config = config

        apply_turbo_crud_model_container_default!(model_class, normalized_container) if normalized_container

        actions = RESOURCE_ACTIONS.dup
        actions &= Array(only).map(&:to_sym) if only
        actions -= Array(except).map(&:to_sym) if except

        define_turbo_crud_resource_actions(actions)
      end

      private

      def define_turbo_crud_resource_actions(actions)
        if actions.include?(:index)
          define_method(:index) do
            config = self.class.turbo_crud_resource_config
            model = config.fetch(:model)
            collection_ivar = "@#{model.model_name.collection}"
            turbo_crud_authorize_resource!(config, :index, model)
            records = turbo_crud_resource_scope(config)
            instance_variable_set(collection_ivar, records)
            render :index
          end
        end

        if actions.include?(:new)
          define_method(:new) do
            config = self.class.turbo_crud_resource_config
            model = config.fetch(:model)
            member_ivar = "@#{model.model_name.element}"
            record = model.new
            turbo_crud_authorize_resource!(config, :new, record)
            instance_variable_set(member_ivar, record)
            render(**turbo_crud_template_for(:new))
          end
        end

        if actions.include?(:create)
          define_method(:create) do
            config = self.class.turbo_crud_resource_config
            model = config.fetch(:model)
            member_ivar = "@#{model.model_name.element}"
            record = model.new(turbo_crud_resource_params(config))
            turbo_crud_authorize_resource!(config, :create, record)
            instance_variable_set(member_ivar, record)
            turbo_create(record, list: config[:list])
          end
        end

        if actions.include?(:edit)
          define_method(:edit) do
            config = self.class.turbo_crud_resource_config
            model = config.fetch(:model)
            member_ivar = "@#{model.model_name.element}"
            record = turbo_crud_find_resource_record(config)
            turbo_crud_authorize_resource!(config, :edit, record)
            instance_variable_set(member_ivar, record)
            render(**turbo_crud_template_for(:edit))
          end
        end

        if actions.include?(:update)
          define_method(:update) do
            config = self.class.turbo_crud_resource_config
            model = config.fetch(:model)
            member_ivar = "@#{model.model_name.element}"
            record = turbo_crud_find_resource_record(config)
            turbo_crud_authorize_resource!(config, :update, record)
            record.assign_attributes(turbo_crud_resource_params(config))
            instance_variable_set(member_ivar, record)
            turbo_update(record)
          end
        end

        if actions.include?(:destroy)
          define_method(:destroy) do
            config = self.class.turbo_crud_resource_config
            model = config.fetch(:model)
            member_ivar = "@#{model.model_name.element}"
            record = turbo_crud_find_resource_record(config)
            turbo_crud_authorize_resource!(config, :destroy, record)
            instance_variable_set(member_ivar, record)
            turbo_destroy(record, list: config[:list])
          end
        end
      end

      def normalize_turbo_crud_authorizer(authorizer)
        return :auto if authorizer.equal?(AUTO_AUTHORIZE)
        return nil if authorizer.nil?

        normalized = authorizer.to_sym
        return normalized if %i[pundit cancancan].include?(normalized)

        raise ArgumentError, "Invalid `authorize_with:` #{authorizer.inspect}. Use :pundit, :cancancan, or nil."
      end

      def normalize_turbo_crud_container(container)
        return nil if container.nil?

        normalized = container.to_sym
        return normalized if %i[modal drawer].include?(normalized)

        raise ArgumentError, "Invalid `container:` #{container.inspect}. Use :modal, :drawer, or nil."
      end

      def apply_turbo_crud_model_container_default!(model_class, container)
        defaults = TurboCrud.config.model_defaults.dup
        model_defaults = (defaults[model_class.name] || {}).dup
        model_defaults[:container] = container
        defaults[model_class.name] = model_defaults
        TurboCrud.config.model_defaults = defaults
      end
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
    def turbo_respond(record, list: nil, insert: DEFAULT_OPTION, success_message: nil,
                      failure_status: :unprocessable_entity, redirect_to: nil, replace: :row, row_partial: nil)
      was_new_record = record.new_record?
      operation = was_new_record ? :create : :update
      resolved_insert = insert.equal?(DEFAULT_OPTION) ? turbo_crud_default_insert_for(record) : insert
      resolved_row_partial = row_partial || turbo_crud_default_row_partial_for(record)

      validate_insert_option!(resolved_insert)
      validate_replace_option!(replace)
      validate_list_option!(list, method_name: :turbo_respond) if was_new_record

      if record.save
        instrument_turbo_crud(operation, record: record, success: true, insert: resolved_insert, replace: replace)
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_success_streams(
              record,
              list: list,
              insert: resolved_insert,
              replace: was_new_record ? nil : replace,
              success_message: success_message,
              updating: !was_new_record,
              row_partial: resolved_row_partial
            )
          end
          format.html { redirect_to(redirect_to || record, notice: success_message, allow_other_host: false) }
        end
      else
        instrument_turbo_crud(operation, record: record, success: false, error_count: record.errors.count)
        # 😬 Validation errors. Record said: "Nope. Try again, human."
        respond_to do |format|
          # If record is new, render :new; else render :edit.
          action = record.persisted? ? :edit : :new
          format.turbo_stream { render(**turbo_crud_template_for(action), formats: :html, status: failure_status) }
          format.html { render action, status: failure_status }
        end
      end
    end

    # ------------------------------------------------------------
    # turbo_save (v0.3)
    # ------------------------------------------------------------
    # Convenience wrapper: calls turbo_create or turbo_update.
    def turbo_save(record, list:, insert: DEFAULT_OPTION, success_message: nil,
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
    def turbo_create(record, list:, insert: DEFAULT_OPTION, success_message: nil,
                     failure_status: :unprocessable_entity, redirect_to: nil, row_partial: nil)
      resolved_insert = insert.equal?(DEFAULT_OPTION) ? turbo_crud_default_insert_for(record) : insert
      resolved_row_partial = row_partial || turbo_crud_default_row_partial_for(record)

      validate_list_option!(list, method_name: :turbo_create)
      validate_insert_option!(resolved_insert)

      if record.save
        instrument_turbo_crud(:create, record: record, success: true, insert: resolved_insert)
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_success_streams(
              record,
              list: list,
              insert: resolved_insert,
              replace: nil, # create inserts; we don't replace by default
              success_message: success_message,
              updating: false,
              row_partial: resolved_row_partial
            )
          end
          format.html { redirect_to(redirect_to || record, notice: success_message, allow_other_host: false) }
        end
      else
        instrument_turbo_crud(:create, record: record, success: false, error_count: record.errors.count)
        respond_to do |format|
          format.turbo_stream { render(**turbo_crud_template_for(:new), formats: :html, status: failure_status) }
          format.html { render :new, status: failure_status }
        end
      end
    end

    # ------------------------------------------------------------
    # turbo_update
    # ------------------------------------------------------------
    def turbo_update(record, success_message: nil, failure_status: :unprocessable_entity, redirect_to: nil, replace: :row, row_partial: nil)
      resolved_row_partial = row_partial || turbo_crud_default_row_partial_for(record)
      validate_replace_option!(replace)

      if record.save
        instrument_turbo_crud(:update, record: record, success: true, replace: replace)
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_success_streams(
              record,
              list: nil,
              insert: nil,
              replace: replace,
              success_message: success_message,
              updating: true,
              row_partial: resolved_row_partial
            )
          end
          format.html { redirect_to(redirect_to || record, notice: success_message, allow_other_host: false) }
        end
      else
        instrument_turbo_crud(:update, record: record, success: false, error_count: record.errors.count, replace: replace)
        respond_to do |format|
          format.turbo_stream { render(**turbo_crud_template_for(:edit), formats: :html, status: failure_status) }
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
      instrument_turbo_crud(:destroy, record: record, success: true, destroyed: record.destroyed?)

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
    # 2) "<collection>/row"
    # 3) "<collection>/<element>"   (ex: "posts/post") — common existing Rails partial
    # 4) TurboCrud.config.row_partial (if compatible and not :auto)
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

      candidates << "#{collection}/row"
      candidates << "#{collection}/#{element}"

      config_pref = TurboCrud.config.row_partial
      if config_pref.present? && config_pref.to_sym != :auto
        config_partial = config_pref.to_s
        # Global row_partial can leak across resources (e.g. blogs/blog on nogs).
        # Keep it as a final fallback and only when path shape looks compatible.
        candidates << config_partial if row_partial_compatible_with_record?(config_partial, collection, element)
      end

      candidates.uniq
    end

    def row_partial_compatible_with_record?(partial_path, collection, element)
      basename = File.basename(partial_path)
      dirname = File.dirname(partial_path)

      return true if basename == "row" || basename == element
      return true if dirname == collection || dirname.start_with?("shared")

      false
    end

    def raise_missing_row_partial!(record, preferred:)
      candidates = turbo_row_partial_candidates(record, preferred: preferred)
      instrument_turbo_crud(:row_partial_missing, record: record, success: false, candidates: candidates)
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

    def turbo_crud_template_for(action)
      return { action: action } unless turbo_crud_requested_frame_id == TurboCrud.config.drawer_frame_id

      drawer_variant = "#{action}.drawer"
      template = "#{controller_path}/#{drawer_variant}"
      if lookup_context.exists?(template, [], true)
        return { template: template }
      end

      { action: action }
    end

    def turbo_crud_resource_scope(config)
      scope = config[:scope]
      records =
        case scope
        when nil
          config[:model].all
        when Proc
          instance_exec(&scope)
        else
          scope
        end

      if records.respond_to?(:all) && !records.respond_to?(:to_ary)
        records.all
      else
        records
      end
    end

    def turbo_crud_find_resource_record(config)
      records = turbo_crud_resource_scope(config)
      return records.find(params[:id]) if records.respond_to?(:find)

      config[:model].find(params[:id])
    end

    def turbo_crud_resource_params(config)
      params.require(config[:model].model_name.param_key).permit(*config[:permit])
    end

    def turbo_crud_authorize_resource!(config, action, resource)
      strategy = turbo_crud_authorizer_strategy(config[:authorize_with])

      case strategy
      when nil
        nil
      when :pundit
        unless respond_to?(:authorize, true)
          raise NotImplementedError, "authorize_with: :pundit requires an `authorize` method (include Pundit::Authorization)."
        end
        authorize(resource)
      when :cancancan
        unless respond_to?(:authorize!, true)
          raise NotImplementedError, "authorize_with: :cancancan requires an `authorize!` method (include CanCan::ControllerAdditions)."
        end
        authorize!(action, resource)
      else
        raise ArgumentError, "Unsupported authorizer: #{strategy.inspect}"
      end
    end

    def turbo_crud_authorizer_strategy(config_value)
      return config_value unless config_value == :auto

      # Prefer CanCanCan when both are present to keep behavior deterministic.
      return :cancancan if respond_to?(:authorize!, true)
      return :pundit if respond_to?(:authorize, true)

      nil
    end

    def turbo_crud_requested_frame_id
      helper_frame_id = turbo_frame_request_id if respond_to?(:turbo_frame_request_id, true)

      helper_frame_id || request.headers["Turbo-Frame"] || request.get_header("HTTP_TURBO_FRAME") || params[:turbo_frame]
    end

    # Centralized instrumentation keeps payload shape stable for logs/metrics.
    def instrument_turbo_crud(event, record:, **payload)
      base_payload = {
        controller: self.class.name,
        action: action_name,
        request_format: request.format.to_s,
        model: record.class.name,
        id: record.id,
        persisted: record.persisted?
      }

      ActiveSupport::Notifications.instrument("turbo_crud.#{event}", base_payload.merge(payload))
    end

    def turbo_crud_default_insert_for(record)
      TurboCrud.model_default_for(record, :insert) || TurboCrud.config.default_insert
    end

    def turbo_crud_default_row_partial_for(record)
      TurboCrud.model_default_for(record, :row_partial)
    end
  end
end
