

describe 'successful testsuite', ->
    it 'should report a sucessful testrun', (done) ->
        done()

    it.skip 'should skip', (done) ->
        done()

    it 'should also report a sucessful testrun', (done) ->
        done()


describe.skip 'skipped testsuite', ->
    it 'should report a sucessful testrun', (done) ->
        done()

    it.skip 'should skip', (done) ->
        done()

    it 'should also report a sucessful testrun', (done) ->
        done()
