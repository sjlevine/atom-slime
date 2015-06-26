REPLView = require './atom-slime-repl-view'
StatusView = require './atom-slime-status-view'

module.exports =
class AtomSlimeView
  constructor: (serializedState) ->
    # Create root element

    # Start a REPL
    #@repl = new REPLView()

    # Start a status view
    @status = new StatusView()


  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @status.destroy()

  getElement: ->
    @element

  setStatusBar: (@statusBar) ->
      @status.attach(@statusBar)
