# frozen_string_literal: true

require 'active_support/dependencies'

module RedmineScalableWorkflows
  module PatchLoader
    module_function

    def install!
      load_redmine_dependencies
      load_plugin_patches
      patch_controller
      patch_transition_model
      Rails.logger.info '[redmine_scalable_workflows] Editor esparso ativado no WorkflowsController'
    rescue StandardError => error
      Rails.logger.error "[redmine_scalable_workflows] Falha ao ativar: #{error.class}: #{error.message}"
      raise
    end

    def load_redmine_dependencies
      require_dependency Rails.root.join('app/controllers/workflows_controller').to_s
      require_dependency Rails.root.join('app/models/workflow_transition').to_s
    end

    def load_plugin_patches
      require_dependency File.expand_path('workflows_controller_patch', __dir__)
      require_dependency File.expand_path('workflow_transition_patch', __dir__)
    end

    def patch_controller
      patch = RedmineScalableWorkflows::WorkflowsControllerPatch
      WorkflowsController.prepend(patch) unless WorkflowsController.ancestors.include?(patch)
    end

    def patch_transition_model
      patch = RedmineScalableWorkflows::WorkflowTransitionPatch
      singleton = WorkflowTransition.singleton_class
      singleton.prepend(patch) unless singleton.ancestors.include?(patch)
    end
  end
end
