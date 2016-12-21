{CompositeDisposable, Point, Range} = require 'atom'
{$, TextEditorView, View} = require 'atom-space-pen-views'
DebuggerView = require './atom-slime-debugger-view'

module.exports =
class REPLView
  pkg: "CL-USER"
  prompt: "> "
  preventUserInput: false
  inputFromUser: true
  # Keep track of command history, for use with the up/down arrows
  previousCommands: []
  cycleIndex: null
  presentationMode: false
  presentationText: ""

  constructor: (@swank) ->
    @prompt = @pkg + "> "

  attach: () ->
    @subs = new CompositeDisposable
    @setupSwankSubscriptions()
    @createRepl()
    @setupDebugger()


  # Make a new pane / REPL text editor, or find one
  # that already exists
  createRepl: () ->
    @editor = @replPane = null
    editors = atom.workspace.getTextEditors()
    for editor in editors
      if editor.getTitle() == 'repl.lisp-repl'
        # We found the editor! Now search for the pane it's in.
        allPanes = atom.workspace.getPanes()
        for pane in allPanes
          if editor in pane.getItems()
            # Found the pane too!
            @editor = editor
            @replPane = pane
            @editorElement = atom.views.getView(@editor)

    if @editor and @replPane
      @setupRepl()
      return

    # Create a new pane and editor if we didn't find one
    paneCurrent = atom.workspace.getActivePane()
    @replPane = paneCurrent.splitDown() #.splitRight
    # Open a new REPL there
    @replPane.activate()
    atom.workspace.open('/tmp/repl.lisp-repl').then (editor) =>
      @editor = editor
      @editorElement = atom.views.getView(@editor)
      @setupRepl()


  # Set up the REPL GUI for use
  setupRepl: () ->
    # Make sure it's marked with the special REPL class - helps some of our keybindings!
    $(@editorElement).addClass('slime-repl')
    # Clear the REPL
    @clearREPL()
    # Attach event handlers
    @subs.add atom.commands.add @editorElement, 'core:backspace': (event) =>
      # Check buffer position!
      point = @editor.getCursorBufferPosition()
      if point.column <= @prompt.length or point.row < @editor.getLastBufferRow()
        event.stopImmediatePropagation()

    @subs.add atom.commands.add @editorElement, 'core:delete': (event) =>
      point = @editor.getCursorBufferPosition()
      if point.column < @prompt.length or point.row < @editor.getLastBufferRow()
        event.stopImmediatePropagation()

    @subs.add atom.commands.add @editorElement, 'core:cut': (event) =>
      # TODO - prevent cutting here. We can make this better.
      event.stopImmediatePropagation()

    # Prevent undo / redo
    @subs.add atom.commands.add @editorElement, 'core:undo': (event) => event.stopImmediatePropagation()
    @subs.add atom.commands.add @editorElement, 'core:redo': (event) => event.stopImmediatePropagation()

    @subs.add atom.commands.add @editorElement, 'editor:newline': (event) => @handleEnter(event)
    @subs.add atom.commands.add @editorElement, 'editor:newline-below': (event) => @handleEnter(event)

    @subs.add @editor.onWillInsertText (event) =>
      #console.log 'Insert: ' + event.text
      # console.log "Insert: #{event.text}"
      point = @editor.getCursorBufferPosition()
      if @inputFromUser and (@preventUserInput or point.column < @prompt.length or point.row < @editor.getLastBufferRow())
        event.cancel()

    # Set up up/down arrow previous command cycling. But don't do it
    # if the autocomplete window is active...
    # TODO - should check autocomplete plus's settings and make sure core movements is enabled?
    @subs.add atom.commands.add @editorElement, 'core:move-up': (event) =>
      if not @isAutoCompleteActive()
        @cycleBack()
        event.stopImmediatePropagation()
    @subs.add atom.commands.add @editorElement, 'core:move-down': (event) =>
      if not @isAutoCompleteActive()
        @cycleForward()
        event.stopImmediatePropagation()

    # Add a clear command
    @subs.add atom.commands.add @editorElement, 'slime:clear-repl': (event) =>
      @clearREPL()
    # Add an interrupt command
    @subs.add atom.commands.add @editorElement, 'slime:interrupt-lisp': (event) =>
      if @swank.connected
        @swank.interrupt()

    @subs.add @editor.onDidDestroy =>
      @destroy()

    # Prevent the "do you want to save?" dialog from popping up when the REPL window is closed.
    # Unfortunately, as per https://discuss.atom.io/t/how-to-disable-do-you-want-to-save-dialog/31373
    # there is no built-in API to do this. As such, we must override an API method to trick
    # Atom into thinking it isn't ever modified.
    @editor.isModified = (() => false)


    # Hide the gutter(s)
    # g.hide() for g in @editor.getGutters()

    # @subs.add atom.commands.add 'atom-workspace', 'slime:thingy': =>
    #   point = @ed.getCursorBufferPosition()
    #   pointAbove = new Point(point.row - 1, @ed.lineTextForBufferRow(point.row - 1).length)
    #   @ed.setTextInBufferRange(new Range(pointAbove, pointAbove), "\nmonkus",undo:'skip')
    #   @ed.scrollToBotom()


  isAutoCompleteActive: () ->
    return $(@editorElement).hasClass('autocomplete-active')


  clearREPL: () ->
    # Destroy any markers
    for marker in @editor.getMarkers()
      marker.destroy()
    # Delete any text, and move to end
    @editor.setText @prompt
    @editor.moveToEndOfLine()


  # Adds non-user-inputted text to the REPL
  appendText: (text, colorTags=true) ->
    @inputFromUser = false
    if colorTags
      @editor.insertText("\x1B#{text}\x1B")
    else
      @editor.insertText(text)
    @inputFromUser = true


  appendPresentationMarker: () ->
    @inputFromUser = false
    @editor.insertText("\x1A")
    @inputFromUser = true


  presentationStart: (presentationID) ->
    @presentationText = ""
    @presentationMode = true

  presentationEnd: (presentationID) ->
    @presentationMode = false
    @insertObject(@presentationText, presentationID)

  # Retrieve the string of the user's input
  getUserInput: (text) ->
    lastLine = @editor.lineTextForBufferRow(@editor.getLastBufferRow())
    return lastLine[@prompt.length..]


  handleEnter: (event) ->
    point = @editor.getCursorBufferPosition()
    if point.row == @editor.getLastBufferRow() and !@preventUserInput and @swank.connected
      input = @getUserInput()
      # Push this command to the ring if applicable
      if input != '' and @previousCommands[@previousCommands.length - 1] != input
        @previousCommands.push input
      @cycleIndex = @previousCommands.length

      @preventUserInput = true
      @editor.moveToEndOfLine()
      @appendText("\n",false)
      promise = @swank.eval input, @pkg
      promise.then =>
        @insertPrompt()
        @preventUserInput = false
        setTimeout ( => @editor.scrollToCursorPosition()), 0


    # Stop the enter
    event.stopImmediatePropagation()


  insertPrompt: () ->
    @appendText("\n" + @prompt, false)
    # Now, mark it
    row = @editor.getLastBufferRow()
    marker = @editor.markBufferPosition(new Point(row,0))
    @editor.decorateMarker marker, {type:'line',class:'repl-line'}


  insertObject: (text, pID) ->
    # We need a buffer character... otherwise, the marker we add will overlap
    # the cursor position, which means when we insert text, the marker position
    # will be updated and change, making the block move. We don't want that.
    # console.log "Presentation ID:" + pID
    @appendText(" ", false)
    pos = @editor.getCursorBufferPosition()
    marker = @editor.markBufferPosition([pos.row, pos.column - 1])
    # <button class='btn btn-info inline-block-tight'>Info</button>
    elementContainer = document.createElement('div')
    element = @createObjectButton(text, pID, false)
    elementContainer.appendChild(element)
    element.addEventListener("click", ((e) => @objectClickCallback(element, pID)), false)
    @editor.decorateMarker(marker, {type: 'block', item: elementContainer, position: 'after'})


  createObjectButton: (text, pID, nth_type=false, colorize=true) ->
    # Creates a button-like representation of an introspected object
    # as an HTML object that is returned. nth_type is a boolean arg
    # that is true if we must call the different swank function to get the
    # nth type to get color / type information
    element = document.createElement('button')
    element.textContent = text
    # element.classList.add('slime-object');
    element.classList.add('slime-object')
    element.classList.add('btn')
    # element.classList.add('btn-success')
    element.classList.add('inline-block-tight')
    element.setAttribute('data-swank-id', pID)
    # Get the type, if we can!
    if colorize and @swank.connected
      if not nth_type
        promise = @swank.get_type_of_presentation_object(pID)
      else
        promise = @swank.get_type_of_inspection_nth_part(pID)
      promise.then (result) => @colorizeObjectByType(element, result.children[1].source.replace(/\\\"/g, '').replace(/\"/g, ''))
    return element


  colorizeObjectByType: (element, type_string) ->
    if type_string == "string" or type_string == "character"
      element.classList.add('btn-warning')
    else if type_string == "number"
      element.classList.add('btn-info')
    else if type_string == "symbol"
      element.classList.add('btn-primary')
    else if type_string == 'list' or type_string == 'array' or type_string == 'hash-table'
      element.classList.add('btn-success')
    else if type_string == 'boolean'
      element.classList.add('btn-error')
    # console.log "Unknown:" + type_string
    #else
      # Nothing!

  objectClickCallback: (element, pID) ->
    # Introspect this object
    @openObjectIntrospection(element, pID)


  openObjectIntrospection: (element, pID) ->
    if @swank.connected
      promise = @swank.inspect_presentation(pID)
      promise.then (result) =>
        title = result.children[1].source.replace(/\"/g, '')
        content = result.children[5].children[0].children

        divContent = [{type: 'title', data: title}]

        for c in content
          if c.type == "string"
            for m in c.source[1...-1].replace(/\\\\/g, '\\').replace(/\\"/g, '"').split(/(\n)/g)
              if m == '\n'
                divContent.push({type: 'newline', data: '\n'})
              else
                divContent.push({type: 'string', data: m}) if m != ''

          else if c.type == "list"
            text = c.children[1].source[1...-1].replace(/\\\\/g, '\\').replace(/\\"/g, '"')
            id = c.children[2].source
            raw_type = c.children[0].source.toLowerCase()
            if raw_type == ':value'
              type = 'reference'
              # If it's a reference, and it begins with a reference, remove it.
              match = text.match(/^@[\d]+=(.*)$/)
              if match
                text = match[1] # Only the matching part!
            else if raw_type == ':action'
              type = 'action'
            else
              type = 'unknown'

            divContent.push({type: type, text: text, id: id})

        # Set the text
        div = document.createElement('div')

        # console.log $(element).css('border-radius')
        # console.log $(element).css('background')
        # console.log $(element).css('border')

        $(div).css('border-radius', $(element).css('border-radius'))
        # $(div).css('border', $(element).css('border'))
        # $(div).css('border', '1px')
        $(div).css('padding', $(element).css('padding'))
        $(div).css('margin', $(element).css('margin'))
        div.classList.add('slime-object-introspected')

        parent = $(element).parent()
        $(element).css('display', 'none')
        $(parent).append(div);

        # element.classList.remove('btn-info')
        # element.classList.remove('btn-success')
        # element.classList.remove('btn-warning')
        # element.classList.remove('btn-error')
        # element.classList.remove('btn-primary')
        contents = @objectContentsToDivHTML(divContent)
        console.log(contents)
        for c in contents
          div.appendChild(c)
        # div.innerHTML = @objectContentsToDivHTML(divContent)


  objectContentsToDivHTML: (divContent) ->
    # First, reformat it to look prettier for Atom
    # Divide into lines
    lines = []
    line = []
    for m in divContent
      if m.type == 'string'
        line.push(m)
      if m.type == 'reference' or m.type == 'action'
        line.push(m)
      if m.type == 'newline'
        lines.push(line)
        line = []
      if m.type == 'title'
        lines.push(line)
        line = []
        lines.push([m])
    lines.push(line)

    # Now parse out tables
    in_table = false
    table_rows = []
    lines_new = []
    for line in lines
      is_table_row = line.some( (x) => x.type == 'string' and x.data == ': ')
      if is_table_row and in_table == false
        in_table = true
      else if is_table_row == false and in_table
        lines_new.push([{type: 'table', rows: table_rows}])
        table_rows = []
        in_table = false
      if is_table_row
        sep_index = line.findIndex((x) => x.type == 'string' and x.data == ': ')
        table_rows.push({left_column: line[0..sep_index-1], right_column: line[sep_index+1...]})
      else
        lines_new.push(line)

    if in_table
      lines_new.push([{type: 'table', rows: table_rows}])

    lines = lines_new

    contents = []
    for line in lines
      for m in line
        contents.push(@formatIntrospectionObj(m))
      contents.push(document.createElement('br'))
    return contents


  formatIntrospectionObj: (m) ->
    # Recursive helper method
    if m.type == 'title'
      html_node = document.createElement('span')
      h4 = document.createElement('h4')
      h4.appendChild(document.createTextNode(m.data))
      html_node.appendChild(h4)
      html_node.appendChild(document.createElement('br'))

    else if m.type == 'string'
      html_node = document.createTextNode(m.data)

    else if m.type == 'newline'
      html_node = document.createElement('br')

    else if m.type == 'reference' or m.type == 'action'
      colorize =  (m.type == 'reference')
      html_node = @createObjectButton(m.text, m.id, true, colorize=colorize)

    else if m.type == 'table'
      html_node = document.createElement('table')
      html_node.classList.add('table')
      html_node.classList.add('table-hover')
      html_node.classList.add('table-condensed')
      tbody = document.createElement('tbody')
      html_node.appendChild(tbody)
      for row in m.rows
        tr = document.createElement('tr')
        tbody.appendChild(tr)
        td = document.createElement('td')
        tr.appendChild(td)
        for c in row.left_column
          td.appendChild(@formatIntrospectionObj(c))
        td = document.createElement('td')
        tr.appendChild(td)
        for c in row.right_column
          td.appendChild(@formatIntrospectionObj(c))

    return html_node


  setupSwankSubscriptions: () ->
    # On changing package
    @swank.on 'new_package', (pkg) => @setPackage(pkg)

    # On printing text from REPL response
    @swank.on 'print_string', (msg) =>
      @print_string_callback(msg)

    # On printing presentation visualizations (like for results)
    @swank.on 'presentation_start', (pID) =>
      # @appendPresentationMarker()
      @presentationStart(pID)
    @swank.on 'presentation_end', (pID) =>
      # @appendPresentationMarker()
      @presentationEnd(pID)

    # Debug functions
    @swank.on 'debug_setup', (obj) => @createDebugTab(obj)
    @swank.on 'debug_activate', (obj) =>
     # TODO - keep track of differnet levels
     @showDebugTab()
    @swank.on 'debug_return', (obj) =>
      # TODO - keep track of different levels
      @closeDebugTab()


  print_string_callback: (msg) ->
    # Print something to the REPL when the swank server says to.
    # However, we need to make sure we're not interfering with the cursor!
    msg = msg.replace(/\\\"/g, '"')

    # TODO: edge case if cursor elsewhere while printing objects?
    if @presentationMode
      @presentationText += msg
      return

    if @preventUserInput
      # A command is being run, no prompt is in the way - so directly print
      # anything received to the REPL
      @appendText(msg)
    else
      # There's a REPL in the way - so go to the line before the REPL,
      # insert the message, then go back down to the corresponding line in the REPL!
      # But only move the user's cursor back to the REPL line if it was there to
      # begin with, otherwise put it back at it's absolute location.
      p_cursor = @editor.getCursorBufferPosition()
      row_repl = @editor.getLastBufferRow()
      cursor_originally_in_repl = (p_cursor.row == row_repl)
      # Edge case: if the row is the last line, insert a new line right above then continue.
      if row_repl == 0
        @editor.setCursorBufferPosition([0, 0])
        @appendText("\n", colorTags=false)
        row_repl = 1
      # Compute the cursor position to the last character on the line above the REPL (we know it exists!)
      p_before_cursor = Point(row_repl - 1, @editor.lineTextForBufferRow(row_repl - 1).length)
      @editor.setCursorBufferPosition(p_before_cursor, {autoScroll: false})
      @appendText(msg)
      if cursor_originally_in_repl
        # Put back in the REPL (which may now have a different row/line)
        @editor.setCursorBufferPosition([@editor.getLastBufferRow(), p_cursor.column])
      else
        # Put back the cursor where it was
        @editor.setCursorBufferPosition(p_cursor)



  cycleBack: () ->
    # Cycle back through command history
    @cycleIndex = @cycleIndex - 1 if @cycleIndex > 0
    @showPreviousCommand(@cycleIndex)


  cycleForward: () ->
    # Cycle forward through command history
    @cycleIndex = @cycleIndex + 1 if @cycleIndex < @previousCommands.length
    @showPreviousCommand(@cycleIndex)


  showPreviousCommand: (index) ->
    if index >= @previousCommands.length
      # Empty it
      @setPromptCommand ''
    else if index >= 0 and index < @previousCommands.length
      cmd = @previousCommands[index]
      @setPromptCommand cmd


  setPromptCommand: (cmd) ->
    # Sets the command at the prompt
    lastrow = @editor.getLastBufferRow()
    lasttext = @editor.lineTextForBufferRow(lastrow)
    range = new Range([lastrow, 0], [lastrow, lasttext.length])
    newtext = "#{@prompt}#{cmd}"
    @editor.setTextInBufferRange(range, newtext, undo:'skip')


  setupDebugger: () ->
    process.nextTick =>
    @subs.add atom.workspace.addOpener (filePath) =>
        if filePath == 'slime://debug'
          return @dbgv
    @subs.add @replPane.onWillDestroyItem (e) =>
      if e.item == @dbgv
        @swank.debug_escape_all()


  createDebugTab: (obj) ->
    @dbgv = new DebuggerView
    @dbgv.setup(@swank, obj)

  showDebugTab: () ->
    @replPane.activate()
    atom.workspace.open('slime://debug').then (d) =>
      # TODO - doesn't work
      #elt = atom.views.getView(d)
      #atom.commands.add elt, 'q': (event) => @closeDebugTab()

  closeDebugTab: () ->
    @replPane.destroyItem(@dbgv)


  # Set the package and prompt
  setPackage: (pkg) ->
    @pkg = pkg
    @prompt = "#{@pkg}> "


  destroy: ->
    if @swank.connected
      @closeDebugTab()
      @subs.dispose()
      @swank.quit()
