REPLView = require './atom-slime-repl-view'
StatusView = require './atom-slime-status-view'
SlimeAutocompleteProvider = require './slime-autocomplete'

module.exports =
class AtomSlimeView
  constructor: (serializedState, @swank) ->
    # Start a status view
    @statusView = new StatusView()

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @statusView?.destroy()
    @destroyRepl()


  destroyRepl: ->
    @repl?.destroy()

  showRepl: ->
      # Start a REPL
      @repl = new REPLView(@swank)
      @repl.attach()
      SlimeAutocompleteProvider.setup @swank, @repl

  getElement: ->
    @element

  setStatusBar: (@statusBar) ->
    @statusView.attach(@statusBar)
