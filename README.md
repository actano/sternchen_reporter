sternchen_reporter
==================
xml reporter for jenkins

custom actano mocha reporter (in memorial of my lovely mother sheep sternchen)

set the global state require('chai').Assertion.includeStack = true
to enforce stacktrace for chai AssertionErrors.
you must use the same chai version as in your project to get it work


                                        _____
                                      _/  /  \_
                                    _/   /     \_
                                   /    /        \
                                   \_____________/
                                       |O   O|
                                       \     /
                                      **\ - /**
                                    /****\_/****\\
                                   /************* \
                                  / /************ _\
                                 / /************** \\
                                 |______ *********  \\
                                   ***************   **
                                    *************
                                    *************
                                     ***********
                                       || *  ||
                                       ~~    ~~


Motivation
====
This reporter produces XML files.

xunit reporter of mocha does also generate xml files, but they are not
usefull (at least in jenkins) because it's optimized for Java package structure.
The results are grouped (splitted) by a `.` instead of by the `describe` and `it`
hierarchy of the test file.



The console output is same as spec reporter.