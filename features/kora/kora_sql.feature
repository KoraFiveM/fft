@kora @kora_sql
Feature: kora_sql database layer reads
  Read-only checks of the database layer through its real exports: readiness,
  version, constant SELECTs, statistics and the oxmysql bridge. Every statement
  is a SELECT of constants or of a table that does not exist.
  Not covered, on purpose: execute/insert/update, transactions, write-behind
  queues (enqueue/flush), schema helpers (ensureTables), resetStats and the
  /kora_sql console commands. They write to or reconfigure the live database, and
  this suite never writes, alters or drops anything. The failing-read scenario
  makes kora_sql print one error line to the server console; that is expected.

  Background:
    Given resource "kora_sql" is running

  @server
  Scenario: Database layer is connected and identifies itself
    Then the database layer should be ready
    And the database layer should report its server version and driver "kora_sql/1.0.0"

  @server
  Scenario: Scalar read returns a constant
    When I read the database scalar "SELECT 1"
    Then the database read should answer the number 1

  @server
  Scenario: Scalar read binds a parameter
    When I read the database scalar "SELECT ? AS answer" with the parameter 42
    Then the database read should answer the number 42

  @server
  Scenario: Query read returns a row list
    When I read the database rows "SELECT 7 AS n"
    Then the database read should answer exactly 1 rows
    And database row 1 should have "n" equal to the number 7

  @server
  Scenario: Single read answers nothing when no row matches
    When I read the single database row "SELECT 1 AS n FROM DUAL WHERE 1 = 0"
    Then the database read should answer no row

  @server
  Scenario: Statistics count the reads
    Given I remember how many database queries were counted
    When I read the database scalar "SELECT 1"
    Then the counted database queries should have grown
    And the database statistics should include error and queue counters
    And the slow query log should answer a list of at most 5 entries

  @server
  Scenario: An idle character has no database operation in flight
    Then my character should have no active database operation

  @server
  Scenario: oxmysql bridge serves legacy reads
    When I read the database scalar "SELECT 1" through the oxmysql bridge
    Then the database read should answer the number 1

  @server @rejection
  Scenario: A failing read reports its error to the caller
    # kora_sql logs a failed export call in red before answering the caller:
    # kora_sql/server/js/exports.js:60 ends the line with "; SQL: <statement>".
    Given I expect a console error from "kora_sql" containing "; SQL: SELECT 1 FROM fft_table_that_does_not_exist"
    When I read the database rows "SELECT 1 FROM fft_table_that_does_not_exist"
    Then the database read should fail with an error

  @server @rejection
  Scenario: oxmysql bridge refuses a multi-statement query
    Then the oxmysql bridge should refuse the two-statement read "SELECT 1; SELECT 2"
    When I read the database scalar "SELECT 1"
    Then the database read should answer the number 1

  # ---------------------------------------------------------------------------
  # Round 3: identity, parameters, result shapes, the other read exports,
  # legacy bridges, transactions and checked operations over SELECTs, schema
  # reads and statistics. Still nothing is written, altered or reset.
  # ---------------------------------------------------------------------------

  @server
  Scenario: Reported version matches the database's own version string
    Then the database layer should report the same server version as the database itself

  @server
  Scenario: The ready callback confirms the connection
    Then the database layer should confirm readiness through its ready callback

  @server
  Scenario Outline: Legacy bridges report the database as ready
    Then the "<bridge>" bridge should report the database as ready

    Examples:
      | bridge      |
      | oxmysql     |
      | mysql-async |

  @server
  Scenario: An unknown character has no database operation in flight
    Then the character "FFT_NO_SUCH_CITIZEN" should have no active database operation

  # Bootstrapped by kora_sql/server/js/index.js at start-up.
  @server
  Scenario: The driver's own bookkeeping tables exist
    Then the database tables "kora_sql_schema_owners" and "kora_sql_deadletter" should exist

  @server @rejection
  Scenario: Waiting for a missing table times out with its name
    # kora_sql/server/js/schema.js:495, logged by exports.js:60.
    Given I expect a console error from "kora_sql" containing "tables not created within the timeout: fft_no_such_table"
    When I wait 300 milliseconds for the database table "fft_no_such_table"
    Then the database read should fail with an error containing "tables not created within the timeout: fft_no_such_table"

  @server @rejection
  Scenario: Waiting for a table with an invalid name is refused
    # kora_sql/server/js/schema.js:485 (IDENT is ^[A-Za-z0-9_]{1,64}$).
    Given I expect a console error from "kora_sql" containing "awaitTables expects a list of table names"
    When I wait 300 milliseconds for the database table "fft-bad-name"
    Then the database read should fail with an error containing "awaitTables expects a list of table names"

  @server
  Scenario: Query read returns several rows in order
    When I read the database rows "SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3"
    Then the database read should answer exactly 3 rows
    And database row 1 should have "n" equal to the number 1
    And database row 3 should have "n" equal to the number 3

  @server
  Scenario: Query read with no match answers an empty list
    When I read the database rows "SELECT 1 AS n FROM DUAL WHERE 1 = 0"
    Then the database read should answer exactly 0 rows

  @server
  Scenario: Single read answers the first of several rows
    When I read the single database row "SELECT 4 AS n UNION ALL SELECT 5"
    Then the database read should answer a row with "n" equal to the number 4

  @server
  Scenario Outline: Scalar read with no value answers nothing
    When I read the database scalar "<sql>"
    Then the database read should answer an empty value

    Examples:
      | sql                                 |
      | SELECT NULL AS n                    |
      | SELECT 1 AS n FROM DUAL WHERE 1 = 0 |

  # pool.js: decimalNumbers true, supportBigNumbers true, bigNumberStrings false.
  @server
  Scenario: A decimal arrives as a number
    When I read the database scalar "SELECT CAST(1.25 AS DECIMAL(10,2)) AS d"
    Then the database read should answer the decimal 1.25

  @server
  Scenario: An integer beyond double precision arrives as exact text
    When I read the database scalar "SELECT CAST(9007199254740993 AS SIGNED) AS big"
    Then the database read should answer the text "9007199254740993"

  @server
  Scenario: Scalar read binds two positional parameters
    When I read the database scalar "SELECT ? + ? AS total" with the parameters 2 and 3
    Then the database read should answer the number 5

  @server
  Scenario Outline: Scalar read binds a text parameter unchanged
    When I read the database scalar "SELECT ? AS s" with the text parameter "<value>"
    Then the database read should answer the text "<value>"

    Examples:
      | value                 |
      | fft                   |
      |                       |
      | O'Brien; DROP x -- ?  |
      | Kora ✓ ünïcode        |

  @server
  Scenario: Scalar read binds a long text parameter
    When I read the database scalar "SELECT ? AS s" with a 2000 character text parameter
    Then the database read should answer a text of 2000 characters

  # normalizeNamedPlaceholders in kora_sql/server/js/execute.js.
  @server
  Scenario Outline: Scalar read binds a named parameter
    When I read the database scalar "<sql>" with the named parameter "<key>" set to 9
    Then the database read should answer the number 9

    Examples:
      | sql             | key |
      | SELECT :v AS v  | v   |
      | SELECT :v AS v  | :v  |
      | SELECT @v AS v  | @v  |

  @server
  Scenario: An @name inside a string literal is not a placeholder
    When I read the database scalar "SELECT '@v' AS s" with the named parameter "@v" set to 9
    Then the database read should answer the text "@v"

  @server
  Scenario: A missing positional parameter is bound as NULL
    When I read the database rows "SELECT ? AS a, ? AS b, ? AS c" with only the parameters 1 and 3 set to 1 and 3
    Then database row 1 should have "a" equal to the number 1
    And database row 1 should have no "b"
    And database row 1 should have "c" equal to the number 3

  # kora_sql/docs.md "Protocol choice": batch and transaction statements with a
  # table or list bind use the text protocol, where a list expands to 1,2,3 and
  # an object is sent as its JSON text.
  @server
  Scenario: A list parameter expands for IN inside a batch
    When I run the database read "SELECT 3 IN (?) AS found" as a batch with the list parameter 1, 2 and 3
    Then database row 1 should have "found" equal to the number 1

  @server
  Scenario: An object parameter is sent as JSON text inside a batch
    When I run the database read "SELECT ? AS j" as a batch with an object parameter whose "a" is 1
    Then database row 1 should have "j" as JSON text whose "a" is the number 1

  # Same docs.md paragraph: an ordinary prepared read sends the list as the
  # text '[1,2,3]', which silently matches nothing.
  @server
  Scenario: A list parameter on an ordinary read does not expand
    When I read the database scalar "SELECT 3 IN (?) AS found" with the list parameter 1, 2 and 3
    Then the database read should answer the number 0

  @server
  Scenario: Prepare answers a single value for a one-column read
    When I prepare the database read "SELECT ? AS n" with the parameter 6
    Then the database read should answer the number 6

  @server
  Scenario: Prepare runs once per parameter set
    When I prepare the database read "SELECT ? AS n" with the parameter sets 1 and 2
    Then the database read should answer the numbers 1 and 2

  @server
  Scenario: The execute export on a read carries its rows
    When I run the database read "SELECT 1 AS n UNION ALL SELECT 2" through the execute export
    Then the execute answer should report 0 affected rows and 2 rows

  @server
  Scenario Outline: Write-shaped exports on a read report nothing changed
    When I run the database read "SELECT 1 AS n" through the <export> export
    Then the database read should answer the number 0

    Examples:
      | export |
      | update |
      | insert |

  @server
  Scenario: A stored statement runs through its handle
    When I store the database read "SELECT ? AS n" and run it with the parameter 8
    Then the database read should answer exactly 1 rows
    And database row 1 should have "n" equal to the number 8

  @server @rejection
  Scenario: An unknown stored statement handle answers nothing
    When I run the unknown stored statement handle 987654321
    Then the database read should answer an empty value

  @server
  Scenario: A batch of reads answers each result in order
    When I run the database reads "SELECT 1 AS a" and "SELECT 2 AS b" as a batch
    Then batch result 1 should have "a" equal to the number 1
    And batch result 2 should have "b" equal to the number 2

  @server @rejection
  Scenario Outline: A malformed read reports its error to the caller
    # kora_sql/server/js/exports.js:60 ends the line with "; SQL: <statement>".
    Given I expect a console error from "kora_sql" containing "; SQL: <sql>"
    And I remember the database error count
    When I read the database rows "<sql>"
    Then the database read should fail with an error
    And the database error count should have grown

    Examples:
      | sql                             |
      | SELECT FROM                     |
      | SELECT fft_no_such_column       |
      | SELECT * FROM fft_no_such_table |

  @server
  Scenario: A parameterised read reuses the prepared statement cache
    Given I read the database scalar "SELECT ? AS fft_cache_probe" with the parameter 1
    And I remember the prepared statement cache hits
    When I read the database scalar "SELECT ? AS fft_cache_probe" with the parameter 2
    Then the database read should answer the number 2
    And the prepared statement cache hits should have grown

  @server @slow
  Scenario: A slow read is recorded with the resource that ran it
    When I run a database read slower than the slow query threshold
    Then the database read should answer the number 0
    And the slow query log should list that read for this test runner
    And the slow query log should answer a list of at most 1 entries

  # Legacy bridges: kora_sql/server/compat/*.lua.
  @server
  Scenario Outline: Legacy bridges serve constant reads
    When I read "SELECT 1 AS n" through the legacy "<bridge>" export "<export>"
    Then the database read should answer the number 1

    Examples:
      | bridge      | export             |
      | mysql-async | mysql_fetch_scalar |
      | ghmattimysql | scalar            |
      | oxmysql     | scalar             |

  @server
  Scenario Outline: Legacy bridges serve row lists
    When I read "SELECT 1 AS n UNION ALL SELECT 2" through the legacy "<bridge>" export "<export>"
    Then the database read should answer exactly 2 rows
    And database row 2 should have "n" equal to the number 2

    Examples:
      | bridge       | export          |
      | mysql-async  | mysql_fetch_all |
      | ghmattimysql | execute         |
      | oxmysql      | query           |
      | oxmysql      | fetch           |

  @server
  Scenario: oxmysql bridge single read answers one row
    When I read "SELECT 3 AS n UNION ALL SELECT 4" through the legacy "oxmysql" export "single"
    Then the database read should answer a row with "n" equal to the number 3

  @server
  Scenario: oxmysql bridge prepare binds a parameter
    When I read "SELECT ? AS n" with the parameter 11 through the legacy "oxmysql" export "prepare"
    Then the database read should answer the number 11

  @server
  Scenario Outline: Blocking legacy reads answer directly
    When I read "SELECT 1 AS n" through the blocking legacy "<bridge>" export "<export>"
    Then the database read should answer the number 1

    Examples:
      | bridge       | export     |
      | oxmysql      | scalarSync |
      | ghmattimysql | scalarSync |

  # oxmysql's typeCast port (kora_sql/server/js/typecast.js) on the bridge only.
  @server
  Scenario: oxmysql bridge returns JSON columns as text
    Given the oxmysql bridge typecast is enabled
    When I read "SELECT JSON_OBJECT('a', 1) AS j" through the legacy "oxmysql" export "scalar"
    Then the database read should answer JSON text whose "a" is the number 1

  @server
  Scenario Outline: oxmysql bridge returns dates as millisecond timestamps
    Given the oxmysql bridge typecast is enabled
    When I read "<sql>" through the legacy "oxmysql" export "scalar"
    Then the database read should answer a millisecond timestamp for "<moment>" in some time zone

    Examples:
      | sql                                                | moment              |
      | SELECT CAST('2020-01-02 03:04:05' AS DATETIME) AS d | 2020-01-02 03:04:05 |
      | SELECT CAST('2020-01-02' AS DATE) AS d             | 2020-01-02          |

  @server
  Scenario: oxmysql bridge returns a NULL date as nothing
    Given the oxmysql bridge typecast is enabled
    When I read "SELECT CAST(NULL AS DATETIME) AS d" through the legacy "oxmysql" export "scalar"
    Then the database read should answer an empty value

  # looksMultiStatement in kora_sql/server/compat/oxmysql.lua ignores a
  # trailing semicolon and semicolons inside quotes.
  @server
  Scenario Outline: oxmysql bridge allows a semicolon that is not a second statement
    When I read "<sql>" through the legacy "oxmysql" export "scalar"
    Then the database read should answer the text "<answer>"

    Examples:
      | sql                    | answer |
      | SELECT 'a;b' AS s      | a;b    |
      | SELECT 'ok' AS s;      | ok     |
      | SELECT `a;b` FROM (SELECT 'ok' AS `a;b`) AS t | ok |

  @server @rejection
  Scenario Outline: oxmysql bridge refuses multi-statement reads on every guarded export
    Then the oxmysql bridge <export> export should refuse the two-statement read "SELECT 1; SELECT 2"

    Examples:
      | export  |
      | scalar  |
      | single  |
      | prepare |

  @server @rejection
  Scenario: oxmysql bridge passes a failing read's error to the caller
    # Logged by kora_sql/server/js/exports.js:60 for the oxQuery export.
    Given I expect a console error from "kora_sql" containing "; SQL: SELECT 1 FROM fft_ox_missing_table"
    When I read "SELECT 1 FROM fft_ox_missing_table" through the legacy "oxmysql" export "query"
    Then the database read should fail with an error

  # Transactions over SELECTs only: kora_sql/server/js/transaction.js.
  @server
  Scenario: A transaction of reads commits
    When I run the database reads "SELECT 1 AS a" and "SELECT 2 AS b" in a transaction
    Then the database transaction should have committed

  @server @rejection
  Scenario: A transaction with a failing read rolls back and reports it
    Given I expect a console error from "kora_sql" containing "kora_sql transaction rolled back"
    When I run the database reads "SELECT 1 AS a" and "SELECT 1 FROM fft_txn_missing_table" in a transaction
    Then the database transaction should have rolled back reporting "fft_txn_missing_table"

  @server
  Scenario: A checked read without a row expectation succeeds
    When I run the checked database read "SELECT 1 AS n UNION ALL SELECT 2"
    Then the checked database operation should succeed with 1 result

  @server
  Scenario: A checked read whose row count matches succeeds
    When I run the checked database read "SELECT 1 AS n UNION ALL SELECT 2" expecting 2 rows
    Then the checked database operation should succeed with 1 result

  @server @rejection
  Scenario Outline: A checked read whose row count differs reports a conflict
    When I run the checked database read "SELECT 1 AS n" expecting <rows> rows
    Then the checked database operation should fail with the code "conflict" at statement 1
    And the checked database operation message should be "Transaction precondition changed"

    Examples:
      | rows |
      | 0    |
      | 2    |

  @server @rejection
  Scenario: A checked read reports its own failure code
    When I run the checked database read "SELECT 1 AS n FROM DUAL WHERE 1 = 0" expecting 1 rows with the failure code "fft_missing_row"
    Then the checked database operation should fail with the code "fft_missing_row" at statement 1

  @server @rejection
  Scenario: A checked read with a failing statement is unavailable
    When I run the checked database read "SELECT 1 FROM fft_checked_missing_table"
    Then the checked database operation should fail with the code "unavailable" at statement 1
    And the checked database operation message should be "Database transaction could not be confirmed"

  @server @rejection
  Scenario: A negative row expectation is refused
    # kora_sql/server/js/transaction.js:84, logged by exports.js:60.
    Given I expect a console error from "kora_sql" containing "expectedRows must be a non-negative integer"
    When I run the checked database read "SELECT 1 AS n" expecting -1 rows
    Then the database read should fail with an error containing "expectedRows must be a non-negative integer"

  @server @rejection
  Scenario: An empty checked transaction is refused
    Given I expect a console error from "kora_sql" containing "Checked transaction requires statements"
    When I run an empty checked database transaction
    Then the database read should fail with an error containing "Checked transaction requires statements"

  # An operation key claims the tester's citizenid for the 2 s of a SELECT SLEEP.
  @server @slow
  Scenario: A claimed checked read marks my character busy until it settles
    When I start a slow checked database read claimed for my character
    Then my character should have an active database operation
    And another request with the same operation key should be refused as indeterminate
    And waiting on the operation key with another fingerprint should report it indeterminate
    And the slow checked database read should succeed
    And the operation key should no longer be active
    And my character should have no active database operation

  @server
  Scenario: Waiting on a prefix with no operations settles nothing
    Then waiting for checked operations with the prefix "fft_sql_none_" should settle 0

  @server @rejection
  Scenario: Waiting on operations without a prefix is refused
    # kora_sql/server/js/transaction.js:72, logged by exports.js:60.
    Given I expect a console error from "kora_sql" containing "An operation key prefix is required"
    When I wait for checked operations without a prefix
    Then the database read should fail with an error containing "An operation key prefix is required"
