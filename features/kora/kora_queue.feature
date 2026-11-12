@kora @kora_queue
Feature: kora_queue connection queue bookkeeping
  Checks of the queue state a connected player leaves behind, and of the
  queue, connecting and priority bookkeeping, through the functions
  exports.kora_queue:GetQueueExports() gives other resources.
  The @global scenarios drive that bookkeeping with fake entries whose ids
  start with "fft:", the way the resource's own rcon debug commands (addq,
  removeq, addc, removec, setpos) do, and remove every entry and priority they
  add as soon as the scenario ends. They need an idle queue and refuse to run
  while a real player waits or connects. Real players are never kicked,
  re-queued or given priority.
  Not covered: waiting in the queue as a real player, the adaptive card, grace
  and join-delay timers and the full-server refusal, which all happen while a
  player connects, before a tester exists; and OnJoin/CanJoin, whose join
  callbacks cannot be unregistered or belong to other resources.

  Background:
    Given resource "kora_queue" is running

  @server
  Scenario: A connected player is counted as joined
    Then the connection queue should list me as a joined player
    And the connection queue should count at least 1 joined players
    And the connection queue should count no more joined players than the server slot limit

  @server
  Scenario: A connected player is no longer queued or connecting
    Then I should not be waiting in the connection queue
    And I should not be in the connecting list of the connection queue

  @server
  Scenario: Queue sizes and fullness are consistent
    Then the connection queue should report whole-number waiting and connecting sizes
    And the connection queue fullness should match its own counts

  @server
  Scenario: The queue resolves the identifiers it prioritises by
    Then the connection queue should know my identifiers
    And the connection queue should answer my priority as a power or none

  @server
  Scenario: The queue replaces the stock hard cap
    Then the hard cap resource should not be running beside the connection queue

  @server
  Scenario: The queue identifies steam among my identifiers
    Then the connection queue should recognise whether I run steam
    And my queue identifiers should leave out unprioritised ip addresses

  @server
  Scenario: The queue follows the debug and display convars
    Then the connection queue display flags should follow the server convars
    And the connection queue first-join fullness should match its own counts

  # Expected values follow SteamID64 = 76561197960265728 + 2 * Z + Y.
  @server
  Scenario Outline: The queue converts hex steam ids to the legacy form
    Then the connection queue should convert the steam id "<hex>" to "<legacy>"

    Examples:
      | hex                   | legacy             |
      | steam:110000100000001 | steam_0:1:0        |
      | steam:110000100000002 | steam_0:0:1        |
      | steam:110000103fd1bb1 | steam_0:1:33459672 |
      | steam:11000010a2b3c4d | steam_0:1:85302822 |

  # The shipped Config.Priority lists a steam_0 row (sv_queue_config.lua), so
  # a legacy id is a real input. This is read-only.
  @server
  Scenario: The queue answers the priority of a legacy steam id
    Then the connection queue should answer the priority of the legacy id "steam_0:1:12345678" as a power or none

  @server
  Scenario: Priority calls without an id are refused
    Then giving queue priority to no id should be refused
    And removing queue priority from no id should be refused

  @server
  Scenario: Removing the priority of an unknown id is harmless
    Then the connection queue priority list should not hold "fft:never-added"
    When I remove the queue priority of "fft:never-added"
    Then the connection queue priority list should not hold "fft:never-added"
    And the connection queue should give "fft:never-added" no priority

  @server @global
  Scenario: Priority is added and removed again
    Given the test entry "fft:prio-a" has queue priority 42
    Then the connection queue priority list should hold "fft:prio-a" at 42
    And the connection queue should give "fft:prio-a" the priority 42
    When I remove the queue priority of "fft:prio-a"
    Then the connection queue priority list should not hold "fft:prio-a"
    And the connection queue should give "fft:prio-a" no priority

  @server @global
  Scenario: Priority ids are matched without regard to case
    Given the queue id "FFT:Prio-Case" is given priority 7
    Then the connection queue priority list should hold "fft:prio-case" at 7
    And the connection queue should give "FFT:PRIO-CASE" the priority 7
    When I remove the queue priority of "FFT:PRIO-case"
    Then the connection queue should give "fft:prio-case" no priority

  @server @global
  Scenario: A non-numeric priority power falls back to 10
    Given the test entry "fft:prio-text" is given the non-numeric queue priority "high"
    Then the connection queue should give "fft:prio-text" the priority 10

  @server @global
  Scenario: Re-adding a priority replaces its power
    Given the test entry "fft:prio-b" has queue priority 30
    And the test entry "fft:prio-b" has queue priority 5
    Then the connection queue should give "fft:prio-b" the priority 5

  @server @global
  Scenario: Several priorities are added through a table
    Given the test entries get queue priority through a table:
      """
      { "fft:table-a": 12, "fft:table-b": 14 }
      """
    Then the connection queue should give "fft:table-a" the priority 12
    And the connection queue should give "fft:table-b" the priority 14

  @server @global
  Scenario: A table with a non-numeric power is refused
    Then giving queue priority through a table with the power "high" for "fft:table-bad" should be refused
    And the connection queue should give "fft:table-bad" no priority

  @server @global
  Scenario: A legacy steam priority applies to the matching hex steam id
    Then the connection queue should give "steam:110000100000001" no priority
    Given the legacy steam id "steam_0:1:0" is given priority 33
    Then the connection queue should give "steam:110000100000001" the priority 33
    And the connection queue should give "steam:110000100000002" no priority

  @server @global
  Scenario: A temporary priority is reported with its end time
    Given the test entry "fft:temp-a" has temporary queue priority 40 for 60 seconds
    Then the connection queue should give "fft:temp-a" a temporary priority of 40
    And the connection queue should give "fft:temp-a" the priority 40

  @server @global
  Scenario Outline: The higher of a permanent and a temporary priority wins
    Given the test entry "fft:mixed" has queue priority <permanent>
    And the test entry "fft:mixed" has temporary queue priority <temporary> for 60 seconds
    Then the connection queue should give "fft:mixed" the priority <expected>

    Examples:
      | permanent | temporary | expected |
      | 20        | 30        | 30       |
      | 50        | 30        | 50       |

  @server @global
  Scenario: Waiting entries join the end of the queue in arrival order
    Given the connection queue has no waiting or connecting players
    And a test entry "fft:queue-a" waits in the connection queue
    And a test entry "fft:queue-b" waits in the connection queue
    And a test entry "fft:queue-c" waits in the connection queue
    Then the connection queue should hold 3 waiting players
    And the test entry "fft:queue-a" should be number 1 in the connection queue
    And the test entry "fft:queue-b" should be number 2 in the connection queue
    And the test entry "fft:queue-c" should be number 3 in the connection queue
    And the connection queue should count no waiting players with temporary priority

  @server @global
  Scenario: Adding a waiting entry twice keeps one place
    Given the connection queue has no waiting or connecting players
    And a test entry "fft:queue-a" waits in the connection queue
    And a test entry "fft:queue-b" waits in the connection queue
    Then adding the test entry "fft:queue-a" to the connection queue again should change nothing
    And the connection queue should hold 2 waiting players

  @server @global
  Scenario: A prioritised entry is placed ahead of entries without priority
    Given the connection queue has no waiting or connecting players
    And the test entry "fft:queue-vip" has queue priority 50
    And a test entry "fft:queue-a" waits in the connection queue
    And a test entry "fft:queue-b" waits in the connection queue
    And a test entry "fft:queue-vip" waits in the connection queue
    Then the test entry "fft:queue-vip" should be number 1 in the connection queue
    And the test entry "fft:queue-a" should be number 2 in the connection queue
    And the test entry "fft:queue-b" should be number 3 in the connection queue

  @server @global
  Scenario: A higher priority is placed ahead of a lower one
    Given the connection queue has no waiting or connecting players
    And the test entry "fft:queue-low" has queue priority 10
    And the test entry "fft:queue-high" has queue priority 60
    And a test entry "fft:queue-low" waits in the connection queue
    And a test entry "fft:queue-high" waits in the connection queue
    Then the test entry "fft:queue-high" should be number 1 in the connection queue
    And the test entry "fft:queue-low" should be number 2 in the connection queue

  @server @global
  Scenario: An equal priority keeps arrival order
    Given the connection queue has no waiting or connecting players
    And the test entry "fft:queue-first" has queue priority 20
    And the test entry "fft:queue-second" has queue priority 20
    And a test entry "fft:queue-first" waits in the connection queue
    And a test entry "fft:queue-second" waits in the connection queue
    Then the test entry "fft:queue-first" should be number 1 in the connection queue
    And the test entry "fft:queue-second" should be number 2 in the connection queue

  @server @global
  Scenario: Waiting entries with a temporary priority are counted
    Given the connection queue has no waiting or connecting players
    And the test entry "fft:queue-temp" has temporary queue priority 15 for 60 seconds
    And a test entry "fft:queue-a" waits in the connection queue
    And a test entry "fft:queue-temp" waits in the connection queue
    Then the connection queue should count 1 waiting players with temporary priority
    And the test entry "fft:queue-temp" should be number 1 in the connection queue

  @server @global
  Scenario: A waiting entry is moved and removed
    Given the connection queue has no waiting or connecting players
    And a test entry "fft:queue-a" waits in the connection queue
    And a test entry "fft:queue-b" waits in the connection queue
    And a test entry "fft:queue-c" waits in the connection queue
    When I move the test entry "fft:queue-c" to position 1 in the connection queue
    Then the test entry "fft:queue-c" should be number 1 in the connection queue
    And the test entry "fft:queue-a" should be number 2 in the connection queue
    And the test entry "fft:queue-b" should be number 3 in the connection queue
    When I remove the test entry "fft:queue-a" from the connection queue
    Then the test entry "fft:queue-a" should not be in the connection queue
    And the connection queue should hold 2 waiting players
    And the test entry "fft:queue-b" should be number 2 in the connection queue

  @server @global
  Scenario Outline: Moving a waiting entry outside the queue is refused
    Given the connection queue has no waiting or connecting players
    And a test entry "fft:queue-a" waits in the connection queue
    And a test entry "fft:queue-b" waits in the connection queue
    Then moving the test entry "fft:queue-a" to position <position> should be refused
    And the test entry "fft:queue-b" should be number 2 in the connection queue

    Examples:
      | position |
      | 0        |
      | -1       |
      | 3        |

  @server @global
  Scenario: A waiting entry is removed by its position
    Given the connection queue has no waiting or connecting players
    And a test entry "fft:queue-a" waits in the connection queue
    And a test entry "fft:queue-b" waits in the connection queue
    When I remove queue position 1 from the connection queue
    Then the test entry "fft:queue-a" should not be in the connection queue
    And the test entry "fft:queue-b" should be number 1 in the connection queue

  @server @global
  Scenario: Removing an entry that is not waiting changes nothing
    Given the connection queue has no waiting or connecting players
    And a test entry "fft:queue-a" waits in the connection queue
    When I remove the test entry "fft:queue-missing" from the connection queue
    Then the connection queue should hold 1 waiting players
    And the test entry "fft:queue-a" should be number 1 in the connection queue

  @server @global
  Scenario: More than one waiting entry blocks a first join
    Given the connection queue has no waiting or connecting players
    And a test entry "fft:queue-a" waits in the connection queue
    Then the connection queue first-join fullness should match its own counts
    Given a test entry "fft:queue-b" waits in the connection queue
    Then the connection queue should not let a first join through
    And the connection queue first-join fullness should match its own counts

  @server @global
  Scenario: The server name shows how many players wait
    Given the connection queue has no waiting or connecting players
    And a test entry "fft:queue-a" waits in the connection queue
    And a test entry "fft:queue-b" waits in the connection queue
    Then the server name should show 2 waiting players
    When I remove the test entry "fft:queue-a" from the connection queue
    And I remove the test entry "fft:queue-b" from the connection queue
    Then the server name should not show a waiting count

  @server @global
  Scenario: A debug entry is listed as connecting and removed again
    Given the connection queue has no waiting or connecting players
    And a debug entry is in the connecting list
    Then the connection queue should count 1 connecting players
    And the queue id "debug" should be in the connecting list
    And the connection queue fullness should match its own counts
    When I remove the queue id "debug" from the connecting list
    Then the connection queue should count 0 connecting players
    And removing the queue id "debug" from the connecting list should find nothing

  @server @global
  Scenario: Only the first waiting entry is let through to connecting
    Given the connection queue has no waiting or connecting players
    And a test entry "fft:queue-a" waits in the connection queue
    And a test entry "fft:queue-b" waits in the connection queue
    Then letting the test entry "fft:queue-b" through to the connecting list should be refused
    And the test entry "fft:queue-a" should be let through to the connecting list
    And the queue id "fft:queue-a" should be in the connecting list
    And the test entry "fft:queue-a" should not be in the connection queue
    And the test entry "fft:queue-b" should be number 1 in the connection queue
    And the connection queue should count 1 connecting players
    When I remove the queue id "fft:queue-a" from the connecting list
    Then the queue id "fft:queue-a" should not be in the connecting list
