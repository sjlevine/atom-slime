{View} = require('atom-space-pen-views')

module.exports =
  class StatusView extends View
    @content:->
      @div class:'inline-block', =>
        @div outlet:'main', 'Hi there'

      console.log this


    message: (msg) =>
      @main.html(msg)

    attach: (@statusBar) ->
      @statusBar.addLeftTile(item: this, priority: 100)

    # Tear down any state and detach
    destroy: ->
      @element.remove()
