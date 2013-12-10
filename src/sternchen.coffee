###
    custom actano reporter (derived from the mocha tap reporter)
###

# set the global state to enforce stacktrace for chai AssertionErrors

require('chai').Assertion.includeStack = true

class Sternchen
    constructor: (@runner) ->
        @n = 1
        @passes = 0
        @failures = 0;
        @initalizeEvents()

    initalizeEvents: ->
        @runner.on 'start', =>
            total = @runner.grepTotal(@runner.suite)
            console.log('%d..%d', 1, total)

        @runner.on 'test end', =>
            ++@n

        @runner.on 'pending', (test) =>
            console.log('ok %d %s # SKIP -', @n, @title(test))


        @runner.on 'pass', (test) =>
            @passes++
            console.log('ok %d %s', @n, @title(test))

        @runner.on 'fail', (test, err) =>
            @failures++;
            console.log('not ok %d %s', n, @title(test));
            if (err.stack)
                console.log(err.stack.replace(/^/gm, '  '))

        @runner.on 'end', =>
            console.log('# tests ' + (@passes + @failures));
            console.log('# pass ' + @passes);
            console.log('# fail ' + @failures);


    title: (test) ->
        return test.parent.fullTitle() + " : " + test.title;

module.exports = Sternchen

