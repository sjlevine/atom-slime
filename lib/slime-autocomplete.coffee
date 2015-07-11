# Implements Slime autocompletion!

module.exports =
  selector: '.source.lisp-repl, .source.lisp'
  disableForSelector: '.comment'

  # This will take priority over the default provider, which has a priority of 0.
  # `excludeLowerPriority` will suppress any providers with a lower priority
  # i.e. The default provider will be suppressed
  inclusionPriority: 1
  excludeLowerPriority: true

  # Required: Return a promise, an array of suggestions, or null.
  getSuggestions: ({editor, bufferPosition, scopeDescriptor, prefix}) ->
    if @swank.connected
      return @swank.autocomplete(prefix, @repl.pkg).then (acs) =>
        return (text:ac for ac in acs)
    else
      return new Promise (resolve) ->
        resolve([])

  # (optional): called _after_ the suggestion `replacementPrefix` is replaced
  # by the suggestion `text` in the buffer
  onDidInsertSuggestion: ({editor, triggerPosition, suggestion}) ->

  # (optional): called when your provider needs to be cleaned up. Unsubscribe
  # from things, kill any processes, etc.
  dispose: ->

  setup: (@swank, @repl) ->
