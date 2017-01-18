{CompositeDisposable} = require 'atom'
{$, $$, TextEditorView, View, SelectListView, ScrollView} = require 'atom-space-pen-views'

module.exports =
class ProfilerView extends ScrollView
  @content: ->
    @div outlet:"main", class:"atom-slime-profiler padded", =>
      @h1 outlet:"profiler-toggle-func-title", =>
          @text "Toggle profiling of a function"
      @input outlet:"profiler-function-input", class:"input-text", type:"text", placeholder:"<function name>"
      @h1 outlet:"profiler-package-title", =>
          @text "Profile all functions in a package"
      @input outlet:"profiler-package-input", class:"input-text", type:"text", placeholder:"<package name>"
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
    this.find('#profiler-unprofile-button').on 'click', (event) =>
      @unprofile_click_handler event
    this.find('#profiler-report-button').on 'click', (event) =>
      @report_click_handler event
    this.find('#profiler-reset-button').on 'click', (event) =>
      @reset_click_handler event
    return

  unprofile_click_handler: (event) ->
    atom.notifications.addSuccess('Unprofiling all functions', detail:'Coming soon...')

  report_click_handler: (event) ->
    atom.notifications.addSuccess('Showing profiler report', detail:'Coming soon...')

  reset_click_handler: (event) ->
    atom.notifications.addSuccess('Reseting the profiler data', detail:'Coming soon...')


  getTitle: -> "Profiler"
  getURI: -> "slime://profile"
  isEqual: (other) ->
    other instanceof ProfilerView
