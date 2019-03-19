{CompositeDisposable, Point, Range} = require 'atom'
{$, TextEditorView, View} = require 'atom-space-pen-views'
DebuggerView = require './atom-slime-debugger-view'
paredit = require 'paredit.js'

module.exports =
class REPLView
  pkg: "CL-USER"
  prompt: "> "
  promptMarker: null
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
      if editor.getTitle() == 'repl.lisp-repl'
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
      selections = @editor.getSelectedBufferRanges()
      for selection in selections
        if selection.start.isEqual(selection.end)
          # no selection, need to check that the previous character is backspace-able
          point = selection.start
          if @promptMarker.getBufferRange().containsPoint(point)
            event.stopImmediatePropagation()
            return
        else
          # range selected, need to check that selection is backspace-able
          if @promptMarker.getBufferRange().intersectsWith(selection, true)
            event.stopImmediatePropagation()
            return

    @subs.add atom.commands.add @editorElement, 'core:delete': (event) =>
      selections = @editor.getSelectedBufferRanges()
      for selection in selections
        # need to check that both start and end of selection are valid
        if @promptMarker.getBufferRange().intersectsWith(selection, true)
          event.stopImmediatePropagation()
          return

    @subs.add atom.commands.add @editorElement, 'core:cut': (event) =>
      selections = @editor.getSelectedBufferRanges()
      for selection in selections
        # need to check that both start and end of selection are valid
        if @promptMarker.getBufferRange().intersectsWith(selection, true)
          event.stopImmediatePropagation()
          return

    # Prevent undo / redo
    @subs.add atom.commands.add @editorElement, 'core:undo': (event) => event.stopImmediatePropagation()
    @subs.add atom.commands.add @editorElement, 'core:redo': (event) => event.stopImmediatePropagation()

    @subs.add atom.commands.add @editorElement, 'editor:newline': (event) => @handleEnter(event)
    @subs.add atom.commands.add @editorElement, 'editor:newline-below': (event) => @handleEnter(event)

    @subs.add @editor.onWillInsertText (event) =>
      #console.log 'Insert: ' + event.text
      # console.log "Insert: #{event.text}"
      if @inputFromUser
        if @preventUserInput
          event.cancel()
        points = @editor.getCursorBufferPositions()
        for point in points
          if point.isLessThan(@promptMarker.getBufferRange().end)
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

    # Prevent the "do you want to save?" dialog from popping up when the REPL window is closed.
    # Unfortunately, as per https://discuss.atom.io/t/how-to-disable-do-you-want-to-save-dialog/31373
    # there is no built-in API to do this. As such, we must override an API method to trick
    # Atom into thinking it isn't ever modified.
    @editor.isModified = (() => false)


    # Hide the gutter(s)
    # g.hide() for g in @editor.getGutters()

    # @subs.add atom.commands.add 'atom-workspace', 'slime:thingy': =>
    #   point = @ed.getCursorBufferPosition()
    #   pointAbove = new Point(point.row - 1, @ed.lineTextForBufferRow(point.row - 1).length)
    #   @ed.setTextInBufferRange(new Range(pointAbove, pointAbove), "\nmonkus",undo:'skip')
    #   @ed.scrollToBotom()


  isAutoCompleteActive: () ->
    return $(@editorElement).hasClass('autocomplete-active')

  markPrompt: (promptRange) ->
    range = new Range([0, 0], promptRange.end)
    @promptMarker = @editor.markBufferRange(range, {exclusive: true})
    syntaxRange = new Range(promptRange.start, [promptRange.end.row, promptRange.end.column-1])
    syntaxMarker = @editor.markBufferRange(syntaxRange, {exclusive: true})
    @editor.decorateMarker(syntaxMarker, {type: 'text', class:'syntax--repl-prompt syntax--keyword syntax--control syntax--lisp'})

  clearREPL: () ->
    @editor.setText @prompt
    range = @editor.getBuffer().getRange()
    @markPrompt(range)
    @editor.moveToEndOfLine()

    marker = @editor.markBufferPosition(new Point(0, 0))
    @editor.decorateMarker marker, {type:'line',class:'repl-line'}


  # Adds non-user-inputted text to the REPL
  appendText: (text, colorTags=true) ->
    @inputFromUser = false
    range = @editor.insertText(text, {autoIndent:false,autoIndentNewline:false})
    if colorTags
      marker = @editor.markBufferRange(range, {exclusive: true})
      @editor.decorateMarker(marker, {type: 'text', class:'syntax--string syntax--quoted syntax--double syntax--lisp'})
    @inputFromUser = true

  # Retrieve the string of the user's input
  getUserInput: (text) ->
    lastrow = @editor.getLastBufferRow()
    lasttext = @editor.lineTextForBufferRow(lastrow)
    promptEnd = @promptMarker.getBufferRange().end
    range = new Range(promptEnd, [lastrow, lasttext.length])
    return @editor.getTextInBufferRange(range)


  handleEnter: (event) ->
    if @preventUserInput or !@swank.connected
      # Can't process it right now
      event.stopImmediatePropagation()
      return

    input = @getUserInput()
    ast = paredit.parse(input)
    if ast.errors.length > 0
      # missing ending parenthesis, use default system to add newline
      console.log ast.errors
      return

    # Push this command to the ring if applicable
    if input != '' and @previousCommands[@previousCommands.length - 1] != input
      @previousCommands.push input
    @cycleIndex = @previousCommands.length

    @preventUserInput = true
    @editor.moveToBottom()
    @appendText("\n",false)
    promise = @swank.eval input, @pkg
    promise.then =>
      @insertPrompt()
      @preventUserInput = false

    # Stop enter
    event.stopImmediatePropagation()



  insertPrompt: () ->
    @inputFromUser = false

    @editor.insertText("\n", {autoIndent:false,autoIndentNewline:false})
    range = @editor.insertText(@prompt, {autoIndent:false,autoIndentNewline:false})[0]
    @markPrompt(range)

    # Now, mark it
    marker = @editor.markBufferPosition(range.start)
    @editor.decorateMarker marker, {type:'line',class:'repl-line'}

    @inputFromUser = true


  setupSwankSubscriptions: () ->
    # On changing package
    @swank.on 'new_package', (pkg) => @setPackage(pkg)

    # On printing text from REPL response
    @swank.on 'print_string', (msg) =>
      @print_string_callback(msg)

    # On printing presentation visualizations (like for results)
    @presentation_starts = {}
    @swank.on 'presentation_start', (pid) =>
      @presentation_starts[pid] = @editor.getBuffer().getRange().end
    @swank.on 'presentation_end', (pid) =>
      presentation_end = @editor.getBuffer().getRange().end
      range = new Range(@presentation_starts[pid], presentation_end)
      marker = @editor.markBufferRange(range, {exclusive: true})
      #TODO should this just be syntax--lisp and let the lisp.cson find the best class (otherwise numbers/strings/ect don't get highlighting)
      @editor.decorateMarker(marker, {type: 'text', class:'syntax--variable syntax--other syntax--global syntax--lisp'})
      delete @presentation_starts[pid]

    # Debug functions
    @swank.on 'debug_setup', (obj) => @createDebugTab(obj)
    @swank.on 'debug_activate', (obj) =>
     # TODO - keep track of differnet levels
     @showDebugTab()
    @swank.on 'debug_return', (obj) =>
      # TODO - keep track of different levels
      @closeDebugTab()

    # Profile functions
    @swank.on 'profile_command_complete', (msg) =>
      atom.notifications.addSuccess(msg)


  print_string_callback: (msg) ->
    # Print something to the REPL when the swank server says to.
    # However, we need to make sure we're not interfering with the cursor!
    msg = msg.replace(/\\\"/g, '"')
    if @preventUserInput
      # A command is being run, no prompt is in the way - so directly print
      # anything received to the REPL
      @appendText(msg)
    else
      # There's a REPL in the way - so go to the line before the REPL,
      # insert the message, then go back down to the corresponding line in the REPL!
      # But only move the user's cursor back to the REPL line if it was there to
      # begin with, otherwise put it back at it's absolute location.
      p_cursors = @editor.getCursorBufferPositions()
      original_prompt_end = @promptMarker.getBufferRange().end
      row_repl = original_prompt_end.row
      # Edge case: if the row is the last line, insert a new line right above then continue.
      if row_repl == 0
        @editor.setCursorBufferPosition([0, 0])
        @appendText("\n", colorTags=false)
        row_repl = 1
      # Compute the cursor position to the last character on the line above the REPL (we know it exists!)
      p_before_cursor = Point(row_repl - 1, @editor.lineTextForBufferRow(row_repl - 1).length)
      @editor.setCursorBufferPosition(p_before_cursor, {autoScroll: false})
      @appendText(msg)

      # Map cursors above the REPL to the same spot
      # Map cursors at the REPL based on the change in the prompt's end location
      new_prompt_end = @promptMarker.getBufferRange().end
      row_offset = new_prompt_end.row-original_prompt_end.row
      col_offset = Math.min(new_prompt_end.column-original_prompt_end.column, 0)
      p_cursors = for point in p_cursors
        if point.row < original_prompt_end.row
          point
        else
          [point.row+row_offset, point.column+col_offset]
      @editor.setCursorBufferPosition(p_cursors[0])
      for point in p_cursors[1..]
        @editor.addCursorAtBufferPosition(point)



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
    promptEnd = @promptMarker.getBufferRange().end
    range = new Range(promptEnd, [lastrow, lasttext.length])
    @editor.setTextInBufferRange(range, cmd)
    @editor.getBuffer().groupLastChanges()


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
