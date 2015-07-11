{CompositeDisposable, Point, Range} = require 'atom'
{$, TextEditorView, View} = require 'atom-space-pen-views'
DebuggerView = require './atom-slime-debugger-view'

module.exports =
class REPLView
  pkg: "CL-USER"
  prompt: "> "
  preventUserInput: false
  inputFromUser: true

  constructor: (@swank) ->

  attach: () ->
    @subs = new CompositeDisposable
    @setupSwankSubscriptions()
    @createRepl()


  createRepl: () ->
    # Create a new pane
    paneCurrent = atom.workspace.getActivePane()
    @replPane = paneCurrent.splitDown() #.splitRight
    # Open a new REPL there
    @replPane.activate()
    atom.workspace.open('/tmp/repl.lisp-repl').then (editor) =>
      @editor = editor
      @editorElement = atom.views.getView(@editor)
      @setupRepl()

  # Set up the REPL GUI for use
  setupRepl: () ->
    @prompt = @pkg + "> "
    @editor.setText @prompt
    @editor.moveToEndOfLine()
    @subs.add atom.commands.add @editorElement, 'core:backspace': (event) =>
      # Check buffer position!
      point = @editor.getCursorBufferPosition()
      if point.column <= @prompt.length or point.row < @editor.getLastBufferRow()
        event.stopImmediatePropagation()

    @subs.add atom.commands.add @editorElement, 'core:delete': (event) =>
      point = @editor.getCursorBufferPosition()
      if point.column < @prompt.length or point.row < @editor.getLastBufferRow()
        event.stopImmediatePropagation()

    @subs.add atom.commands.add @editorElement, 'core:cut': (event) =>
      # TODO - prevent cutting here. We can make this better.
      event.stopImmediatePropagation()

    # Prevent undo / redo
    @subs.add atom.commands.add @editorElement, 'core:undo': (event) => event.stopImmediatePropagation()
    @subs.add atom.commands.add @editorElement, 'core:redo': (event) => event.stopImmediatePropagation()


    @subs.add atom.commands.add @editorElement, 'editor:newline': (event) => @handleEnter(event)
    @subs.add atom.commands.add @editorElement, 'editor:newline-below': (event) => @handleEnter(event)


    @subs.add @editor.onWillInsertText (event) =>
      #console.log 'Insert: ' + event.text
      # console.log "Insert: #{event.text}"
      point = @editor.getCursorBufferPosition()
      if @inputFromUser and (@preventUserInput or point.column < @prompt.length or point.row < @editor.getLastBufferRow())
        event.cancel()

    # Hide the gutter(s)
    # g.hide() for g in @editor.getGutters()

    # @subs.add atom.commands.add 'atom-workspace', 'slime:thingy': =>
    #   point = @ed.getCursorBufferPosition()
    #   pointAbove = new Point(point.row - 1, @ed.lineTextForBufferRow(point.row - 1).length)
    #   @ed.setTextInBufferRange(new Range(pointAbove, pointAbove), "\nmonkus",undo:'skip')
    #   @ed.scrollToBotom()

  # Adds non-user-inputted text to the REPL
  appendText: (text) ->
    @inputFromUser = false
    @editor.insertText(text)
    @inputFromUser = true

  # Retrieve the string of the user's input
  getUserInput: (text) ->
    lastLine = @editor.lineTextForBufferRow(@editor.getLastBufferRow())
    return lastLine[@prompt.length..]


  handleEnter: (event) ->
    point = @editor.getCursorBufferPosition()
    if point.row == @editor.getLastBufferRow() and !@preventUserInput
      input = @getUserInput()
      @preventUserInput = true
      @appendText("\n")
      promise = @swank.eval input, @pkg
      promise.then =>
        @appendText "\n" + @prompt
        @preventUserInput = false
    # Stop the enter
    event.stopImmediatePropagation()

  setupSwankSubscriptions: () ->
    @swank.on 'new_package', (pkg) => @setPackage(pkg)

    @swank.on 'presentation_print', (msg) =>
      @appendText msg.replace(/\\\"/g, '"')

    # @swank.on 'debug_setup', (obj) => @debugger.setup(@swank, obj)
    # @swank.on 'debug_activate', (obj) =>
    #   # TODO - keep track of differnet levels
    #   @showDebugger true
    # @swank.on 'debug_return', (obj) =>
    #   # TODO - keep track of differnet levels
    #   @showDebugger false

  # Set the package and prompt
  setPackage: (pkg) ->
    @pkg = pkg
    @prompt = "#{@pkg}> "
