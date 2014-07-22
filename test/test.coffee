{exec} = require 'child_process'
fs = require 'fs'
path = require 'path'

{expect} = require 'chai'
parseXml = require('xml2js').parseString
uuid = require 'node-uuid'
rimraf = require 'rimraf'

describe 'Sternchen Reporter', ->
    _triggerTest = (fileName, toFileName, cb) ->
        if typeof toFileName is 'function'
            cb = toFileName
            toFileName = ""

        command = "REPORT_FILE=#{toFileName} " +
            "`npm bin`/mocha -R #{__dirname}/../lib/index.js " +
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

    before (done) ->
        fs.exists 'tmp', (exists) ->
            return done() if exists
            fs.mkdir 'tmp', done

    after (done) ->
        rimraf 'tmp', done

    it 'should report test results to console', (done) ->
        _triggerTest 'mocha_test.coffee', (error, stdout, stderr) ->
            expect(error).to.not.exist
            _checkResult stdout,
                totalTestCount: 6
                runTestCount: 2
                passedTestCount: 2
                failureTestCount: 0
            done()

    it 'should report test results to file system (process.env.REPORT_FILE)', (done) ->
        reportFileName = path.join 'tmp', uuid.v4()
        _triggerTest 'mocha_test.coffee', reportFileName, (error, stdout, stderr) ->
            expect(error).to.not.exist
            
            _checkResultFromFile reportFileName,
                totalTestCount: 6
                skippedTestCount: 4
                failureTestCount: 0,
                (err) ->
                    done err


    it.skip 'should work in a casper/phantom environment', (done) ->

    it.skip 'should report pre test errors in nodeJS environment', (done) ->

    it.skip 'should report pre test errors in casper/phantom environment', (done) ->
