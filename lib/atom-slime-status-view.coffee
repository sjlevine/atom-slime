{$} = require('atom-space-pen-views')

module.exports =
  class StatusView

    constructor: ->
      @content = $('<div>').addClass('inline-block')
      @content.css({'max-width':'100vw'}) # Prevent from getting cut off
      @main = $('<div>').text('Slime not connected.')
      @content.append(@main)


    message: (msg) =>
      @main.html(msg)

    # Display prettily-formatted autodocumentation information
    displayAutoDoc: (msg) =>
      # msg is a paredit-parsed structure
      if msg.type == 'symbol'
        # It's probably the :not-available symbol, so clear the autodoc
        @message ""
        return

      doc = msg.source[2...-2] # Cut off being / end quotes and parens
      currentSymbol = doc.match /\S+(?=\s+<===)/g
      if currentSymbol != null
        currentSymbol = currentSymbol[0]

      fields = doc.split /\s+/g
      entries = ({classes:[], text:field} for field in fields when field != "===>" and field != "<===")
      for entry in entries
        if entry.text == currentSymbol
          entry.classes.push "slime-keyword-highlight"

        if entry.text.charAt(0) == "&"
          entry.classes.push "constant"

      entries[0].classes.push "entity"
      entries[0].classes.push "name"
      entries[0].classes.push "function"
      result = '<div style="font-family: monospace;">(' + (('<span class="' + entry.classes.join(' ') + '">' + entry.text + '</span>' for entry in entries).join ' ') + ')</div>'
      # Otherwise, treat it and parse it
      @main.html(result)

    attach: (@statusBar) ->
      @statusBar.addLeftTile(item: @content[0], priority: 100)

    # Tear down any state and detach
    destroy: ->
      @content.remove()
