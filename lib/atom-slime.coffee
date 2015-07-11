{CompositeDisposable, Point, Range} = require 'atom'
Swank = require 'swank-client-js'
AtomSlimeView = require './atom-slime-view'
paredit = require 'paredit.js'
slime = require './slime-functions'
AtomSlimeEditor = require './atom-slime-editor'
SlimeAutocompleteProvider = require './slime-autocomplete'

module.exports = AtomSlimeManager =
  views: null
  subs: null
  asts: {}
  pkgs: {}

  activate: (state) ->
    # Setup a swank client instance
    @setupSwank()
    @views = new AtomSlimeView(state.viewsState, @swank)
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subs = new CompositeDisposable
    @ases = new CompositeDisposable

    # Setup connections
    @subs.add atom.commands.add 'atom-workspace', 'slime:connect': => @swankConnect()
    @subs.add atom.commands.add 'atom-workspace', 'slime:hide': => @views.repl.hide()
    @subs.add atom.commands.add 'atom-workspace', 'slime:show': => @views.repl.show()
    #@subs.add atom.commands.add 'atom-workspace', 'slime:show-debugger': => @views.repl.showDebugger true
    #@subs.add atom.commands.add 'atom-workspace', 'slime:hide-debugger': => @views.repl.showDebugger false
    # Keep track of all Lisp editors
    @subs.add atom.workspace.observeTextEditors (editor) =>
      if editor.getGrammar().name == "Lisp"
        ase = new AtomSlimeEditor(editor, @views.statusView, @swank)
        @ases.add ase
      else
        editor.onDidChangeGrammar =>
          if editor.getGrammar().name == "Lisp"
            ase = new AtomSlimeEditor(editor, @views.statusView, @swank)
            @ases.add ase

    SlimeAutocompleteProvider.setup @swank, @views.repl

  # Sets up a swank client but does not connect
  setupSwank: () ->
    @swank = new Swank.Client("localhost", 4005);
    @swank.on 'disconnect', =>
      console.log "Disconnected!"
    # @swank.on 'presentation_print', (msg) =>
    #   @views.repl.writeSuccess msg.replace(/\\\"/g, '"')

  # Connect the swank client
  swankConnect: () ->
    @swank.connect().then =>
      console.log "Slime Connected!!"
      return @swank.initialize().then =>
        @views.statusView.message("Slime connected")
        @views.repl.show()

  deactivate: ->
    @subs.dispose()
    @ases.dispose()
    @views.destroy()

  serialize: ->
    viewsState: @views.serialize()

  consumeStatusBar: (statusBar) ->
    @views.setStatusBar(statusBar)

  provideSlimeAutocomplete: -> SlimeAutocompleteProvider
