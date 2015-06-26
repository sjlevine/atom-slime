{CompositeDisposable, Point, Range} = require 'atom'
AtomSlimeView = require './atom-slime-view'
paredit = require 'paredit.js'
slime = require './slime-functions'
AtomSlimeEditor = require './atom-slime-editor'

module.exports = AtomSlime =
  views: null
  subs: null
  asts: {}
  pkgs: {}

  activate: (state) ->
    console.log("Slime activated")
    @views = new AtomSlimeView(state.viewsState)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subs = new CompositeDisposable
    @ases = new CompositeDisposable

    editor = atom.workspace.getActiveTextEditor()

    # Keep track of all Lisp editors, and when the person stops editing
    # call the callback.
    @subs.add atom.workspace.observeTextEditors (editor) =>
      if editor.getGrammar().name == "Lisp"
        ase = new AtomSlimeEditor(editor, @views.statusView)
        @ases.add ase
      else
        editor.onDidChangeGrammar =>
          if editor.getGrammar().name == "Lisp"
            ase = new AtomSlimeEditor(editor)
            @ases.add ase



  deactivate: ->
    @subs.dispose()
    @ases.dispose()
    @views.destroy()

  serialize: ->
    viewsState: @views.serialize()

  consumeStatusBar: (statusBar) ->
    @views.setStatusBar(statusBar)
