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


  setup: (@swank, @info) ->
    @errorTitle.html @info.title
    @errorType.html @info.type
    level = @info.level
    thread = @info.thread
    @restarts.empty()
    for restart, i in @info.restarts
      @restarts.append $$ ->
        @li class:"", =>
          @button class:'inline-block-tight restart-button btn', restartindex:i, level:level, thread:thread, restart.cmd
          @text restart.description

    this.find('.restart-button').on 'click', (event) =>
      @restart_click_handler event

  restart_click_handler: (event) ->
    restartindex = event.target.getAttribute('restartindex')
    level = event.target.getAttribute('level')
    thread = event.target.getAttribute('thread')
    @swank.debug_invoke_restart(level, restartindex, thread)
