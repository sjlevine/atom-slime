{$, TextEditorView, View} = require 'atom-space-pen-views'

module.exports =
class Dialog extends View
  @content: ({prompt, forpackage} = {}) ->
    @div =>
      @label prompt, class: 'icon', outlet: 'promptText'
      @subview 'miniEditor', new TextEditorView(mini: true)
      @div class: 'error-message', outlet: 'errorMessage'
      if forpackage
        @div =>
          @label "Record most common callers", class: 'input-label', =>
            @input class: 'input-toggle', type: 'checkbox', id: 'profiler-record-callers', checked: true
          @label "Profile methods", style: 'margin-left: 13px', class: 'input-label', =>
            @input class: 'input-toggle', type: 'checkbox', id: 'profiler-profile-methods', checked: true
      @div style: 'text-align:right; display:block; margin-top: 13px', =>
        @button class: 'btn btn-primary icon icon-check', id: 'profileConfirm'
        @button ' X ', class: 'btn btn-error', id: 'profileCancel', style: 'font-weight: bold'

  initialize: ->
    atom.commands.add @element,
      'core:confirm': => @confirm(@miniEditor.getText())
      'core:cancel': => @cancel()
    @miniEditor.getModel().onDidChange => @showError()

  attach: (cb, forpackage) ->
    @callback = cb
    @panel = atom.workspace.addModalPanel(item: this.element)
    @miniEditor.focus()
    @miniEditor.getModel().scrollToCursorPosition()
    @forpackage = forpackage
    @rec_calls = true
    @prof_meth = true
    $('#profileCancel').on 'click', => @close()
    $('#profileConfirm').on 'click', => @confirm(@miniEditor.getText())
    $('#profiler-record-callers').on 'click', => @toggleRecCalls()
    $('#profiler-profile-methods').on 'click', => @toggleProfMeth()

  toggleRecCalls: ->
    @rec_calls = !@rec_calls

  toggleProfMeth: ->
    @prof_meth = !@prof_meth

  close: ->
    panelToDestroy = @panel
    @panel = null
    panelToDestroy?.destroy()
    atom.workspace.getActivePane().activate()

  confirm: (txt) ->
    if @forpackage
      rc = {true: 't', false:'nil'}[@rec_calls]
      pm = {true: 't', false:'nil'}[@prof_meth]
      @callback(txt, rc, pm)
    else
      @callback(txt)
    @close()
    return

  cancel: ->
    @close()

  showError: (message='') ->
    @errorMessage.text(message)
    @flashError() if message
