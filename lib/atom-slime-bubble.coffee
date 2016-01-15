{$} = require('atom-space-pen-views')
{CompositeDisposable, Range, Point} = require 'atom'
utils = require './utils'

module.exports =
class Bubble
  constructor: (@editor, @refs) ->
    @subs = new CompositeDisposable()
    @linkElements = []
    @createFunctionBubble()

  # Create a bubble element
  createFunctionBubble: () ->
    # Don't bother if there are no suggestions
    return if @refs.length == 0
    # Create the DOM element from the references
    @bubbleElement = $('<div id="bubble-inline">')
    for ref in @refs
      label = ref.label.toLowerCase().replace('\n', '')
      le = $("<bubble-message>")
            .append($('<span class="bubble-message-item">')
              .append($('<bubble-message-line>').html(ref.label.toLowerCase())))
      @bubbleElement.append(le)
      @linkElements.push(le)
    # Create an Atom marker at current cursor position, and decorate it with
    # the DOM element
    @marker = @editor.markBufferPosition(@editor.getCursorBufferPosition())
    @editor.decorateMarker(@marker, {
      type:'overlay',
      item: @bubbleElement[0]
    })
    # Select the first one
    @selIndex = 0
    @updateSelections()

    #@bubbleElement.on('click', =>
    #  console.log "Click")

    # Add subscriptions for important key events, and to close
    @subs.add atom.commands.add(atom.views.getView(atom.workspace.getActiveTextEditor()), 'core:move-down': (event) =>
      @selIndex = (@selIndex + 1) % @refs.length
      @updateSelections()
      event.stopImmediatePropagation()
    )
    @subs.add atom.commands.add(atom.views.getView(atom.workspace.getActiveTextEditor()), 'core:move-up': (event) =>
      @selIndex = (@selIndex - 1) % @refs.length
      @updateSelections()
      event.stopImmediatePropagation()
    )
    @subs.add atom.commands.add(atom.views.getView(atom.workspace.getActiveTextEditor()), 'core:cancel': (event) =>
      @destroy()
    )
    @subs.add atom.commands.add(atom.views.getView(atom.workspace.getActiveTextEditor()), 'editor:newline': (event) =>
      # Confirmed! Open that tab!
      utils.openFileToIndex(@refs[@selIndex].filename, @refs[@selIndex].index)
      @destroy()
      event.stopImmediatePropagation()
    )
    # TODO - better way to handle this? Priorities? If lisp-paredit exists and getss it first, then enter happens
    @subs.add atom.commands.add(atom.views.getView(atom.workspace.getActiveTextEditor()), 'lisp-paredit:newline': (event) =>
      # Confirmed! Open that tab!
      utils.openFileToIndex(@refs[@selIndex].filename, @refs[@selIndex].index)
      @destroy()
      event.stopImmediatePropagation()
    )
    @subs.add @editor.onDidChangeCursorPosition( (event) =>
      @destroy()
    )


  updateSelections: () ->
    for le in @linkElements
      le.removeClass('active')
    @linkElements[@selIndex].addClass('active')


  destroy: () ->
    @marker?.destroy()
    @subs?.dispose()
