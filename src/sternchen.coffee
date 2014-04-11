###
    custom actano reporter (derived from the mocha tap reporter)
###

# set the global state to enforce stacktrace for chai AssertionErrors

require('chai').Assertion.includeStack = true
path = require 'path'
fs = require 'fs'

class Sternchen
    constructor: (@runner) ->
        @n = 1
        @passes = 0
        @failures = 0;
        @initalizeEvents()

    write: (str) ->
        if @fd?
            buf = new Buffer str
            fs.writeSync @fd, buf, 0, buf.length, null

    htmlEscape: (str) ->
        String(str)
            .replace(/&/g, '&amp;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')

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
                @write ' time="' + (test.duration / 1000) + '"'
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

    initalizeEvents: ->
        @runner.on 'start', =>
            report_file = process.env.REPORT_FILE

            if report_file?
                @package = path.join(path.dirname(report_file), path.basename(report_file, path.extname(report_file))).replace /\//g, '.'
                prefix = process.env.PREFIX
                report_file = path.join prefix, report_file if prefix?
                @fd = fs.openSync(report_file, 'w')
                @write '<testsuites name="Mocha Tests">\n'

            total = @runner.grepTotal(@runner.suite)
            console.log('%d..%d', 1, total)

        @runner.on 'test', (test) =>
            if test.parent.fullTitle() != @lastSuiteTitle
                @endSuite()
                @lastSuiteTitle = test.parent.fullTitle()
                @startSuite(test.parent)

        @runner.on 'test end', (test) =>
            @currentSuite.tests.push test if @currentSuite?.tests?
            ++@n

        @runner.on 'pending', (test) =>
            console.log('ok %d %s # SKIP -', @n, @title(test))

        @runner.on 'pass', (test) =>
            @currentSuite.passes++
            @passes++
            console.log('ok %d %s', @n, @title(test))

        @runner.on 'fail', (test, err) =>
            # There are some cases in which test.err is undefined.
            # So we set it here to be sure that we have an error for our xml report.
            test.err = err
            @currentSuite.failures++ if @currentSuite?
            @failures++;
            console.log('mocha not ok %d %s', @n, @title(test));
            if (err.stack)
                console.log(err.stack.replace(/^/gm, '  '))

        @runner.on 'end', =>
            @endSuite()
            @write '</testsuites>'
            fs.closeSync fd if fd?

            console.log('# tests ' + (@passes + @failures));
            console.log('# pass ' + @passes);
            console.log('# fail ' + @failures);


    title: (test) ->
        return test.parent.fullTitle() + " : " + test.title;

module.exports = Sternchen

