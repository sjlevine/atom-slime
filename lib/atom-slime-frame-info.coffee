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
      @button outlet:'restartFrame', class:'inline-block-tight btn', 'Restart Frame'
      @input outlet:'frameReturnValue', class:'inline-block-tight', type:'text'
      @button outlet:'returnFromFrame', class:'inline-block-tight btn', 'Return From Frame'
      @button outlet:'disassemble', class:'inline-block-tight btn', 'Disassemble Frame'
      @div outlet:'disassembleOutput'

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

    if frame.restartable
      @restartFrame[0].disabled = false
      @restartFrame.on 'click', (event) =>
        @debugView.active = false
        @swank.debug_restart_frame(@frame_index, @info.thread)
    else
      @restartFrame[0].disabled = true

    @returnFromFrame.on 'click', (event) =>
      @debugView.active = false
      @swank.debug_return_from_frame(@frame_index, @frameReturnValue[0].value, @info.thread)

    @disassembleOutput.text = ''
    @disassemble.on 'click', (event) =>
      @swank.debug_disassemble_frame(@frame_index, @info.thread).then (output) =>
        @disassembleOutput.text = output

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


  getTitle: -> 'Frame Info'
  getURI: => 'slime://debug/' + @info.level + '/frame'
  isEqual: (other) =>
    other instanceof FrameInfoView and @info.level == other.info.level
