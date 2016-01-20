{CompositeDisposable, Point, Range} = require 'atom'
{$, TextEditorView, View} = require 'atom-space-pen-views'
DebuggerView = require './atom-slime-debugger-view'

module.exports =
class REPLView
  pkg: "CL-USER"
  prompt: "> "
  preventUserInput: false
  inputFromUser: true
  # Keep track of command history, for use with the up/down arrows
  previousCommands: []
  cycleIndex: null

  constructor: (@swank) ->
    @prompt = @pkg + "> "

  attach: () ->
    @subs = new CompositeDisposable
    @setupSwankSubscriptions()
    @createRepl()
    @setupDebugger()


  # Make a new pane / REPL text editor, or find one
  # that already exists
  createRepl: () ->
    @editor = @replPane = null
    editors = atom.workspace.getTextEditors()
    for editor in editors
      if editor.getPath() == '/tmp/repl.lisp-repl'
        # We found the editor! Now search for the pane it's in.
        allPanes = atom.workspace.getPanes()
        for pane in allPanes
          if editor in pane.getItems()
            # Found the pane too!
            @editor = editor
            @replPane = pane
            @editorElement = atom.views.getView(@editor)

    if @editor and @replPane
      @setupRepl()
      return

    # Create a new pane and editor if we didn't find one
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
    @insertPrompt()
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

    # Set up up/down arrow previous command cycling
    @subs.add atom.commands.add @editorElement, 'core:move-up': (event) =>
      @cycleBack()
      event.stopImmediatePropagation()
    @subs.add atom.commands.add @editorElement, 'core:move-down': (event) =>
      @cycleForward()
      event.stopImmediatePropagation()


    @subs.add @editor.onDidDestroy =>
      @closeRepl()

    # Hide the gutter(s)
    # g.hide() for g in @editor.getGutters()

    # @subs.add atom.commands.add 'atom-workspace', 'slime:thingy': =>
    #   point = @ed.getCursorBufferPosition()
    #   pointAbove = new Point(point.row - 1, @ed.lineTextForBufferRow(point.row - 1).length)
    #   @ed.setTextInBufferRange(new Range(pointAbove, pointAbove), "\nmonkus",undo:'skip')
    #   @ed.scrollToBotom()

  # Adds non-user-inputted text to the REPL
  appendText: (text, colorTags=true) ->
    @inputFromUser = false
    if colorTags
      @editor.insertText("\x1B#{text}\x1B")
    else
      @editor.insertText(text)
    @inputFromUser = true

  # Retrieve the string of the user's input
  getUserInput: (text) ->
    lastLine = @editor.lineTextForBufferRow(@editor.getLastBufferRow())
    return lastLine[@prompt.length..]


  handleEnter: (event) ->
    point = @editor.getCursorBufferPosition()
    if point.row == @editor.getLastBufferRow() and !@preventUserInput and @swank.connected
      input = @getUserInput()
      # Push this command to the ring if applicable
      if input != '' and @previousCommands[@previousCommands.length - 1] != input
        @previousCommands.push input
      @cycleIndex = @previousCommands.length

      @preventUserInput = true
      @editor.moveToEndOfLine()
      @appendText("\n",false)
      promise = @swank.eval input, @pkg
      promise.then =>
        @insertPrompt()
        @preventUserInput = false
    # Stop the enter
    event.stopImmediatePropagation()


  insertPrompt: () ->
    @appendText("\n" + @prompt, false)
    # Now, mark it
    row = @editor.getLastBufferRow()
    marker = @editor.markBufferPosition(new Point(row,0))
    @editor.decorateMarker marker, {type:'line',class:'repl-line'}


  setupSwankSubscriptions: () ->
    # On changing package
    @swank.on 'new_package', (pkg) => @setPackage(pkg)

    # On printing text from REPL response
    @swank.on 'presentation_print', (msg) =>
      @appendText msg.replace(/\\\"/g, '"')

    # Debug functions
    @swank.on 'debug_setup', (obj) => @createDebugTab(obj)
    @swank.on 'debug_activate', (obj) =>
     # TODO - keep track of differnet levels
     @showDebugTab()
    @swank.on 'debug_return', (obj) =>
      # TODO - keep track of different levels
      @closeDebugTab()


  cycleBack: () ->
    # Cycle back through command history
    @cycleIndex = @cycleIndex - 1 if @cycleIndex > 0
    @showPreviousCommand(@cycleIndex)


  cycleForward: () ->
    # Cycle forward through command history
    @cycleIndex = @cycleIndex + 1 if @cycleIndex < @previousCommands.length
    @showPreviousCommand(@cycleIndex)


  showPreviousCommand: (index) ->
    if index >= @previousCommands.length
      # Empty it
      @setPromptCommand ''
    else if index >= 0 and index < @previousCommands.length
      cmd = @previousCommands[index]
      @setPromptCommand cmd


  setPromptCommand: (cmd) ->
    # Sets the command at the prompt
    lastrow = @editor.getLastBufferRow()
    lasttext = @editor.lineTextForBufferRow(lastrow)
    range = new Range([lastrow, 0], [lastrow, lasttext.length])
    newtext = "#{@prompt}#{cmd}"
    @editor.setTextInBufferRange(range, newtext, undo:'skip')


  setupDebugger: () ->
    process.nextTick =>
    @subs.add atom.workspace.addOpener (filePath) =>
        if filePath == 'slime://debug'
          return @dbgv
    @subs.add @replPane.onWillDestroyItem (e) =>
      if e.item == @dbgv
        @swank.debug_escape_all()


  createDebugTab: (obj) ->
    @dbgv = new DebuggerView
    @dbgv.setup(@swank, obj)

  showDebugTab: () ->
    @replPane.activate()
    atom.workspace.open('slime://debug').then (d) =>
      # TODO - doesn't work
      #elt = atom.views.getView(d)
      #atom.commands.add elt, 'q': (event) => @closeDebugTab()

  closeDebugTab: () ->
    @replPane.destroyItem(@dbgv)


  # Set the package and prompt
  setPackage: (pkg) ->
    @pkg = pkg
    @prompt = "#{@pkg}> "


  closeRepl: ->
    if @swank.connected
      @closeDebugTab()
      @subs.dispose()
      @swank.quit()
