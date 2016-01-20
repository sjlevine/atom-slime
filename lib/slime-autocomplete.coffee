# Implements Slime autocompletion!
utils = require './utils'

module.exports =
  selector: '.source.lisp-repl, .source.lisp'
  disableForSelector: '.comment'
  disabled: false

  # This will take priority over the default provider, which has a priority of 0.
  # `excludeLowerPriority` will suppress any providers with a lower priority
  # i.e. The default provider will be suppressed
  inclusionPriority: 1
  excludeLowerPriority: true

  # Required: Return a promise, an array of suggestions, or null.
  getSuggestions: ({editor, bufferPosition}) ->
    prefix = @getPrefix(editor, bufferPosition)
    console.log prefix
    if @swank?.connected and !@disabled and prefix != ""
      return @swank.autocomplete(prefix, @repl.pkg).then (acs) =>
        return ({text: ac, replacementPrefix: prefix} for ac in acs)
    else
      return new Promise (resolve) ->
        resolve([])


  # A better prefix for Lisp
  getPrefix: (editor, bufferPosition) ->
    # Get the text for the line up to the triggered buffer position
    line = editor.getTextInRange([[bufferPosition.row, @repl.prompt.length], bufferPosition])
    # Match the regex to the line, and return the match
    matches = line.match(utils.lispWordRegex)
    console.log matches
    return matches?[matches?.length - 1] or ''

  # (optional): called _after_ the suggestion `replacementPrefix` is replaced
  # by the suggestion `text` in the buffer
  onDidInsertSuggestion: ({editor, triggerPosition, suggestion}) ->

  # (optional): called when your provider needs to be cleaned up. Unsubscribe
  # from things, kill any processes, etc.
  dispose: ->

  setup: (@swank, @repl) ->

  disable: () -> @disabled = true
  enable: () -> @disabled = false
