{View} = require('atom-space-pen-views')

module.exports =
  class StatusView extends View
    @content:->
      @div class:'inline-block', =>
        @div outlet:'main', 'Hi there'


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
          entry.classes.push "highlight"

        if entry.text.charAt(0) == "&"
          entry.classes.push "constant"

      entries[0].classes.push "entity"
      entries[0].classes.push "name"
      entries[0].classes.push "function"

      result = '(' + (('<span class="' + entry.classes.join(' ') + '">' + entry.text + '</span>' for entry in entries).join ' ') + ')'

      # console.log entries
      # console.log result


      # Otherwise, treat it and parse it
      @main.html(result)

    attach: (@statusBar) ->
      @statusBar.addLeftTile(item: this, priority: 100)

    # Tear down any state and detach
    destroy: ->
      @element.remove()
