{CompositeDisposable} = require 'atom'
{$, $$, TextEditorView, View, SelectListView, ScrollView} = require 'atom-space-pen-views'

module.exports =
class ProfilerView extends ScrollView
  @content: ->
    @div outlet:"main", class:"atom-slime-profiler padded", =>
      @h1 outlet:"profiler-toggle-func-title", =>
          @text "Toggle profiling of a function"
      @input id:"profiler-function-input", outlet:"profiler-function-input", class:"input-text", type:"text", placeholder:"Input <function name>, then hit enter"
      @h1 outlet:"profiler-package-title", =>
          @text "Profile all functions in a package"
      @input id:"profiler-package-input", outlet:"profiler-package-input", class:"input-text", type:"text", placeholder:"Input <package name>, then hit enter"
      @h1 outlet:"commands-title", =>
          @text "Profiler Commands"
      @div class:"select-list", =>
        @ol outlet:"profiler-command-list", class:'list-group', =>
          @li class:"", =>
            @button id:"profiler-unprofile-button", class:"inline-block-tight btn btn-lg", "Unprofile"
            @text "Unprofile all functions"
          @li class:"", =>
            @button id:"profiler-report-button", class:"inline-block-tight btn btn-lg", "Report"
            @text "Report the profiler data"
          @li class:"", =>
            @button id:"profiler-reset-button", class:"inline-block-tight btn btn-lg", "Reset"
            @text "Reset the profiler data"

  setup: (@swank) ->
    this.find('#profiler-function-input').on 'keydown', (event) =>
      @profile_function_click_handler event
    this.find('#profiler-unprofile-button').on 'click', (event) =>
      @unprofile_click_handler event
    this.find('#profiler-report-button').on 'click', (event) =>
      @report_click_handler event
    this.find('#profiler-reset-button').on 'click', (event) =>
      @reset_click_handler event
    return

  unprofile_click_handler: (event) ->
    @swank.profile_invoke_unprofile_all()

  report_click_handler: (event) ->
    atom.notifications.addSuccess('Showing profiler report', detail:'Coming soon...')

  reset_click_handler: (event) ->
    @swank.profile_invoke_reset()

  profile_function_click_handler: (event) ->
    if event.which is 13
      @swank.profile_invoke_toggle_function(this.find('#profiler-function-input').val())


  getTitle: -> "Profiler"
  getURI: -> "slime://profile"
  isEqual: (other) ->
    other instanceof ProfilerView
