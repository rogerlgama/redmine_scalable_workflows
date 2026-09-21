# Fluxo de Trabalho Escalável para Redmine

Plugin que substitui a matriz completa de transições por um editor progressivo e esparso, destinado a instalações com muitas situações de tarefa.

## Recursos

- Seletores pesquisáveis e múltiplos de papéis e tipos de tarefa.
- Opção pesquisável **Todos** para papéis e tipos.
- Carregamento automático das transições existentes ao editar um tipo e um ou vários papéis.
- Pesquisa de situações sob demanda, sem carregar toda a lista antecipadamente.
- Matriz compacta formada somente pelas situações escolhidas pelo administrador.
- Checkboxes de três estados, preservando o comportamento **Não alterar** do Redmine em edições de vários escopos.
- Marcação ou desmarcação em lote por linha de origem ou coluna de destino.
- Suporte às regras padrão, somente autor e somente responsável.
- Atualizações parciais sem sobrescrever transições não editadas.
- Leituras e gravações direcionadas às situações de origem e destino selecionadas.
- Otimização de `WorkflowTransition.replace_transitions` planejada para compatibilidade com Redmine 7.
- Nenhuma migration e nenhuma alteração em arquivos do núcleo do Redmine.

Ao remover o plugin, o editor nativo retorna sem excluir as transições salvas.

## Requisitos e compatibilidade

- Redmine 6.0 ou superior.
- Ruby e Rails compatíveis com a versão instalada do Redmine.

A versão atual foi validada estruturalmente contra o código-fonte do Redmine 6.0.6.

## Instalação

1. Copie o plugin para `REDMINE_ROOT/plugins/redmine_scalable_workflows`.
2. Reinicie o Redmine.
3. Acesse **Administração → Fluxo de trabalho**.

Não há migrations de banco.

## Uso

1. Selecione um ou mais papéis.
2. Selecione um tipo de tarefa.
3. Use **Editar** para carregar as transições existentes.
4. Pesquise e adicione somente as situações necessárias à alteração.
5. Edite as transições na matriz compacta e salve.

O estado indeterminado do checkbox indica que os valores existentes diferem entre os escopos selecionados. Eles permanecem inalterados até que o administrador marque ou desmarque explicitamente a opção.

## Modelo de desempenho

O editor nativo renderiza toda a matriz situação por situação. Este plugin pesquisa situações sob demanda e monta somente o subconjunto selecionado. Na atualização, envia e consulta apenas as origens e destinos afetados, reduzindo o trabalho do navegador e do servidor em catálogos extensos.

## Atualização e remoção

Para atualizar, substitua os arquivos mantendo o nome `redmine_scalable_workflows` e reinicie o Redmine. Para remover, exclua a pasta e reinicie. O editor nativo e as transições já salvas permanecem disponíveis.

## Situação dos testes

O pacote foi validado estruturalmente contra Redmine 6.0.6. Ainda não contém testes automatizados; antes da produção, valide em homologação a seleção de papéis e tipos, estados mistos, salvamento e retorno ao editor nativo.

## Licença e autor

Licenciado sob GNU GPL versão 2 ou posterior (`GPL-2.0-or-later`). Consulte [LICENSE](LICENSE).

Autor: Roger Gama.
