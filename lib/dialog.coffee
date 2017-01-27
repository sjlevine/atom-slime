{$, TextEditorView, View} = require 'atom-space-pen-views'

module.exports =
class Dialog extends View
  @content: ({prompt} = {}) ->
    @div =>
      @label prompt, class: 'icon', outlet: 'promptText'
      @subview 'miniEditor', new TextEditorView(mini: true)
      @div class: 'error-message', outlet: 'errorMessage'

  initialize: ->
    atom.commands.add @element,
      'core:confirm': => @confirm(@miniEditor.getText())
      'core:cancel': => @cancel()
    @miniEditor.on 'blur', => @close() if document.hasFocus()
    @miniEditor.getModel().onDidChange => @showError()

  attach: (cb) ->
    @callback = cb
    @panel = atom.workspace.addModalPanel(item: this.element)
    @miniEditor.focus()
    @miniEditor.getModel().scrollToCursorPosition()

  close: ->
    panelToDestroy = @panel
    @panel = null
    panelToDestroy?.destroy()
    atom.workspace.getActivePane().activate()

  confirm: (txt) ->
    @callback(txt)
    @close()
    return

  cancel: ->
    @close()

  showError: (message='') ->
    @errorMessage.text(message)
    @flashError() if message
