# frozen_string_literal: true

Redmine::Plugin.register :redmine_scalable_workflows do
  name 'Fluxo de Trabalho'
  author 'Roger Gama'
  description 'Editor progressivo e otimização de desempenho para fluxos com grande quantidade de situações.'
  version '0.4.14'
  url 'https://github.com/rogerlgama/redmine_scalable_workflows'
  requires_redmine version_or_higher: '6.0.0'
end

require_relative 'lib/redmine_scalable_workflows/patch_loader'

# Aplica imediatamente em produção e reaplica após recargas de classes em desenvolvimento.
RedmineScalableWorkflows::PatchLoader.install!
Rails.application.config.to_prepare do
  RedmineScalableWorkflows::PatchLoader.install!
end
