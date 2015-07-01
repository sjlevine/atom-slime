{CompositeDisposable, Point, Range} = require 'atom'
Swank = require 'swank-client-js'
AtomSlimeView = require './atom-slime-view'
paredit = require 'paredit.js'
slime = require './slime-functions'
AtomSlimeEditor = require './atom-slime-editor'
Q = require('q')

module.exports = AtomSlimeManager =
  views: null
  subs: null
  asts: {}
  pkgs: {}
  swank: null

  activate: (state) ->
    console.log("Slime activated")
    @views = new AtomSlimeView(state.viewsState)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subs = new CompositeDisposable
    @ases = new CompositeDisposable

    editor = atom.workspace.getActiveTextEditor()

    @subs.add atom.commands.add 'atom-workspace', 'slime:connect': => @swankConnect()
    @subs.add atom.commands.add 'atom-workspace', 'slime:hide': => @views.repl.hide()
    @subs.add atom.commands.add 'atom-workspace', 'slime:show': => @views.repl.show()

    # Keep track of all Lisp editors, and when the person stops editing
    # call the callback.
    @subs.add atom.workspace.observeTextEditors (editor) =>
      if editor.getGrammar().name == "Lisp"
        ase = new AtomSlimeEditor(editor, @views.statusView, this)
        @ases.add ase
      else
        editor.onDidChangeGrammar =>
          if editor.getGrammar().name == "Lisp"
            ase = new AtomSlimeEditor(editor)
            @ases.add ase

  swankConnect: () ->
    @swank = new Swank.Client("localhost", 4005);
    @swank.on 'disconnect', =>
      console.log "Disconnected!"
    @swank.on 'presentation_print', (msg) =>
      @views.repl.writeSuccess msg.replace(/\\\"/g, '"')
    @views.repl.setSwank(@swank)

    @swank.connect("localhost", 4005).then =>
      console.log "Slime Connected!!"
      return @swank.initialize().then =>
        @views.statusView.message("Slime connected")
        @views.repl.show()


    #  .then ->
    #    return @swank.autodoc("(+ 1 2)", "COMMON-LISP-USER", 2);})


  getAutoDoc: (sexp_string, cursor, pkg) ->
    if @swank
      return @swank.autodoc sexp_string, cursor, pkg

  swankEval: (sexp_string, cursor) ->
    if @swank
      return @swank.eval sexp_string, pkg

  deactivate: ->
    @subs.dispose()
    @ases.dispose()
    @views.destroy()

  serialize: ->
    viewsState: @views.serialize()

  consumeStatusBar: (statusBar) ->
    @views.setStatusBar(statusBar)
