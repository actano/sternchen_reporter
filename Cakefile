{exec} = require 'child_process'

task 'build', "Build project from src/*.coffee to lib/*.js", ->
    exec './node_modules/.bin/coffee --compile --output lib/ src/', (err, stdout, stderr) ->
        throw err if err
        process.stdout.write stdout
        process.stderr.write stderr

