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
  presentationMode: false
  presentationText: ""

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
    # Make sure it's marked with the special REPL class - helps some of our keybindings!
    $(@editorElement).addClass('slime-repl')
    # Clear the REPL
    @clearREPL()
    # Attach event handlers
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

    # Set up up/down arrow previous command cycling. But don't do it
    # if the autocomplete window is active...
    # TODO - should check autocomplete plus's settings and make sure core movements is enabled?
    @subs.add atom.commands.add @editorElement, 'core:move-up': (event) =>
      if not @isAutoCompleteActive()
        @cycleBack()
        event.stopImmediatePropagation()
    @subs.add atom.commands.add @editorElement, 'core:move-down': (event) =>
      if not @isAutoCompleteActive()
        @cycleForward()
        event.stopImmediatePropagation()

    # Add a clear command
    @subs.add atom.commands.add @editorElement, 'slime:clear-repl': (event) =>
      @clearREPL()
    # Add an interrupt command
    @subs.add atom.commands.add @editorElement, 'slime:interrupt-lisp': (event) =>
      if @swank.connected
        @swank.interrupt()


    @subs.add @editor.onDidDestroy =>
      @destroy()

    # Hide the gutter(s)
    # g.hide() for g in @editor.getGutters()

    # @subs.add atom.commands.add 'atom-workspace', 'slime:thingy': =>
    #   point = @ed.getCursorBufferPosition()
    #   pointAbove = new Point(point.row - 1, @ed.lineTextForBufferRow(point.row - 1).length)
    #   @ed.setTextInBufferRange(new Range(pointAbove, pointAbove), "\nmonkus",undo:'skip')
    #   @ed.scrollToBotom()


  isAutoCompleteActive: () ->
    return $(@editorElement).hasClass('autocomplete-active')


  clearREPL: () ->
    @editor.setText @prompt
    @editor.moveToEndOfLine()


  # Adds non-user-inputted text to the REPL
  appendText: (text, colorTags=true) ->
    @inputFromUser = false
    if colorTags
      @editor.insertText("\x1B#{text}\x1B")
    else
      @editor.insertText(text)
    @inputFromUser = true


  appendPresentationMarker: () ->
    @inputFromUser = false
    @editor.insertText("\x1A")
    @inputFromUser = true


  presentationStart: () ->
    @presentationText = ""
    @presentationMode = true

  presentationEnd: () ->
    @presentationMode = false
    @insertObject(@presentationText)

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


  insertObject: (text) ->
    # We need a buffer character... otherwise, the marker we add will overlap
    # the cursor position, which means when we insert text, the marker position
    # will be updated and change, making the block move. We don't want that.
    @appendText(" ", false)
    pos = @editor.getCursorBufferPosition()
    marker = @editor.markBufferPosition([pos.row, pos.column - 1])
    elementContainer = document.createElement('div')
    element = document.createElement('div')
    elementContainer.appendChild(element)
    element.textContent = text
    element.classList.add('slime-object');
    @editor.decorateMarker(marker, {type: 'block', item: elementContainer, position: 'after'})


  setupSwankSubscriptions: () ->
    # On changing package
    @swank.on 'new_package', (pkg) => @setPackage(pkg)

    # On printing text from REPL response
    @swank.on 'print_string', (msg) =>
      @print_string_callback(msg)

    # On printing presentation visualizations (like for results)
    @swank.on 'presentation_start', () =>
      # @appendPresentationMarker()
      @presentationStart()
    @swank.on 'presentation_end', () =>
      # @appendPresentationMarker()
      @presentationEnd()

    # Debug functions
    @swank.on 'debug_setup', (obj) => @createDebugTab(obj)
    @swank.on 'debug_activate', (obj) =>
     # TODO - keep track of differnet levels
     @showDebugTab()
    @swank.on 'debug_return', (obj) =>
      # TODO - keep track of different levels
      @closeDebugTab()


  print_string_callback: (msg) ->
    # Print something to the REPL when the swank server says to.
    # However, we need to make sure we're not interfering with the cursor!
    msg = msg.replace(/\\\"/g, '"')

    # TODO: edge case if cursor elsewhere while printing objects?
    if @presentationMode
      @presentationText += msg
      return

    if @preventUserInput
      # A command is being run, no prompt is in the way - so directly print
      # anything received to the REPL
      @appendText(msg)
    else
      # There's a REPL in the way - so go to the line before the REPL,
      # insert the message, then go back down to the corresponding line in the REPL!
      # But only move the user's cursor back to the REPL line if it was there to
      # begin with, otherwise put it back at it's absolute location.
      p_cursor = @editor.getCursorBufferPosition()
      row_repl = @editor.getLastBufferRow()
      cursor_originally_in_repl = (p_cursor.row == row_repl)
      # Edge case: if the row is the last line, insert a new line right above then continue.
      if row_repl == 0
        @editor.setCursorBufferPosition([0, 0])
        @appendText("\n", colorTags=false)
        row_repl = 1
      # Compute the cursor position to the last character on the line above the REPL (we know it exists!)
      p_before_cursor = Point(row_repl - 1, @editor.lineTextForBufferRow(row_repl - 1).length)
      @editor.setCursorBufferPosition(p_before_cursor, {autoScroll: false})
      @appendText(msg)
      if cursor_originally_in_repl
        # Put back in the REPL (which may now have a different row/line)
        @editor.setCursorBufferPosition([@editor.getLastBufferRow(), p_cursor.column])
      else
        # Put back the cursor where it was
        @editor.setCursorBufferPosition(p_cursor)



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


  destroy: ->
    if @swank.connected
      @closeDebugTab()
      @subs.dispose()
      @swank.quit()
