{CompositeDisposable} = require 'atom'
{$, $$, TextEditorView, View, SelectListView, ScrollView} = require 'atom-space-pen-views'

module.exports =
class DebuggerView extends ScrollView
  @content: ->
    @div outlet:"main", class:"atom-slime-debugger padded", =>
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
      @h3 "Stack Trace:"
      @ol outlet:"stackTrace", start:"0", =>
        @li class:"", =>
          @text "Description of frame 1"
        @li class:"", =>
          @text "Description of frame 2"
        @li class:"", =>
          @text "Description of frame 3"
      @button outlet:"fullStackTrace", class:"inline-block-tight btn", "Show All Stack Frames"


  setup: (@swank, @info) ->
    @errorTitle.html @info.title
    @errorType.html @info.type
    level = @info.level
    thread = @info.thread
    @active = true

    @restarts.empty()
    for restart, i in @info.restarts
      @restarts.append $$ ->
        @li class:"", =>
          @button class:'inline-block-tight restart-button btn', restartindex:i, level:level, thread:thread, restart.cmd
          @text restart.description

    this.find('.restart-button').on 'click', (event) =>
      @restart_click_handler event

    @render_stack_trace(@info.stack_frames)

    @fullStackTrace.on 'click', (event) =>
      @load_full_stack_trace event

  restart_click_handler: (event) ->
    restartindex = event.target.getAttribute('restartindex')
    level = event.target.getAttribute('level')
    thread = event.target.getAttribute('thread')
    @active = false
    @swank.debug_invoke_restart(level, restartindex, thread)

  load_full_stack_trace: (event) ->
    @fullStackTrace.remove()
    thread = @info.thread
    @swank.debug_get_stack_trace(thread).then (stack_trace) =>
      @info.stack_frame = stack_trace
      @render_stack_trace(stack_trace)

  render_stack_trace: (trace) =>
    @stackTrace.empty()
    for frame, i in trace
      @stackTrace.append $$ ->
        @li class:"", =>
          @text frame.description


  getTitle: -> "Debugger"
  getURI: -> "slime://debug/"+@info.level
  isEqual: (other) ->
    other instanceof DebuggerView and other.info.level == @info.level
