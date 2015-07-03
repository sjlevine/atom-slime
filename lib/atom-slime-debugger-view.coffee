{CompositeDisposable} = require 'atom'
{$, $$, TextEditorView, View, SelectListView, ScrollView} = require 'atom-space-pen-views'

module.exports =
class DebuggerView extends ScrollView
  @content: ->
    @div outlet:"main", class:"inset-panel atom-slime-debugger padded", =>
      @h1 outlet:"errorTitle", =>
        @text "arithmetic error DIVISION-BY-ZERO signalled: Operation was /, operands (0 0)."
      @h2 outlet:"errorType", class:"text-subtle", "   [Condition of type DIVISION-BY-ZERO]"
      @h3 "Restarts:"
      @div class:"select-list", =>
        @ol outlet:"restarts", class:'list-group mark-active', =>
          @li class:"", =>
            @button class:"inline-block-tight btn", "Option 1"
            @text "Description of option 1"
          @li class:"", =>
            @button class:"inline-block-tight btn", "Option 2"
            @text "Description of option 2"
          @li class:"", =>
            @button class:"inline-block-tight btn", "Option 3"
            @text "Description of option 3"
          @li class:"", =>
            @button class:"inline-block-tight btn", "Option 3"
            @text "Description of option 3"

      # @h3 "Stack Trace:"
      # @ul class:"list-tree has-collapsable-children", =>
      #   @li class:'list-nested-item', =>
      #     @div class:'list-item', =>
      #       @text 'Function '
      #       @span class:'badge icon icon-file-text', 'Go to file'
      #     @ul class:'list-tree', =>
      #       @li class:'list-nested-item', =>
      #         @div class:'list-item', 'Hi there'

  @setup: (@info) ->
    @errorTitle.innerHTML @info.title
    @errorType.innerHTML @info.type
    @restarts.empty()
    for [restartCmd, restartDesc], i in @info.restarts
      @restarts.append $$ ->
        @li class:"", =>
          @button class:"inline-block-tight btn", restartCmd
          @text restartDesc
          # Bind click handler!


class MySelectListView extends SelectListView
 initialize: ->
   super
   @addClass('overlay from-top')
   @setItems(['Hello', 'World'])
   #@panel ?= atom.workspace.addModalPanel(item: this)
   #@panel.show()
   #@focusFilterEditor()

 viewForItem: (item) ->
   "<li>#{item}</li>"

 confirmed: (item) ->
   console.log("#{item} was selected")

 cancelled: ->
   console.log("This view was cancelled")
