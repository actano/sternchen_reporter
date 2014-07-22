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

    fs.fsyncSync = (fd) ->
        fd.flush()
else
    path = require 'path'

class PhantomError
    constructor: (@message, stack) ->
        @stack = ''

        for entry in stack
            @stack += "\n\t#{entry.function} at #{entry.file}:#{entry.line}"

    toString: ->
        @message + @stack

preTestErrors = []

if casper?
    _addPhantomError = (msg, trace) ->
        err = new PhantomError(msg, trace)
        preTestErrors.push err

    casper.on 'error', _addPhantomError
    casper.on 'page.error', _addPhantomError

class ReportWriter
    write: (str) ->
        if @fd?
            if phantom?
                @fd.write str
            else
                buf = new Buffer str
                fs.writeSync @fd, buf, 0, buf.length, null

    flush: ->
        fs.fsyncSync @fd if @fd

    htmlEscape: (str) ->
        String(str)
            .replace(/&/g, '&amp;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')

    createReportFile: ->
        report_file = process.env.REPORT_FILE

        if report_file? and report_file.length > 0
            @package = path.join(path.dirname(report_file), path.basename(report_file, path.extname(report_file))).replace /\//g, '.'
            prefix = process.env.PREFIX
            report_file = path.join prefix, report_file if prefix?
            @fd = fs.openSync(report_file, 'w')
            @write '<testsuites name="Mocha Tests">\n'

    closeReportFile: ->
        if @fd?
            @write '</testsuites>'
            fs.closeSync @fd if @fd?

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

    writePreTestErrors: ->
        if preTestErrors.length > 0
            @write '<testcase classname="' + @htmlEscape(process.env.REPORT_FILE) + '" name="ERROR">\n'
            for err in preTestErrors
                @write '<failure message="' + @htmlEscape(err.message) + '">\n'
                @write @htmlEscape(err.stack) + '\n' if err.stack?
                @write '</failure>\n'
            @write '</testcase>\n'
            @flush()

    initalizeEvents: ->
        @runner.on 'start', =>
            @createReportFile()
            @writePreTestErrors()

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

        @runner.on 'test end', (test) =>
            @stats.tests++
            @currentSuite.tests.push test if @currentSuite?.tests?

        @runner.on 'pending', (test) =>
            @stats.pending++
            test.skipped = true
            console.log('ok %d %s # SKIP -', @stats.tests + 1, @title(test))

        @runner.on 'pass', (test) =>
            @stats.passes++
            @currentSuite.passes++
            console.log('ok %d %s', @stats.tests + 1, @title(test))

        @runner.on 'fail', (test, err) =>
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

