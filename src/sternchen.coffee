###
    custom actano reporter (derived from the mocha tap reporter)
###

# set the global state to enforce stacktrace for chai AssertionErrors

require('chai').Assertion.includeStack = true
fs = require 'fs'
mkdirp = require 'mkdirp'
path = require 'path'
exit = process.exit
debug = require('debug')('sternchen')

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

    initalizeEvents: ->
        @runner.on 'start', =>
            debug 'run started'
            @createReportFile()

            @stats.start = new Date

            total = @runner.grepTotal(@runner.suite)
            console.log('%d..%d', 1, total)

        @runner.on 'pending', (test) =>
            debug "pending test '#{test?.title}'"
            @addTest test
            @stats.pending++
            test.skipped = true
            console.log('ok %d %s # SKIP -', @stats.tests + 1, @title(test))

        @runner.on 'pass', (test) =>
            debug "test '#{test?.title}' passed"
            @addTest test
            @stats.passes++
            console.log('ok %d %s', @stats.tests + 1, @title(test))

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
            console.log('mocha not ok %d %s', @stats.tests, @title(test));
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

