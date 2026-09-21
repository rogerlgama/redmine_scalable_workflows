# frozen_string_literal: true

require 'set'

module RedmineScalableWorkflows
  module WorkflowsControllerPatch
    def self.prepended(base)
      base.skip_before_action :find_trackers_roles_and_statuses_for_edit, only: [:edit, :update]
      base.before_action :rsw_find_trackers_and_roles, only: [:edit, :update]
    end

    def edit
      prepare_scalable_workflow_editor
      render template: 'redmine_scalable_workflows/edit'
    end

    def scalable_statuses
      query = params[:q].to_s.strip
      results = []

      if params[:axis] == 'source' && query.present? &&
         I18n.transliterate(l(:label_issue_new)).downcase.include?(I18n.transliterate(query).downcase)
        results << {id: 0, name: l(:label_issue_new)}
      end

      if query.present?
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"
        scope = IssueStatus.where('LOWER(name) LIKE ?', pattern)
        results.concat(scope.sorted.limit(20).map { |status| {id: status.id, name: status.name} })
      end

      render json: {results: results.uniq { |item| item[:id] }}
    end

    def update
      return super unless params[:scalable_editor] == '1'

      source_ids = rsw_axis_ids(:source_status_ids, allow_zero: true)
      destination_ids = rsw_axis_ids(:destination_status_ids)

      if @roles && @trackers && rsw_valid_axis_ids?(source_ids, destination_ids)
        transitions = scalable_transition_changes
        WorkflowTransition.replace_transitions(@trackers, @roles, transitions) if transitions.present?
        flash[:notice] = l(:notice_successful_update)
      else
        flash[:error] = l(:rsw_invalid_selection)
      end

      redirect_to edit_workflows_path(
        role_id: Array.wrap(params[:role_id]),
        tracker_id: Array.wrap(params[:tracker_id]),
        source_status_ids: source_ids,
        destination_status_ids: destination_ids,
        axes_initialized: '1'
      )
    end

    private

    def prepare_scalable_workflow_editor
      @rsw_source_status_ids = rsw_axis_ids(:source_status_ids, allow_zero: true)
      @rsw_destination_status_ids = rsw_axis_ids(:destination_status_ids)
      load_existing_scalable_workflow if should_load_existing_scalable_workflow?
      synchronize_scalable_status_axes
      @rsw_valid_axes = rsw_valid_axis_ids?(@rsw_source_status_ids, @rsw_destination_status_ids)
      @rsw_transition_states = {}
      @rsw_role_options = [{id: 'all', name: l(:label_all)}] + Role.sorted.select(&:consider_workflow?).map { |role| {id: role.id, name: role.name} }
      @rsw_tracker_options = [{id: 'all', name: l(:label_all)}] + Tracker.sorted.map { |tracker| {id: tracker.id, name: tracker.name} }

      selected_status_ids = (@rsw_source_status_ids + @rsw_destination_status_ids).reject { |id| id.zero? }
      selected_statuses = IssueStatus.where(id: selected_status_ids).index_by(&:id)
      @rsw_sources = @rsw_source_status_ids.filter_map do |id|
        id.zero? ? {id: 0, name: l(:label_issue_new)} : selected_statuses[id]&.then { |status| {id: status.id, name: status.name} }
      end
      @rsw_destinations = @rsw_destination_status_ids.filter_map do |id|
        selected_statuses[id]&.then { |status| {id: status.id, name: status.name} }
      end

      return unless @roles && @trackers && @rsw_valid_axes && @rsw_sources.present? && @rsw_destinations.present?

      records = WorkflowTransition.where(
        tracker_id: @trackers.map(&:id),
        role_id: @roles.map(&:id),
        old_status_id: @rsw_source_status_ids,
        new_status_id: @rsw_destination_status_ids
      ).select(:tracker_id, :role_id, :old_status_id, :new_status_id, :author, :assignee)

      total_scopes = @trackers.size * @roles.size
      scopes = Hash.new { |hash, key| hash[key] = Set.new }

      records.each do |record|
        scope = [record.tracker_id, record.role_id]
        if !record.author && !record.assignee
          scopes[[record.old_status_id, record.new_status_id, 'always']] << scope
        end
        scopes[[record.old_status_id, record.new_status_id, 'author']] << scope if record.author
        scopes[[record.old_status_id, record.new_status_id, 'assignee']] << scope if record.assignee
      end

      @rsw_source_status_ids.product(@rsw_destination_status_ids).each do |source_id, destination_id|
        %w[always author assignee].each do |rule|
          count = scopes[[source_id, destination_id, rule]].size
          @rsw_transition_states[[source_id, destination_id, rule]] = state_for_scalable_count(count, total_scopes)
        end
      end
    end

    def scalable_transition_changes
      source_ids = rsw_axis_ids(:source_status_ids, allow_zero: true).to_set
      destination_ids = rsw_axis_ids(:destination_status_ids).to_set
      submitted = params[:transitions].respond_to?(:to_unsafe_h) ? params[:transitions].to_unsafe_h : params[:transitions].to_h
      changes = {}

      submitted.each do |old_status_id, destinations|
        source_id = old_status_id.to_i
        next unless source_ids.include?(source_id)

        destinations.to_h.each do |new_status_id, rules|
          destination_id = new_status_id.to_i
          next unless destination_ids.include?(destination_id)
          next if source_id.positive? && source_id == destination_id

          clean_rules = rules.to_h.slice('always', 'author', 'assignee')
                             .select { |_rule, value| %w[0 1].include?(value.to_s) }
          changes[source_id.to_s] ||= {}
          changes[source_id.to_s][destination_id.to_s] = clean_rules if clean_rules.present?
        end
      end

      changes
    end

    def rsw_find_trackers_and_roles
      submitted_roles = Array.wrap(params[:role_id]).map(&:to_s)
      submitted_trackers = Array.wrap(params[:tracker_id]).map(&:to_s)
      all_roles = Role.sorted.select(&:consider_workflow?)
      all_trackers = Tracker.sorted.to_a

      if submitted_roles.include?('all')
        @roles = all_roles.presence
        @rsw_selected_roles = [{id: 'all', name: l(:label_all)}]
      else
        role_ids = submitted_roles.filter_map { |id| Integer(id, exception: false) }.uniq
        @roles = Role.where(id: role_ids).to_a.select(&:consider_workflow?).presence
        @rsw_selected_roles = Array.wrap(@roles).map { |role| {id: role.id, name: role.name} }
      end

      if submitted_trackers.include?('all')
        @trackers = all_trackers.presence
        @rsw_selected_trackers = [{id: 'all', name: l(:label_all)}]
      else
        tracker_ids = submitted_trackers.filter_map { |id| Integer(id, exception: false) }.uniq
        @trackers = Tracker.where(id: tracker_ids).to_a.presence
        @rsw_selected_trackers = Array.wrap(@trackers).map { |tracker| {id: tracker.id, name: tracker.name} }
      end
    end

    def should_load_existing_scalable_workflow?
      params[:axes_initialized] != '1' && @roles.present? && @trackers&.one?
    end

    def load_existing_scalable_workflow
      # The statuses shown by Redmine belong to the tracker's workflow as a
      # whole, not only to the selected role. This is especially important for
      # a new role: it has no transitions yet, but must still receive the
      # existing tracker matrix so the administrator can grant permissions
      # without rebuilding the workflow status by status.
      pairs = WorkflowTransition.where(tracker_id: @trackers.first.id)
                                .distinct.pluck(:old_status_id, :new_status_id)
      return if pairs.empty?

      status_ids = pairs.flatten.compact.map(&:to_i).select(&:positive?).uniq
      has_new_issue = pairs.any? { |old_status_id, _new_status_id| old_status_id.to_i.zero? }
      @rsw_source_status_ids = (has_new_issue ? [0] : []) + status_ids
      @rsw_destination_status_ids = status_ids
    end

    def synchronize_scalable_status_axes
      status_ids = (@rsw_source_status_ids + @rsw_destination_status_ids).select(&:positive?).uniq
      has_new_issue = @rsw_source_status_ids.include?(0)
      @rsw_source_status_ids = (has_new_issue ? [0] : []) + status_ids
      @rsw_destination_status_ids = status_ids
    end

    def rsw_axis_ids(key, allow_zero: false)
      Array.wrap(params[key]).filter_map { |id| Integer(id, exception: false) }
           .select { |id| id.positive? || (allow_zero && id.zero?) }.uniq
    end

    def rsw_valid_axis_ids?(source_ids, destination_ids)
      ids = (source_ids + destination_ids).reject { |id| id.zero? }.uniq
      ids.empty? || IssueStatus.where(id: ids).count == ids.size
    end

    def state_for_scalable_count(count, total)
      return '0' if count.zero?
      return '1' if count == total

      'no_change'
    end

  end
end
