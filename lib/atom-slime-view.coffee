REPLView = require './atom-slime-repl-view'
StatusView = require './atom-slime-status-view'

module.exports =
class AtomSlimeView
  constructor: (serializedState) ->
    # Create root element

    # Start a REPL
    @repl = new REPLView()
    @repl.attach()

    # Start a status view
    @statusView = new StatusView()


  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @statusView.destroy()

  getElement: ->
    @element

  setStatusBar: (@statusBar) ->
      @statusView.attach(@statusBar)
