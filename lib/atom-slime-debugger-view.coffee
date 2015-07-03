{CompositeDisposable} = require 'atom'
{$, $$, TextEditorView, View, SelectListView, ScrollView} = require 'atom-space-pen-views'

module.exports =
class DebuggerView extends ScrollView
  @content: ->
    @div outlet:"main", class:"atom-slime-debugger", =>
      @h1 =>
        @span class:"icon icon-bug", ""
        @text "arithmetic error DIVISION-BY-ZERO signalled"
        @br()
        @text "Operation was /, operands (0 0)."
      @h2 class:"text-subtle", "   [Condition of type DIVISION-BY-ZERO]"
      @h3 "Restarts:"
      @div class:"select-list", =>
        @ol class:'list-group mark-active', =>
          @li class:"", =>
            @button class:"inline-block-tight btn", "Option 1"
            @text "Description of option 1"
          @li class:"", =>
            @button class:"inline-block-tight btn", "Option 2"
            @text "Description of option 2"
          @li class:"", =>
            @button class:"inline-block-tight btn", "Option 3"
            @text "Description of option 3"
      @h3 "Stack Trace:"
      @ul class:"list-tree has-collapsable-children", =>
        @li class:'list-nested-item', =>
          @div class:'list-item', =>
            @text 'Function '
            @span class:'badge icon icon-file-text', 'Go to file'
          @ul class:'list-tree', =>
            @li class:'list-nested-item', =>
              @div class:'list-item', 'Hi there'

  @setup: ->



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
