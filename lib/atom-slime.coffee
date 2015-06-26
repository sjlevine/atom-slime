{CompositeDisposable, Point, Range} = require 'atom'
AtomSlimeView = require './atom-slime-view'
paredit = require 'paredit.js'
slime = require './slime-functions'


module.exports = AtomSlime =
  views: null
  subs: null

  activate: (state) ->
    console.log("Slime activated")
    @views = new AtomSlimeView(state.viewsState)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subs = new CompositeDisposable

    editor = atom.workspace.getActiveTextEditor()

    # Keep track of all Lisp editors, and when the person stops editing
    # call the callback.
    @subs.add atom.workspace.observeTextEditors (editor) =>
      if editor.getGrammar().name == "Lisp"
        @subs.add editor.onDidStopChanging =>
          @stoppedEditingCallback(editor)
      else
        editor.onDidChangeGrammar =>
          if editor.getGrammar().name == "Lisp"
            @subs.add editor.onDidStopChanging =>
              @stoppedEditingCallback(editor)


  deactivate: ->
    @subs.dispose()
    @views.destroy()

  serialize: ->
    viewsState: @views.serialize()

  consumeStatusBar: (statusBar) ->
    @views.setStatusBar(statusBar)

  stoppedEditingCallback: (editor) ->
    ast = paredit.parse(editor.getText())
    pkg = slime.getPackage(ast)
    cursorIndex = @getCursorIndex(editor)
    topform = slime.getTopLevelForm(ast, cursorIndex)
    console.log topform

  getCursorIndex: (editor) ->
    point = editor.getCursors()[0].getBufferPosition()
    range = new Range(new Point(0, 0), point)
    return editor.getTextInBufferRange(range).length
