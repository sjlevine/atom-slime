{View} = require('atom-space-pen-views')

module.exports =
  class StatusView extends View
    @content:->
      @div class:'atom-slime-status inline-block',  =>
        @span class:'highlight', 'Hi there!'

    attach: (@statusBar) ->
      @statusBar.addLeftTile(item: this, priority: 100)

    # Tear down any state and detach
    destroy: ->
      @element.remove()
