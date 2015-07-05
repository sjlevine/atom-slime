REPLView = require './atom-slime-repl-view'
StatusView = require './atom-slime-status-view'

module.exports =
class AtomSlimeView
  constructor: (serializedState, @swank) ->
    # Start a REPL
    @repl = new REPLView(@swank)
    @repl.attach()
    # Start a status view
    @statusView = new StatusView()

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @statusView.destroy()
    @repl.destroy()

  getElement: ->
    @element

  setStatusBar: (@statusBar) ->
    @statusView.attach(@statusBar)
