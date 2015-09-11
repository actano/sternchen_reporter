###
    custom actano reporter (derived from the mocha tap reporter)
###

# set the global state to enforce stacktrace for chai AssertionErrors
require('chai').config.includeStack = true
fs = require 'fs'
mkdirp = require 'mkdirp'
path = require 'path'
exit = process.exit
debug = require('debug')('sternchen')

Base = require 'mocha/lib/reporters/base'
cursor = Base.cursor
color = Base.color

{REPORT_FILE, PREFIX, MAKE_TARGET} = process.env

class ReportWriter
    write: (str) ->
        if @fd?
            if phantom?
                @fd.write str
            else
                buf = new Buffer str
                fs.writeSync @fd, buf, 0, buf.length, null

    htmlEscape: (str) ->
        String(str)
            .replace(/&/g, '&amp;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')

    createReportFile: ->
        @reportFile = REPORT_FILE
        console.log '>>>>>>>>> report file: ', @reportFile

        if @reportFile? and @reportFile.length > 0
            @package = path.join(path.dirname(@reportFile), path.basename(@reportFile, path.extname(@reportFile))).replace /\//g, '.'
            @reportFile = path.join(PREFIX, @reportFile) if PREFIX?

            # Create directory if it doesn't exist. fs.openSync blocks forever if the directory doesn't exist beforehand.
            directory = path.dirname @reportFile
            mkdirp.sync directory

            @tempFile = @reportFile + '.tmp'
            debug "creating temp report file #{@tempFile}"
            @fd = fs.openSync(@tempFile, 'w')
            @write '<testsuites name="Mocha Tests">\n'

    closeReportFile: ->
        if @fd?
            @write '</testsuites>'
            fs.closeSync @fd
            debug "moving temp file to #{@reportFile}"
            if fs.renameSync?
                fs.renameSync @tempFile, @reportFile
            else
                fs.remove @reportFile if fs.exists @reportFile
                fs.move @tempFile, @reportFile

class Sternchen extends ReportWriter
    constructor: (@runner) ->
        debug 'creating sternchen reporter'
        @stats =
            suites: 0
            tests: 0
            passes: 0
            pending: 0
            failures: 0
        @runner.stats = @stats
        @initalizeEvents()
        @tests = []

    endSuite: =>
        debug 'writing XML report'
        duration = new Date - @stats.start

        @write '<testsuite'
        @write ' name="' + @package + '"'
        @write ' tests="' + @tests.length + '"'
        @write ' failures="' + @stats.failures + '"'
        @write ' skipped="' + (@tests.length - @stats.failures - @stats.passes) + '"'
        @write ' timestamp="' + @stats.start.toUTCString() + '"'
        @write ' make_target="' + @htmlEscape(MAKE_TARGET) + '"'
        @write ' time="' + (duration / 1000) + '">\n'

        for test in @tests
            @write '<testcase'
            @write ' classname="' + @package + '"'
            @write ' name="' + @htmlEscape(test.parent.fullTitle() + ' ' + test.title) + '"'
            @write ' time="' + (test.duration / 1000) + '"' if not test.skipped
            @write '>\n'

            if test.stdout?
                @write '<system-out>\n'
                @write '<![CDATA['
                @write test.stdout
                @write ']]>\n'
                @write '</system-out>\n'

            if test.state == "failed"
                @write '<failure message="'
                if test.err?.message?
                    @write @htmlEscape(test.err.message)
                else
                    @write 'unknown error'
                @write '">\n'
                if test.err?.stack?
                    @write @htmlEscape test.err.stack.replace /^/gm, '  '
                @write '\n</failure>\n'
                @write '</testcase>\n'
            else
                if test.skipped
                    @write '<skipped/>\n'
                    @write '</testcase>\n'
                else
                    @write '</testcase>\n'

        @write '</testsuite>\n'

    addTest: (test) ->
        debug "adding test '#{test?.title}'"
        @stats.tests++
        @tests.push test

    # spec reporter
    indents = 0
    indent = ->
        Array(indents).join('  ')

    initalizeEvents: ->

        @runner.on 'start', =>
            debug 'run started'
            @createReportFile()

            @stats.start = new Date

            total = @runner.grepTotal(@runner.suite)

            # spec reporter
            console.log();

        # spec reporter
        @runner.on 'suite', (suite) ->
            ++indents
            console.log(color('suite', '%s%s'), indent(), suite.title)

        # spec reporter
        @runner.on 'suite end', (suite) ->
            --indents
            console.log() if 1 is indents

        @runner.on 'pending', (test) =>
            debug "pending test '#{test?.title}'"
            @addTest test
            @stats.pending++
            test.skipped = true

            # spec reporter
            fmt = indent() + color('pending', '  - %s')
            console.log(fmt, test.title);

        @runner.on 'pass', (test) =>
            debug "test '#{test?.title}' passed"
            @addTest test
            @stats.passes++

            # spec reporter
            fmt = indent() +
                color('checkmark', '  ' + Base.symbols.ok) +
                color('pass', ' %s')
            cursor.CR()
            console.log(fmt, test.title)

        @runner.on 'fail', (test, err) =>
            debug "test '#{test?.title}' failed"
            if test.onFailureHandlers?.length
                test.stdout ?= ''

                for failureHandler in test.onFailureHandlers
                    test.stdout += failureHandler path.dirname @reportFile

            @addTest test
            # There are some cases in which test.err is undefined.
            # So we set it here to be sure that we have an error for our xml report.
            test.err = err
            @stats.failures++

            # spec reporter
            cursor.CR()
            console.log(indent() + color('fail', '  %d) %s'), @stats.failures, test.title)

            if (err.stack)
                console.log(err.stack.replace(/^/gm, '  '))

        @runner.on 'end', =>
            debug 'run ended'
            @stats.end = new Date
            @stats.duration = @stats.end - @stats.start
            @endSuite()
            @closeReportFile()

            console.log('# tests ' + (@stats.passes + @stats.failures));
            console.log('# pass ' + @stats.passes);
            console.log('# fail ' + @stats.failures);

    title: (test) ->
        return test.parent.fullTitle() + " : " + test.title;

module.exports = Sternchen

