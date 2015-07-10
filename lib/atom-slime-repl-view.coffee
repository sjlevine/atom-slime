{CompositeDisposable, Point, Range} = require 'atom'
{$, TextEditorView, View} = require 'atom-space-pen-views'
DebuggerView = require './atom-slime-debugger-view'

module.exports =
class REPLView

  constructor: (@swank) ->

  attach: () ->
    @subs = new CompositeDisposable


    # Open an editor in a new pane
    atom.workspace.open('/tmp/repl').then (editor) =>
      pane = atom.workspace.getActivePane()
      pane.splitRight({items: [editor]})
