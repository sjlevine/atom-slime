{CompositeDisposable, Point, Range} = require 'atom'
{$, TextEditorView, View} = require 'atom-space-pen-views'
DebuggerView = require './atom-slime-debugger-view'

module.exports =
class REPLView extends View
  pkg: "CL-USER"
  # Keep track of command history, for use with the up/down arrows
  previousCommands: []
  cycleIndex: null

  @content: ->
    @div class: 'panel atom-slime-repl', =>
      @div class: 'atom-slime-resize-handle'
      #@div outlet:'outputContainer', class: 'atom-slime-repl-output', =>
      #  @pre class: "terminal run-command native-key-bindings", tabindex:"-1", outlet: "output"
      @subview 'replView', new TextEditorView()
      @subview 'debugger', new DebuggerView
      #@div class: 'atom-slime-repl-input', =>
      #  @div class: 'atom-slime-repl-prompt', outlet: "prompt", 'CL-USER>'
      #  @subview 'inputText', new TextEditorView(mini: true, placeholderText: 'input your command here')

  initialize: (@swank) ->
    #atom.commands.add @inputText.element,
    #  'core:confirm': =>
    #    @inputCommandHandler()
    #  atom.commands.add @inputText.element, 'core:move-up': => @cycleBack()
    #  atom.commands.add @inputText.element, 'core:move-down': => @cycleForward()
    # Set up resizing
    #@on 'mousedown', '.atom-slime-resize-handle', (e) => @resizeStarted(e)
    # Setup subscriptions to relevant swank events

    @prompt = "PIKE> "

    # Hide the gutter(s)
    @ed = @replView.getModel()
    g.hide() for g in @ed.getGutters()
    @ed.setText(@prompt)

    # Set the grammer to Lisp?

    # Set up some callbacks
    @subs = new CompositeDisposable



    @subs.add atom.commands.add @replView.element, 'core:backspace': (event) =>
      # Check buffer position!
      point = @ed.getCursorBufferPosition()
      if point.column <= @prompt.length or point.row < @ed.getLastBufferRow()
        event.stopImmediatePropagation()

    @subs.add atom.commands.add @replView.element, 'core:delete': (event) =>
      point = @ed.getCursorBufferPosition()
      if point.column < @prompt.length or point.row < @ed.getLastBufferRow()
        event.stopImmediatePropagation()

    @subs.add atom.commands.add @replView.element, 'editor:newline': (event) =>
      point = @ed.getCursorBufferPosition()
      if point.row == @ed.getLastBufferRow()
        @ed.moveToEndOfLine()
        @ed.insertText("\n" + @prompt, undo:'skip')
      event.stopImmediatePropagation()

    @subs.add @ed.onWillInsertText (event) =>
      console.log 'Insert: ' + event.text
      point = @ed.getCursorBufferPosition()
      if point.column < @prompt.length or point.row < @ed.getLastBufferRow()
        event.cancel()

    @subs.add atom.commands.add 'atom-workspace', 'slime:thingy': =>
      point = @ed.getCursorBufferPosition()
      pointAbove = new Point(point.row - 1, @ed.lineTextForBufferRow(point.row - 1).length)
      @ed.setTextInBufferRange(new Range(pointAbove, pointAbove), "\nmonkus",undo:'skip')
      @ed.scrollToBotom()






    @setupSwankSubscriptions()

  inputCommandHandler: () ->
    if @swank.connected
      input = @inputText.getModel().getText().trim()
      # Push this command to the ring if applicable
      if input != '' and @previousCommands[@previousCommands.length - 1] != input
        @previousCommands.push input
      @cycleIndex = @previousCommands.length
      # Evaluate the command
      promise = @swank.eval input, @pkg
      # Until the command is done, grey out the input box
      @prompt.addClass "atom-slime-repl-pending"
      @inputText.css opacity: 0.3
      promise.then =>
        @prompt.removeClass "atom-slime-repl-pending"
        @inputText.css opacity: 1.0
      # Add an entry of the form PACKAGE> CMD, and clear the text box
      @writePrompt(input)
      @inputText.getModel().setText('')

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
      @inputText.getModel().setText('')
    else if index >= 0 and index < @previousCommands.length
      cmd = @previousCommands[index]
      @inputText.getModel().setText(cmd)


  resizeStarted: =>
    $(document).on('mousemove', @resizeTreeView)
    $(document).on('mouseup', @resizeStopped)

  resizeStopped: =>
    $(document).off('mousemove', @resizeTreeView)
    $(document).off('mouseup', @resizeStopped)

  hide: ->
    @panel.hide()

  show: ->
    @panel.show()

  showDebugger: (show) ->
    if show
      @debugger.show()
      @outputContainer.hide()
    else
      @debugger.hide()
      @outputContainer.show()

  resizeTreeView: ({pageY, which}) =>
    return @resizeStopped() unless which is 1
    # TODO - jumps a little at first
    height = $(document.body).height() - pageY
    if height >= 100
      @height(height)

  setupSwankSubscriptions: () ->
    @swank.on 'new_package', (pkg) =>
      @setPackage(pkg)
    @swank.on 'debug_setup', (obj) =>
      @debugger.setup(@swank, obj)
    @swank.on 'debug_activate', (obj) =>
      # TODO - keep track of differnet levels
      @showDebugger true
    @swank.on 'debug_return', (obj) =>
      # TODO - keep track of differnet levels
      @showDebugger false

  setPackage: (pkg) ->
    @pkg = pkg
    @prompt.html pkg + ">"


  scrollToBottom: ->
    @output.scrollTop 10000000


  writePrompt: (text) ->
    @output.append "<span class=\"repl-prompt\">#{@pkg}&gt;</span> #{text}<br/>"
    @scrollToBottom()

  writeSuccess: (text) ->
    @output.append "<span class=\"repl-success\">#{@sanitizeText text}</span>"
    @scrollToBottom()

  sanitizeText: (text) ->
    return text.replace(/</g, '&lt;').replace(/>/g, '&gt;')

  attach: ->
    @panel = atom.workspace.addBottomPanel(item: this, priority: 200, visible: true)

  destroy: ->
    @element.remove()
