{Range, Point} = require 'atom'

module.exports =
  indexToPoint: (index, src) ->
    substr = src.substring(0, index)
    row = (substr.match(/\n/g) || []).length
    lineStart = substr.lastIndexOf("\n") + 1
    column = index - lineStart
    {row: row, column: column}

  convertPointToIndex: (point, editor) ->
    range = new Range(new Point(0, 0), point)
    editor.getTextInBufferRange(range).length

  convertIndexToPoint: (index, editor) ->
    p = @indexToPoint(index, editor.getText())
    new Point(p.row, p.column)

  openFileToIndex: (file, index) ->
    # Opens the given file (if it isn't already), and moves
    # the cursor to the desired position
    atom.workspace.open(file, {}).then (editor) =>
      point = @convertIndexToPoint(index, editor)
      editor.setCursorBufferPosition(point)
