@kora @kora_weathersync
Feature: kora_weathersync synchronized weather and clock
  kora_weathersync owns one server-held weather, clock, time-freeze and
  blackout state, publishes it through GlobalState and applies it on every
  client. Weather and time are visible to every player, so these scenarios read
  the state and assert refusals. The one scenario that writes (tagged @global)
  writes back the values already in force.

  Not covered: successful weather, time, freeze and blackout changes through
  the commands or exports (they change the world for every player and the
  tester's permission tier is unknown), the dynamic weather scheduler and
  nextWeatherStage (timer driven, global), weather blending and the rain, snow
  and gravity effects (visual), and the qb-weathersync DisableSync and
  EnableSync events.

  Background:
    Given resource "kora_weathersync" is running

  @server
  Scenario: Weather state is complete and within range
    Then the weather state should be valid

  @server
  Scenario: Published global state matches the weather service
    Then the published weather state should match the weather service

  @server
  Scenario: Individual getters agree with the full state
    Then the weather getters should agree with the weather state

  @server
  Scenario: Legacy qb-weathersync exports report the same state
    Then the legacy weather exports should report the same weather state

  @server @rejection
  Scenario: An unknown weather type is refused
    Then setting the weather to "FFT_NOT_WEATHER" should be refused as an unknown weather type
    And the weather state should be unchanged

  @server @rejection
  Scenario Outline: A time outside the clock range is refused
    Then setting the synchronized clock to hour <hour> minute <minute> should be refused
    And the weather state should be unchanged

    Examples:
      | hour | minute |
      | 24   | 0      |
      | 12   | 60     |
      | -1   | 30     |

  Scenario: Client lists the configured weather types
    Then the weather type list should include the current weather

  Scenario: Client game clock follows the synchronized time
    Then my game clock should follow the synchronized time

  Scenario: A state sync request is answered once per cooldown
    When I ask for a weather state sync twice in a row
    Then I should receive exactly one weather state reply

  # /weather and /time are registered by both kora_weathersync and kora_admin;
  # whichever owns the command, an invalid argument changes nothing.
  @ui @rejection
  Scenario Outline: A world control command with an invalid argument changes nothing
    Given I remember the weather state
    When I run the command "<command>"
    Then the world control command should be refused for lack of permission or with "<reason>"
    And the weather state should be unchanged

    Examples:
      | command                 | reason                |
      | weather FFT_NOT_WEATHER | unknown weather type  |
      | time 99                 | hour must be          |
      | blackout maybe          | expected true/false   |
      | freezetime maybe        | expected true/false   |

  # Only changes anything if the server wrongly honours a player-sent event.
  @rejection @global
  Scenario: A player cannot change the weather with the server-only event
    Given I guard the weather against a forged change
    When I send a forged weather change as a player
    Then the weather state should be unchanged

  @server @global
  Scenario: Reapplying the current settings republishes the state without changing it
    When I reapply the current clock, time freeze and blackout settings
    Then the weather state revision should have advanced by at least 3
    And the weather state should be unchanged
    And the published weather state should match the weather service

  # ---------------------------------------------------------------------------
  # Round 3: more refusals of the native and legacy setters, write-back of the
  # current values through the legacy setters, every server-only event forged
  # by a player, state-sync replies and the client-local legacy events, which
  # change only the tester's own view and are resynchronised before the end.
  # ---------------------------------------------------------------------------

  @server @rejection
  Scenario Outline: A weather name that is not exactly configured is refused
    Then setting the weather to "<weather>" should be refused as an unknown weather type
    And the weather state should be unchanged

    Examples:
      | weather      |
      |              |
      | SUNNY        |
      | CLEAR RAIN   |
      | CLEAR;RAIN   |
      | clouds_      |
      | RAINY        |

  @server @rejection
  Scenario Outline: A weather value that is not text is refused
    Then setting the weather to a <kind> value should be refused as an unknown weather type
    And the weather state should be unchanged

    Examples:
      | kind    |
      | number  |
      | nothing |
      | true    |

  # validInteger(value, 0, 23|59) in kora_weathersync/server/state.lua.
  @server @rejection
  Scenario Outline: More clock values outside the range are refused
    Then setting the synchronized clock to hour <hour> minute <minute> should be refused
    And the weather state should be unchanged

    Examples:
      | hour | minute |
      | 23   | 60     |
      | 0    | -1     |
      | 100  | 0      |
      | -24  | -60    |

  @server @rejection
  Scenario Outline: A fractional clock value is refused
    Then setting the synchronized clock to the fractional hour <hour> minute <minute> should be refused
    And the weather state should be unchanged

    Examples:
      | hour | minute |
      | 12.5 | 0.0    |
      | 12.0 | 30.5   |
      | 0.01 | 0.0    |

  @server @rejection
  Scenario: A clock given as text is refused by the native export
    Then setting the synchronized clock with the text "12" and "30" should be refused
    And the weather state should be unchanged

  @server @rejection
  Scenario: The native clock export needs a minute
    Then setting the synchronized clock to the current hour without a minute should be refused
    And the weather state should be unchanged

  @server
  Scenario: Legacy clock and dynamic weather getters report the same state
    Then the legacy weather clock and dynamic weather should match the weather state

  @server @rejection
  Scenario: The legacy weather export refuses an unknown weather with a bare false
    Then the legacy weather export should refuse the weather "FFT_NOT_WEATHER"
    And the weather state should be unchanged

  # legacyTime in server/state.lua.
  @server @rejection
  Scenario Outline: The legacy clock export refuses a time it cannot use
    Then the legacy clock export should refuse hour "<hour>" minute "<minute>"
    And the weather state should be unchanged

    Examples:
      | hour | minute |
      | 25   | 0      |
      | -1   | 0      |
      | noon | 0      |
      | 12   | -5     |
      |      | 0      |

  # README: the legacy setTime accepts numeric strings and floors fractions.
  # The values written are the ones already in force.
  @server @global
  Scenario: The legacy clock export accepts the current time as text
    When I write the current clock back through the legacy export as text
    Then the weather state revision should have advanced by at least 1
    And the weather state should be unchanged

  @server @global
  Scenario: The legacy clock export floors fractional values
    When I write the current clock back through the legacy export with fractions
    Then the weather state revision should have advanced by at least 1
    And the weather state should be unchanged

  @server @global
  Scenario: The legacy freeze and blackout setters accept the current values
    When I write the current time freeze and blackout back through the legacy exports
    Then the weather state revision should have advanced by at least 2
    And the weather state should be unchanged
    And the published weather state should match the weather service

  # serverOnly() in server/state.lua ignores every one of these from a player.
  @rejection @global
  Scenario Outline: A player cannot drive a server-only weather event
    Given I guard every weather setting against a forged change
    When I send the forged event "<event>" as a player
    Then the weather state should be unchanged

    Examples:
      | event                                     |
      | kora_weathersync:server:setTime           |
      | qb-weathersync:server:setWeather          |
      | qb-weathersync:server:setTime             |
      | qb-weathersync:server:toggleBlackout      |
      | qb-weathersync:server:toggleFreezeTime    |
      | qb-weathersync:server:toggleDynamicWeather |

  # Both request events share one 2 s per-player cooldown (server/state.lua).
  Scenario: Both sync request events share one cooldown
    When I ask for a weather state sync on both request events in a row
    Then I should receive exactly 1 weather state replies
    And the weather state reply should match the published state

  Scenario: A sync request after the cooldown is answered again
    When I ask for a weather state sync twice with the cooldown between
    Then I should receive exactly 2 weather state replies
    And the weather state reply should match the published state

  Scenario: The client lists exactly the configured weather types
    Then the weather type list should be the configured list in order

  @world
  Scenario: Client game weather follows the synchronized weather
    Then my game weather should follow the synchronized weather

  # Config.weatherEffects rainLevel: RAIN 0.35, THUNDER 0.70, others none.
  @world
  Scenario: Client rain level follows the synchronized weather
    Then my rain level should follow the synchronized weather

  # Client-local legacy events (client/main.lua). They change only the
  # tester's view; a fresh state sync restores it.
  Scenario: The legacy time event shifts only my clock until the next sync
    When I shift my local clock by 6 hours with the legacy time event
    Then my game clock should show the shifted hour
    When I request a fresh weather state sync
    Then my game clock should follow the synchronized time

  @rejection
  Scenario Outline: The legacy time event ignores values that are not numbers
    When I send the legacy time event with the values "<base>" and "<offset>"
    Then my game clock should follow the synchronized time

    Examples:
      | base | offset |
      | abc  | 0      |
      | 600  | xyz    |
      |      |        |

  @world
  Scenario: The legacy weather event changes only my rain until the next sync
    When I send the legacy weather event for a rainier weather
    Then my rain level should show the local weather
    When I request a fresh weather state sync
    Then my rain level should follow the synchronized weather

  @rejection @world
  Scenario: The legacy weather event ignores an unknown weather
    When I send the legacy weather event for the unknown weather "FFT_NOT_WEATHER"
    Then my rain level should follow the synchronized weather
    And my game clock should follow the synchronized time

  @world
  Scenario: Suspending sync shows the interior view until it is resumed
    When I suspend weather sync with the legacy event
    Then my game should show the suspended interior view
    When I resume weather sync with the legacy event
    Then my game clock should follow the synchronized time
    And my rain level should follow the synchronized weather

  # More invalid command arguments; refused by the permission gate or the
  # command's own validation (server/commands.lua, kora_lib dispatch).
  @ui @rejection
  Scenario Outline: More world control commands with invalid arguments change nothing
    Given I remember the weather state
    When I run the command "<command>"
    Then the world control command should be refused for lack of permission or with "<reason>"
    And the weather state should be unchanged

    Examples:
      | command          | reason                       |
      | weather          | Missing arguments for /weather |
      | weather 123      | unknown weather type         |
      | time abc         | hour must be                 |
      | time 12 75       | hour must be                 |
      | time 12.5        | hour must be                 |
      | time -3          | hour must be                 |
      | freezeweather 2  | expected true/false          |
      | blackout yes     | expected true/false          |
