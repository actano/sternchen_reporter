{exec} = require 'child_process'
fs = require 'fs'
path = require 'path'

{expect} = require 'chai'
parseXml = require('xml2js').parseString
uuid = require 'node-uuid'
rimraf = require 'rimraf'

describe 'Sternchen Reporter', ->
    tempDir = 'tmp'

    _triggerTest = (fileName, opts, cb) ->
        if typeof opts is 'function'
            cb = opts
            opts = {}

        command = ''

        for key, value of opts
            command += "#{key}=#{value} "

        command += "`npm bin`/mocha -R #{__dirname}/../lib/index.js " +
            "--compilers coffee:coffee-script,coffee-trc:coffee-errors " +
            "#{__dirname + '/testData/' + fileName}"

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

    _checkResultFromFile = (fileName, {totalTestCount, skippedTestCount, failureTestCount}, cb) ->
        fs.readFile fileName, {encoding: 'utf8'}, (err, data) ->
            return cb err if err?
            parseXml data, (err, result) ->
                return cb err if err?

                results = result.testsuites.testsuite[0]['$']
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

        _triggerTest 'mocha_test.coffee', {"REPORT_FILE": reportFileName}, (error, stdout, stderr) ->
            expect(error).to.exist
            expect(error.code).to.equal 1

            _checkResultFromFile reportFileName,
                totalTestCount: 8
                skippedTestCount: 5
                failureTestCount: 1,
                (err) ->
                    done err

    it 'should respect the PREFIX env variable as path prefix of the test report file', (done) ->
        reportFileName = _newTempFileName()

        _createDir 'tmp/tmp', ->
            _triggerTest 'mocha_test.coffee', {"PREFIX": tempDir, "REPORT_FILE": reportFileName}, (error, stdout, stderr) ->
                expect(error).to.exist
                expect(error.code).to.equal 1

                _checkResultFromFile path.join(tempDir, reportFileName),
                    totalTestCount: 8
                    skippedTestCount: 5
                    failureTestCount: 1,
                    (err) ->
                        done err

    it.skip 'should work in a casper/phantom environment', (done) ->

    it.skip 'should report pre test errors in nodeJS environment', (done) ->

    it.skip 'should report pre test errors in casper/phantom environment', (done) ->
