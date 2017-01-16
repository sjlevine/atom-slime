{CompositeDisposable} = require 'atom'
{$, $$, TextEditorView, View, SelectListView, ScrollView} = require 'atom-space-pen-views'

module.exports =
class ProfilerView extends ScrollView
  @content: ->
    @div outlet:"main", class:"atom-slime-profiler padded", =>
      @h1 outlet:"errorTitle", =>
        @text "Error description"
      @h2 outlet:"errorType", class:"text-subtle", "   Error sub-text"
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


  setup: (@swank) ->
    return

  restart_click_handler: (event) ->
    restartindex = event.target.getAttribute('restartindex')
    level = event.target.getAttribute('level')
    thread = event.target.getAttribute('thread')
    @swank.debug_invoke_restart(level, restartindex, thread)


  getTitle: -> "Profiler"
  getURI: -> "slime://profile"
  isEqual: (other) ->
    other instanceof ProfilerView
