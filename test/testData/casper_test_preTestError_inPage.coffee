describe 'testsuite', ->
    before (done) ->
        casper.start 'testData/test_preTestError.html'
        casper.waitForSelector '.main', ->
            done()

    it 'should report a sucessful testrun', (done) ->
        casper.then ->
            done()

    it.skip 'should skip', (done) ->
        casper.then ->
            done()

    it 'should fail', (done) ->
        casper.then ->
            throw new Error 'this should fail'

    it 'should also report a sucessful testrun', (done) ->
        casper.then ->
            done()

describe.skip 'skipped testsuite', ->
    before ->
        casper.start 'test.html'

    it 'should report a sucessful testrun', (done) ->
        casper.then ->
            done()

    it.skip 'should skip', (done) ->
        casper.then ->
            done()

    it 'should fail', (done) ->
        casper.then ->
            throw new Error 'this should fail'

    it 'should also report a sucessful testrun', (done) ->
        casper.then ->
            done()
