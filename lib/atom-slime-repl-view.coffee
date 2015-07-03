{CompositeDisposable} = require 'atom'
{$, TextEditorView, View} = require 'atom-space-pen-views'
DebuggerView = require './atom-slime-debugger-view'

module.exports =
class REPLView extends View
  swank: null
  pkg: "CL-USER"

  @content: ->
    @div class: 'panel atom-slime-repl', =>
      @div class: 'atom-slime-resize-handle'
      @div outlet:'outputContainer', class: 'atom-slime-repl-output', =>
        @pre class: "terminal", outlet: "output"
      @subview 'debugger', new DebuggerView
      @div class: 'atom-slime-repl-input', =>
        @div class: 'atom-slime-repl-prompt', outlet: "prompt", 'CL-USER>'
        @subview 'inputText', new TextEditorView(mini: true, placeholderText: 'input your command here')

  initialize: ->
    atom.commands.add @inputText.element,
      'core:confirm': =>
        if @swank
          input = @inputText.getModel().getText()
          promise = @swank.eval input, @pkg
          promise.then =>
            @prompt.removeClass "atom-slime-repl-pending"
            @inputText.css opacity: 1.0

          @prompt.addClass "atom-slime-repl-pending"
          @inputText.css opacity: 0.3
          @writePrompt(input)
          @inputText.getModel().setText('')

    # Set up resizing
    @on 'mousedown', '.atom-slime-resize-handle', (e) => @resizeStarted(e)

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

  setSwank: (@swank) ->
    @swank.on 'new_package', (pkg) =>
      @setPackage(pkg)

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
