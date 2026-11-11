@kora @kora_scoreboard
Feature: kora_scoreboard server status
  The scoreboard shows how many players are online, how many police are on
  duty and whether each police-gated activity has enough police. It is a
  kora_lib AppShell app: kora_lib's hook confirms it opens and closes, and the
  scoreboard's own read-only hook reports the figures it last sent to the app.
  That is the data handed to the UI, not the rendered page.

  The @global scenarios drive the activity busy flag ("On cooldown") through
  the server event robbery resources use. It is broadcast to every player, so
  each one sets the flag back to free when it ends and refuses to start while a
  real robbery has the activity on cooldown.

  Not covered: the player ID overlay drawn above nearby players, which is
  drawn in the world with no readable state and needs a second player; and
  changing Config.Toggle, Config.MaxPlayers or the activity rows in the live
  config editor, which is server-wide configuration.

  Background:
    Given resource "kora_scoreboard" is running

  @ui
  Scenario: Command opens and closes the scoreboard
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    When I run the command "scoreboard"
    Then no app should be open

  @ui
  Scenario: Scoreboard counts the online players
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    And the scoreboard should show at least 1 player online within the server capacity

  # Labels are Config.IllegalActions in kora_scoreboard/shared/config.lua. They
  # can be renamed in the live config editor; this asserts the shipped defaults.
  @ui
  Scenario Outline: Scoreboard lists each police-gated activity
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    And the scoreboard should list the activity "<activity>"

    Examples:
      | activity        |
      | Store Robbery   |
      | Bank Robbery    |
      | Jewelery        |
      | Pacific Bank    |
      | Paleto Bay Bank |

  @ui
  Scenario: Activity status follows the police count
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    And every scoreboard activity status should follow the police count

  @ui
  Scenario: An on-duty police officer is counted
    Given I am on duty as "police" at grade 1
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    And the scoreboard should count at least 1 police on duty
    And every scoreboard activity status should follow the police count

  @ui
  Scenario: Going off duty lowers the police count
    Given I am on duty as "police" at grade 1
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    And I remember the scoreboard police count
    When I close the app
    Then no app should be open
    Given I am off duty as "police" at grade 1
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    And the scoreboard police count should be 1 lower than before

  @ui
  Scenario: Scoreboard app is titled and describes its key
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    And the scoreboard app should be titled "Scoreboard"
    And the scoreboard footer should describe the configured key mode
    And the scoreboard should report itself open

  @ui
  Scenario: Closing the app is seen by the scoreboard
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    When I close the app
    Then no app should be open
    And the scoreboard should report itself closed

  @ui
  Scenario: Running the command twice while it opens leaves it open
    When I run the scoreboard command twice in a row
    Then the app "qb-scoreboard:app" should be open
    And the scoreboard should report itself open

  @ui
  Scenario: Every opening sends fresh figures once
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    And I remember how often the scoreboard figures were sent
    When I run the command "scoreboard"
    Then no app should be open
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    And the scoreboard figures should have been sent 1 more times

  @ui
  Scenario: Scoreboard key follows the configured key mode
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    When I close the app
    Then no app should be open
    And pressing and releasing the scoreboard key should follow the configured key mode

  Scenario: Server data lists me with an opt-in flag
    Then the scoreboard server data should list me with an opt-in flag

  @ui
  Scenario: Scoreboard shows the counts the server reports
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    And the scoreboard should show the player and police counts the server reports

  @ui
  Scenario: Activities are listed once each in name order
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    And the scoreboard should list 5 activities
    And the scoreboard activities should be sorted by name

  # minimumPolice of each Config.IllegalActions row in shared/config.lua
  # (shipped defaults; editable in the live config editor).
  @ui
  Scenario Outline: <activity> requires <police> police
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    And the scoreboard should require <police> police for "<activity>"

    Examples:
      | activity        | police |
      | Store Robbery   | 1      |
      | Bank Robbery    | 3      |
      | Jewelery        | 2      |
      | Pacific Bank    | 5      |
      | Paleto Bay Bank | 4      |

  Scenario: Going on duty as police raises the server police count
    Given I am off duty as "police" at grade 1
    And I remember the scoreboard server police count
    Given I am on duty as "police" at grade 1
    Then the scoreboard server police count should be 1 higher than before
    And the scoreboard server data should count at least 1 police on duty

  # Only job.name == 'police' with onduty counts (server/server.lua).
  Scenario: An on-duty ambulance worker is not counted as police
    Given I am off duty as "police" at grade 1
    And I remember the scoreboard server police count
    Given I am on duty as "ambulance" at grade 1
    Then the scoreboard server police count should be unchanged

  Scenario: Going off duty lowers the server police count
    Given I am on duty as "police" at grade 1
    And I remember the scoreboard server police count
    Given I am off duty as "police" at grade 1
    Then the scoreboard server police count should be 1 lower than before

  @ui @global
  Scenario Outline: A busy activity shows as on cooldown until it is free again
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    And the scoreboard should not show the activity "<label>" on cooldown
    When the activity "<id>" is set busy on the scoreboard
    Then the scoreboard should show the activity "<label>" as "On cooldown"
    When the activity "<id>" is set free on the scoreboard
    Then every scoreboard activity status should follow the police count
    And the scoreboard should not show the activity "<label>" on cooldown

    Examples:
      | id           | label           |
      | storerobbery | Store Robbery   |
      | bankrobbery  | Bank Robbery    |
      | jewellery    | Jewelery        |
      | pacific      | Pacific Bank    |
      | paleto       | Paleto Bay Bank |

  @ui @global
  Scenario: A cooldown overrides enough police
    Given I am on duty as "police" at grade 1
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    And the scoreboard should not show the activity "Store Robbery" on cooldown
    And the scoreboard should count at least 1 police on duty
    When the activity "storerobbery" is set busy on the scoreboard
    Then the scoreboard should show the activity "Store Robbery" as "On cooldown"

  @ui @global
  Scenario: Busy flags reach a closed scoreboard
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    And the scoreboard should not show the activity "Jewelery" on cooldown
    When I close the app
    Then no app should be open
    When the activity "jewellery" is set busy on the scoreboard
    Then the scoreboard should show the activity "Jewelery" as "On cooldown"
    And the scoreboard should report itself closed

  # A refused call sends nothing; the valid "free" call after it is the fence
  # that proves exactly one update arrived.
  @ui @global
  Scenario Outline: An invalid busy flag is ignored
    When I run the command "scoreboard"
    Then the app "qb-scoreboard:app" should be open
    And the scoreboard should not show the activity "Store Robbery" on cooldown
    And I remember how often the scoreboard figures were sent
    When <invalid call>
    And the activity "storerobbery" is set free on the scoreboard
    Then the scoreboard figures should have been sent 1 more times
    And every scoreboard activity status should follow the police count

    Examples:
      | invalid call                                                                   |
      | the unknown activity "fft_unknown" is set busy on the scoreboard               |
      | the unknown activity "Store Robbery" is set busy on the scoreboard             |
      | the activity "storerobbery" is set busy on the scoreboard with the value "true" |
      | the activity "storerobbery" is set busy on the scoreboard with no value        |
