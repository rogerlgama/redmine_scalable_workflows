# frozen_string_literal: true

module RedmineScalableWorkflows
  module WorkflowTransitionPatch
    # Backport da otimização oficial destinada ao Redmine 7.0 (issue #43957).
    # A indexação elimina varreduras repetidas do conjunto completo de regras.
    def replace_transitions(trackers, roles, transitions)
      trackers = Array.wrap(trackers)
      roles = Array.wrap(roles)

      transaction do
        old_status_ids = transitions.keys.map(&:to_i)
        new_status_ids = transitions.values.flat_map { |by_new_status| by_new_status.keys }.map(&:to_i).uniq
        records_by_status_and_scope =
          WorkflowTransition.where(
            tracker_id: trackers.map(&:id),
            role_id: roles.map(&:id),
            old_status_id: old_status_ids,
            new_status_id: new_status_ids
          )
                            .to_a
                            .group_by { |record| [record.old_status_id, record.new_status_id, record.tracker_id, record.role_id] }

        transitions.each do |old_status_id, transitions_by_new_status|
          transitions_by_new_status.each do |new_status_id, transition_by_rule|
            old_status_id = old_status_id.to_i
            new_status_id = new_status_id.to_i

            transition_by_rule.each do |rule, transition|
              trackers.each do |tracker|
                roles.each do |role|
                  key = [old_status_id, new_status_id, tracker.id, role.id]
                  candidates = records_by_status_and_scope[key].to_a.reject(&:destroyed?)
                  candidates =
                    if rule == 'always'
                      candidates.select { |record| !record.author && !record.assignee }
                    else
                      candidates.select { |record| record.author || record.assignee }
                    end

                  candidates.drop(1).each(&:destroy) if candidates.size > 1
                  record = candidates.first

                  if ['1', true].include?(transition)
                    unless record
                      record = WorkflowTransition.new(
                        old_status_id: old_status_id,
                        new_status_id: new_status_id,
                        tracker: tracker,
                        role: role
                      )
                      records_by_status_and_scope[key] ||= []
                      records_by_status_and_scope[key] << record
                    end
                    record.author = true if rule == 'author'
                    record.assignee = true if rule == 'assignee'
                    record.save! if record.changed?
                  elsif record
                    remove_scalable_transition_rule(record, rule)
                  end
                end
              end
            end
          end
        end
      end
    end

    private

    def remove_scalable_transition_rule(record, rule)
      case rule
      when 'always'
        record.destroy!
      when 'author'
        if record.assignee
          record.author = false
          record.save! if record.changed?
        else
          record.destroy!
        end
      when 'assignee'
        if record.author
          record.assignee = false
          record.save! if record.changed?
        else
          record.destroy!
        end
      end
    end
  end
end
