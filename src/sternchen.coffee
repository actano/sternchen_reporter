###
    custom actano reporter (derived from the mocha tap reporter)
###

# set the global state to enforce stacktrace for chai AssertionErrors

require('chai').Assertion.includeStack = true
fs = require 'fs'

if phantom?
    # if we run in phantomjs, we can't require node modules
    join = ->
        args = Array.prototype.filter.call arguments, (elt) ->
            typeof elt == "string"
        args.join '/'

    dirname = (p) ->
        return if not p? or typeof p != "string"

        split = p.split '/'
        slice = split.slice 0, -1
        if slice.length == 0
            '.'
        else
            slice.join '/'

    basename = (p, ext) ->
        return if not p? or typeof p != "string"

        split = p.split '/'
        base = (split.slice -1)[0]

        if ext? and base.slice -1 * ext.length == ext
            base = base.slice 0, -1 * ext.length

        base

    extname = (p) ->
        return if not p? or typeof p != "string"

        idx = p.lastIndexOf '.'

        return p if idx <= 0
        p.slice idx

    path =
        join: join
        dirname: dirname
        basename: basename
        extname: extname

    fs.openSync = fs.open

    fs.closeSync = (fd) ->
        fd.close()

    exit = phantom.exit
else
    path = require 'path'
    exit = process.exit

class PhantomError
    constructor: (@message, stack) ->
        @stack = ''

        for entry in stack
            @stack += "\t#{entry.function} at #{entry.file}:#{entry.line}\n"

    toString: ->
        @message + @stack

running = true

if casper?
    _onPhantomError = (msg, trace) ->
        debugger
        err = new PhantomError(msg, trace)

        console.log err.message
        console.log err.stack if err.stack

        writer = new ReportWriter()
        writer.createReportFile()

        writer.write '<testcase classname="' + writer.htmlEscape(process.env.REPORT_FILE) + '" name="ERROR">\n'
        writer.write '<failure message="' + writer.htmlEscape(err.message) + '">\n'
        writer.write writer.htmlEscape(err.stack) + '\n' if err.stack?
        writer.write '</failure>\n'
        writer.write '</testcase>\n'

        writer.closeReportFile()

        # NOTE: Even if we call exit code seems to be executed afterwards. So we need this trick to prevent that the
        #       report file is overwritten.
        running = false

        exit -1

    casper.on 'error', _onPhantomError
    casper.on 'page.error', _onPhantomError

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
        return unless running

        reportFile = process.env.REPORT_FILE

        if reportFile? and reportFile.length > 0
            @package = path.join(path.dirname(reportFile), path.basename(reportFile, path.extname(reportFile))).replace /\//g, '.'
            prefix = process.env.PREFIX
            @reportFile = path.join prefix, reportFile if prefix?
            @tempFile = @reportFile + '.tmp'
            @fd = fs.openSync(@tempFile, 'w')
            @write '<testsuites name="Mocha Tests">\n'

    closeReportFile: ->
        if @fd?
            @write '</testsuites>'
            fs.closeSync @fd
            if fs.renameSync?
                fs.renameSync @tempFile, @reportFile
            else
                fs.remove @reportFile if fs.exists @reportFile
                fs.move @tempFile, @reportFile

class Sternchen extends ReportWriter
    constructor: (@runner) ->
        @stats =
            suites: 0
            tests: 0
            passes: 0
            pending: 0
            failures: 0
        @runner.stats = @stats
        @initalizeEvents()

    endSuite: =>
        if @currentSuite?
            duration = new Date - @currentSuite.start

            @write '<testsuite'
            @write ' name="' + @htmlEscape(@currentSuite.suite.fullTitle()) + '"'
            @write ' tests="' + @currentSuite.tests.length + '"'
            @write ' failures="' + @currentSuite.failures + '"'
            @write ' skipped="' + (@currentSuite.tests.length - @currentSuite.failures - @currentSuite.passes) + '"'
            @write ' timestamp="' + @currentSuite.start.toUTCString() + '"'
            @write ' make_target="' + process.env.MAKE_TARGET + '"'
            @write ' time="' + (duration / 1000) + '">\n'

            for test in @currentSuite.tests
                @write '<testcase'
                @write ' classname="' + @package + '"'
                @write ' name="' + @htmlEscape(@currentSuite.suite.title + '.' + test.title) + '"'
                @write ' time="' + (test.duration / 1000) + '"' if not test.skipped
                if test.state == "failed"
                    @write '>\n'
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
                        @write '>\n'
                        @write '<skipped/>\n'
                        @write '</testcase>\n'
                    else
                        @write '/>\n'

            @write '</testsuite>\n'

    startSuite: (suite) =>
        @currentSuite = {
            suite: suite,
            tests: [],
            start: new Date
            failures: 0
            passes: 0
        }

    addTest: (test) ->
        @stats.tests++
        @currentSuite.tests.push test if @currentSuite?.tests?

    initalizeEvents: ->
        @runner.on 'start', =>
            @createReportFile()

            @stats.start = new Date

            total = @runner.grepTotal(@runner.suite)
            console.log('%d..%d', 1, total)

        @runner.on 'suite', (suite) =>
            suite.root or @stats.suites++

        @runner.on 'test', (test) =>
            if test.parent.fullTitle() != @lastSuiteTitle
                @endSuite()
                @lastSuiteTitle = test.parent.fullTitle()
                @startSuite(test.parent)

        @runner.on 'pending', (test) =>
            @addTest test
            @stats.pending++
            test.skipped = true
            console.log('ok %d %s # SKIP -', @stats.tests + 1, @title(test))

        @runner.on 'pass', (test) =>
            @addTest test
            @stats.passes++
            @currentSuite.passes++
            console.log('ok %d %s', @stats.tests + 1, @title(test))

        @runner.on 'fail', (test, err) =>
            @addTest test
            # There are some cases in which test.err is undefined.
            # So we set it here to be sure that we have an error for our xml report.
            test.err = err
            @stats.failures++
            @currentSuite.failures++ if @currentSuite?
            console.log('mocha not ok %d %s', @stats.tests, @title(test));
            if (err.stack)
                console.log(err.stack.replace(/^/gm, '  '))

        @runner.on 'end', =>
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

