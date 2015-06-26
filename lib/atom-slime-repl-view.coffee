{CompositeDisposable} = require 'atom'

module.exports =
class REPLView
  constructor: (serializedState) ->
    # Open a new window

    @subscriptions = new CompositeDisposable
    atom.workspace.open('SLIME REPL', split:'right').done (editor) =>
        @subscriptions.add editor.onWillInsertText(@callback_insert_text)


  # Called whenever text is about to be inserted into the text editor
  callback_insert_text: (event) ->
    console.log "Inserting " + event.text

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @element.remove()
