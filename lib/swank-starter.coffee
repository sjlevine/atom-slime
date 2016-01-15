{BufferedProcess} = require 'atom'

# Helps to start a Swank server automatically so the
# user doesn't have to start one in a separate terminal
module.exports =
class SwankStarter
  process: null

  start: () ->
    @path = atom.config.get 'atom-slime.slimePath'
    @lisp = atom.config.get 'atom-slime.lispName'
    command = @lisp
    args = ['--load', "#{@path}/start-swank.lisp"]
    @process = new BufferedProcess command:command, args:args, stdout:@stdout_callback, exit:@exit_callback
    console.log "Started a swank server"

  stdout_callback: (output) ->
    #console.log output

  exit_callback: (code) ->
    console.log "Lisp process exited: #{code}"

  destroy: () ->
    @process?.kill()
