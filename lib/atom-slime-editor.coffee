{CompositeDisposable, Point, Range} = require 'atom'
paredit = require 'paredit.js'
slime = require './slime-functions'

module.exports =
class AtomSlimeEditor
  subs: null
  ast: null
  pkg: null
  mouseMoveTimeout: null

  constructor: (@editor, @statusView, @manager) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subs = new CompositeDisposable
    @subs.add editor.onDidStopChanging => @stoppedEditingCallback()
    @subs.add editor.onDidChangeCursorPosition => @cursorMovedCallback()
    @subs.add editor.onDidDestroy => @editorDestroyedCallback()

  dispose: ->
    @subs.dispose()

  stoppedEditingCallback: ->
    # Parse the file and get an abstract syntax tree, also get package
    @ast = paredit.parse(@editor.getText())
    @pkg = slime.getPackage(@ast)

  cursorMovedCallback: ->
    # Implement a small 300ms delay until when we trigger that the cursor has moved
    if @mouseMoveTimeout
      clearTimeout @mouseMoveTimeout
    @mouseMoveTimeout = setTimeout ( => @processCursorMoved()), 310

  processCursorMoved: ->
    mouseMoveTimeout = null
    # Show slime autodocumentation
    # Get the current sexp we're in
    sexp_info = @getCurrentSexp()
    if sexp_info
      sexp = sexp_info.sexp

      promise = @manager.getAutoDoc sexp, @pkg, 29
      if promise
        promise.then (response) => @statusView.message response 
      else
        @statusView.message sexp


  # Return a string of the current sexp the user is in. The "deepest" one.
  # If we're not in one, return null.
  getCurrentSexp: ->
    index = @getCursorIndex()
    text = @editor.getText()
    range = paredit.navigator.sexpRangeExpansion @ast, index, index
    if not range
      return null
    [start, end] = range
    sexp = text[start...end]
    while sexp.charAt(0) != '('
      range = paredit.navigator.sexpRangeExpansion @ast, start, end
      if not range
        return null
      [start, end] = range
      sexp = text[start...end]
    return sexp: sexp, relativeCursor: index - start


  editorDestroyedCallback: ->
    console.log "Closed!"

  getCursorIndex: ->
    point = @editor.getCursors()[0].getBufferPosition()
    range = new Range(new Point(0, 0), point)
    return @editor.getTextInBufferRange(range).length

  convertIndexToPoint: (index) ->
    p = @indexToPoint(index, @editor.getText())
    new Point(p.row, p.column)

  indexToPoint: (index, src) ->
    substr = src.substring(0, index)
    row = (substr.match(/\n/g) || []).length
    lineStart = substr.lastIndexOf("\n") + 1
    column = index - lineStart
    {row: row, column: column}
