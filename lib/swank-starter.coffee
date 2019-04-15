{BufferedProcess} = require 'atom'
fs = require 'fs'
path = require 'path'

# Helps to start a Swank server automatically so the
# user doesn't have to start one in a separate terminal
module.exports =
class SwankStarter
  process: null

  start: () ->
    success = @check_path()
    if not success
      atom.notifications.addWarning("Did you set up `atom-slime` as noted in the package's preferences? The \"Slime Path\" directory can't be opened. Please double check it!")
      return false
    command = @lisp
    @lispOptionsString = atom.config.get 'atom-slime.lispOptionsString'
    @lispOptionsEnabled = atom.config.get 'atom-slime.lispOptionsEnabled'
    args = []
    args.push 'run' if command.match(/ros/)
    if not command.match(/clisp|lw/)
      args.push '--load'
    else
      args.push '-load' if command.match(/lw/)
    args.push @swank_script
    args.push @lispOptionsString if @lispOptionsEnabled
    @process = new BufferedProcess({
      command: command,
      args: args,
      options:
        cwd: @get_cwd()
      stdout: @stdout_callback,
      stderr: @stderr_callback,
      exit: @exit_callback
    })
    console.log "Started a swank server"
    return true

  check_path: () ->
    # Retrieve the slime path and lisp name
    @lisp = atom.config.get 'atom-slime.lispName'
    @path = atom.config.get 'atom-slime.slimePath'
    @path = @path[0...-1] if @path[@path.length - 1] == path.sep
    @swank_script = "#{@path}#{path.sep}start-swank.lisp"
    # Check if the slime path exists; return true or false
    try
      info = fs.statSync(@swank_script)
      return true
    catch
      return false

  stdout_callback: (output) ->
    if atom.config.get 'atom-slime.advancedSettings.showSwankDebug'
      console.log output

  stderr_callback: (output) ->
    if atom.config.get 'atom-slime.advancedSettings.showSwankDebug'
      console.log output

  get_cwd: ->
    ed = atom.workspace.getActiveTextEditor()?.getPath()
    return atom.project.getPaths()[0] unless ed?
    return path.dirname(ed)

  exit_callback: (code) ->
    console.log "Lisp process exited: #{code}"

  destroy: () ->
    @process?.kill()
