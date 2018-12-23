{CompositeDisposable} = require 'atom'
{$, $$, View, SelectListView, ScrollView} = require 'atom-space-pen-views'

module.exports =
class FrameInfoView extends ScrollView
  @content: ->
    @div outlet:'main', class:'atom-slime-debugger padded', =>
      @h1 outlet:'frameName', 'Frame Name'
      @div class:'select-list', =>
        @ol outlet:'navigation', class:'list-group mark-active', =>
          @li 'Navigate to adjacent stack frames'
      @h3 'Local Variables'
      @div class:'select-list', =>
        @ol outlet:'locals', class:'list-group mark-active', =>
          @li 'Description of var 0'
      @div outlet: 'catchTagsDiv', class:'select-list', =>
        @h3 'Catch Tags'
        @ol outlet:'catchTags', start:'0', =>
          @li 'Description of tag 0'
      @div class:'select-list', =>
        @ol class:'list-group mark-active', =>
          @li =>
            @button outlet:'viewSource', class:'inline-block-tight btn', 'View Frame Source'
          @li =>
            @button outlet:'restartFrame', class:'inline-block-tight btn', 'Restart Frame'
          @li =>
            @button outlet:'disassemble', class:'inline-block-tight btn', 'Disassemble Frame'
        @div outlet:'disassembleDiv', =>
          @h3 'Disassembled:'
          @span outlet:'disassembleOutput', class:'slime-message', ''
        @ol class:'list-group mark-active', =>
          @li =>
            @input outlet:'frameReturnValue', class:'native-key-bindings', type:'text', size:50
          @li =>
            @button outlet:'returnFromFrame', class:'inline-block-tight btn', 'Return From Frame'
          @li =>
            @button outlet:'evalInFrame', class:'inline-block-tight btn', 'Eval in Frame'

  setup: (@swank, @info, @frame_index, @debugView) ->
    frame = @info.stack_frames[@frame_index]

    @frameName.html @frame_index + ': ' + frame.description

    @navigation.empty()
    if @frame_index > 0
      @add_navigation_item(0, description = @info.stack_frames[0].description, 'Stack Top')
    if @frame_index > 1
      @add_navigation_item(@frame_index-1, description = @info.stack_frames[@frame_index-1].description, 'Up')
    if @frame_index < @info.stack_frames.length - 1
      @add_navigation_item(@frame_index+1, description = @info.stack_frames[@frame_index+1].description, 'Down')

    this.find('.frame-navigation-button').on 'click', (event) =>
      @setup(@swank, @info, Number(event.target.getAttribute('frame_index')), @debugView)

    @viewSource.on 'click', (event) =>
      @display_frame_source()

    if frame.restartable
      @restartFrame[0].disabled = false
      @restartFrame.on 'click', (event) =>
        @debugView.active = false
        @swank.debug_restart_frame(@frame_index, @info.thread)
    else
      @restartFrame[0].disabled = true

    @disassembleDiv.hide()
    @disassemble.on 'click', (event) =>
      @swank.debug_disassemble_frame(@frame_index, @info.thread).then (output) =>
        @disassembleOutput.text(output)
        @disassembleDiv.show()

    @returnFromFrame.on 'click', (event) =>
      @debugView.active = false
      @swank.debug_return_from_frame(@frame_index, @frameReturnValue.val(), @info.thread)
      .catch (errorMessage) =>
        atom.notifications.addError(errorMessage)

    @evalInFrame.on 'click', (event) =>
      input = @frameReturnValue.val()
      @frameReturnValue.val('')
      @swank.debug_eval_in_frame(@frame_index, input, @info.thread).then (result) =>
        replView = @debugView.replView
        replView.print_string_callback(result+'\n')
        replView.replPane.activateItem(replView.editor)

    @swank.debug_stack_frame_details(@frame_index, @info.stack_frames, @info.thread).then (frame) =>
      @locals.empty()
      if frame.locals.length > 0
        for local, i in frame.locals
          @locals.append $$ ->
            @li local.id + ': ' + local.name + ' = ' + local.value
      else
        @locals.append $$ ->
          @li '<No Locals>'
      if frame.catch_tags.length > 0
        @catchTagsDiv.show()
        @catchTags.empty()
        for tag, i in frame.catch_tags
          @catchTags.append $$ ->
            @li i + ': ' + tag
      else
        @catchTagsDiv.hide()

  add_navigation_item: (index, frame_description, label) ->
    @navigation.append $$ ->
      @li class:"", =>
        @button class:'inline-block-tight frame-navigation-button btn', frame_index:index, label
        @text index+": " + frame_description

  display_frame_source: () =>
    frame_index = @frame_index
    @swank.debug_frame_source(frame_index, @info.thread).then (source_location) ->
      if source_location.buffer_type == 'error'
        editor_promise = Promise.reject(source_location.error)
      else if source_location.buffer_type == 'buffer' or source_location.buffer_type == 'buffer-and-file'
        # look through editors for an editor with a matching name
        for editor in atom.workspace.getTextEditors()
          if editor.getTitle() == source_location.buffer_name
            pane = atom.workspace.paneForItem(editor)
            pane.activate()
            pane.activateItem(editor)
            editor_promise = Promise.resolve(editor)
            break
        if source_location.buffer_type == 'buffer-and-file'
          # fall back to file if nessacery
          editor_promise ?= atom.workspace.open(source_location.file)
        else
          editor_promise ?= Promise.reject('No editor named '+source_location.buffer_name)
      else if source_location.buffer_type == 'file'
        editor_promise = atom.workspace.open(source_location.file)
      else if source_location.buffer_type == 'source-form'
        editor = atom.workspace.buildTextEditor()
        editor.setText(source_location.source_form)
        #change default title
        editor.getTitle = -> editor.getFileName() ? 'Frame ' + frame_index + ' Source'
        #change condition for save prompt for unsaved file
        editor_buffer = editor.getBuffer()
        editor_buffer.isModified = ->
          if editor_buffer.file?.existsSync()
            editor_buffer.buffer.isModified()
          else
            editor_buffer.getText() != source_location.source_form
        #add to active pane
        activePane = atom.workspace.getActivePane()
        activePane.addItem(editor)
        activePane.activateItem(editor)
        editor_promise = Promise.resolve(editor)
      else
        # TODO zip
        editor_promise = Promise.reject('Unsupported source type given: "'+source_location.buffer_type+'"')

      #need source_location, so use a closure to pass it to the next part
      editor_promise.then (editor) ->
        if source_location.position_type == 'line'
          row = source_location.position_line
          col = location.position_column ? 0
          editor.setCursorBufferPosition(new Point(row, col))
        else if source_location.position_type == 'position'
          position = editor.getBuffer()
                           .positionForCharacterIndex(source_location.position_offset)
          editor.setCursorBufferPosition(position)
        else
          #TODO function-name
          #TODO source-path
          #TODO method
          Promise.reject('Unsupported position type given: "'+source_location.position_type+'"')
    .catch (error) ->
      atom.notifications.addError 'Cannot show frame source: '+error

  getTitle: -> 'Frame Info'
  getURI: => 'slime://debug/' + @info.level + '/frame'
  isEqual: (other) =>
    other instanceof FrameInfoView and @info.level == other.info.level
