{exec} = require 'child_process'
fs = require 'fs'
path = require 'path'

{expect} = require 'chai'
parseXml = require('xml2js').parseString
uuid = require 'node-uuid'
rimraf = require 'rimraf'

describe 'Sternchen Reporter', ->
    tempDir = 'tmp'

    _mochaCommandLine = (fileName) ->
        "mocha -R #{__dirname}/../lib/index.js " +
        "--compilers coffee:coffee-script,coffee-trc:coffee-errors " +
        "#{__dirname + '/testData/' + fileName}"

    _triggerTest = (fileName, opts, cb) ->
        if typeof opts is 'function'
            cb = opts
            opts =
                env: {}

        command = ''

        for key, value of opts.env
            command += "#{key}=#{value} "

        command += _mochaCommandLine fileName

        exec command, cb

    _checkResult = (consoleString, {totalTestCount, runTestCount, passedTestCount, failureTestCount}) ->
        regExTotalCount = new RegExp "1\.\.#{totalTestCount}"
        regExRunTestCount = new RegExp "\# tests #{runTestCount}"
        regExPassedTestCount = new RegExp "\# pass #{passedTestCount}"
        regExFailureTestCount = new RegExp "\# fail #{failureTestCount}"

        expect(consoleString).to.match regExTotalCount
        expect(consoleString).to.match regExRunTestCount
        expect(consoleString).to.match regExPassedTestCount
        expect(consoleString).to.match regExFailureTestCount

    _parseResultFile = (fileName, cb) ->
        fs.readFile fileName, {encoding: 'utf8'}, (err, data) ->
            return cb err if err?
            parseXml data, cb

    _checkResultFromFile = (fileName, {totalTestCount, skippedTestCount, failureTestCount}, cb) ->
        _parseResultFile fileName, (err, result) ->
            return cb err if err?

            results = result?.testsuites?.testsuite?[0]?['$']
            expect(results).to.exist
            expect(results.tests).to.equal "#{totalTestCount}"
            expect(results.skipped).to.equal "#{skippedTestCount}"
            expect(results.failures).to.equal "#{failureTestCount}"

            cb()

    _newTempFileName = ->
        path.join tempDir, uuid.v4()

    _createDir = (dir, cb) ->
        fs.exists dir, (exists) ->
            return cb() if exists
            fs.mkdir dir, cb

    before (done) ->
        _createDir tempDir, done

    after (done) ->
        rimraf tempDir, done

    it 'should report test results to console', (done) ->
        _triggerTest 'mocha_test.coffee', (error, stdout, stderr) ->
            expect(error).to.exist
            expect(error.code).to.equal 1

            _checkResult stdout,
                totalTestCount: 8
                runTestCount: 3
                passedTestCount: 2
                failureTestCount: 1
            done()

    it 'should report test results to file system (process.env.REPORT_FILE)', (done) ->
        reportFileName = _newTempFileName()

        opts =
            env:
                "REPORT_FILE": reportFileName

        _triggerTest 'mocha_test.coffee', opts, (error, stdout, stderr) ->
            expect(error).to.exist
            expect(error.code).to.equal 1

            _checkResultFromFile reportFileName,
                totalTestCount: 8
                skippedTestCount: 5
                failureTestCount: 1,
                done

    it 'should respect the PREFIX env variable as path prefix of the test report file', (done) ->
        reportFileName = _newTempFileName()

        opts =
            env:
                "PREFIX": tempDir
                "REPORT_FILE": reportFileName

        _createDir 'tmp/tmp', ->
            _triggerTest 'mocha_test.coffee', opts, (error, stdout, stderr) ->
                expect(error).to.exist
                expect(error.code).to.equal 1

                _checkResultFromFile path.join(tempDir, reportFileName),
                    totalTestCount: 8
                    skippedTestCount: 5
                    failureTestCount: 1,
                    done

    ###
        We can't check this here. It has nothing to do with sternchen reporter.

        If there are any uncaught errors in the test script, the node process will fail with exit code 8.
        We can do nothing about it since the sternchen reporter will never be loaded.
    ###
    #it.skip 'should report pre test errors in nodeJS environment', (done) ->
    #    done()

    it 'should call onFailure function of a test and write its return value to system-out section', (done) ->
        reportFileName = _newTempFileName()

        opts =
            env:
                "REPORT_FILE": reportFileName

        _triggerTest 'onFailure_test.coffee', opts, (error, stdout, stderr) ->
            _parseResultFile reportFileName, (err, result) ->
                return done err if err?

                testcases = result?.testsuites?.testsuite?[0]?.testcase
                testcaseByName = {}

                for testcase in testcases
                    attrs = testcase['$']
                    testcaseByName[attrs.name] = testcase

                # console.log testcaseByName
                expect(testcaseByName['testsuite pass'], 'testsuite pass').to.exist
                expect(testcaseByName['testsuite pass']['system-out'], 'testsuite pass system-out').to.not.exist

                expect(testcaseByName['testsuite skip'], 'testsuite skip').to.exist
                expect(testcaseByName['testsuite skip']['system-out'], 'testsuite skip system-out').to.not.exist

                expect(testcaseByName['testsuite fail'], 'testsuite fail').to.exist
                expect(testcaseByName['testsuite fail']['system-out'], 'testsuite fail system-out').to.exist
                expect(testcaseByName['testsuite fail']['system-out'][0]).to.contain 'onFailure called with tmp'

                done()
