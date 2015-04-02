beforeEach ->
    @currentTest.onFailure = (testReportDir) ->
        return "onFailure called with #{testReportDir}"

describe 'testsuite', ->
    it 'pass', (done) ->
        done()

    it.skip 'skip', (done) ->
        done()

    it 'fail', (done) ->
        throw new Error 'this should fail'