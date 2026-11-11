@kora @kora_skills
Feature: kora_skills progression
  Characters level eight skills; other resources read them through server
  exports and players through the /skills panel (AppShell app
  "kora_skills:progression").

  Skill XP has no delete or decrease API, so nothing here awards XP: gaining
  experience, levelling up and the level-up notification are not covered. The
  only awards sent are ones the server refuses before any write. Location
  refusals use a point the step has measured to be 3000 metres from the
  tester, and the 100000 award ceiling is probed together with an invalid
  location, so a config change can only turn one refusal into another.

  Background:
    Given resource "kora_skills" is running

  @server
  Scenario: Profile lists every configured skill with consistent progress
    Then my skill profile should list every configured skill
    And my replicated skills should match my skill profile

  @server
  Scenario Outline: Single skill lookup returns its definition
    Then my skill "<skill>" should be reported with the label "<label>"

    Examples:
      | skill    | label    |
      | mining   | Mining   |
      | smelting | Smelting |
      | fishing  | Fishing  |

  @server @rejection
  Scenario: Unknown skill lookup is refused
    Then asking for my skill "fft_no_such_skill" should be refused with "unknown skill"

  @server
  Scenario: Level checks compare against the current level
    Then I should be at least level 1 in the skill "mining"
    # Config.maxLevel is 99, so no character reaches level 100.
    And I should not count as level 100 in the skill "mining"
    And I should not count as level 0 in the skill "mining"
    And I should not count as level 1 in the skill "fft_no_such_skill"

  @server @rejection
  Scenario Outline: Invalid skill award is refused without changing experience
    Given I remember my skill experience
    Then a skill award of "<amount>" to "<skill>" should be refused with "<reason>"
    And my skill experience should be unchanged

    Examples:
      | amount | skill             | reason                                                               |
      | 10     | fft_no_such_skill | unknown skill                                                        |
      | 0      | mining            | skill award must be a positive integer within the configured maximum |
      | -25    | mining            | skill award must be a positive integer within the configured maximum |
      | 1.5    | mining            | skill award must be a positive integer within the configured maximum |
      | lots   | mining            | skill award must be a positive integer within the configured maximum |

  @server
  Scenario: Skill level only eases the minigame fields a skill configures
    # Config.skills.mining.skillCheck = skillbar zoneSize, lockpick tolerance;
    # smelting configures none. No minigame is started.
    Then the "mining" skill should ease a "skillbar" check only through "zoneSize"
    And the "mining" skill should ease a "lockpick" check only through "tolerance"
    And the "smelting" skill should leave a "skillbar" check unchanged
    And the "mining" skill should leave a "fft_no_such_game" check unchanged

  @ui
  Scenario Outline: Command opens the progression panel
    When I run the command "<command>"
    Then the app "kora_skills:progression" should be open
    When I close the app
    Then no app should be open

    Examples:
      | command   |
      | skills    |
      | skillList |

  # ---------------------------------------------------------------------------
  # Round 3: read model, curve, lookups by bad sources, award refusals.
  # ---------------------------------------------------------------------------

  @server
  Scenario: Asking for no particular skill returns the whole profile
    Then asking for my skills without naming one should return my whole profile

  @server
  Scenario Outline: Every configured skill is labelled alike by the catalogue and the profile
    Then the skill catalogue should name "<skill>" as "<label>"
    And my skill "<skill>" should be reported with the label "<label>"
    And my "<skill>" progress should follow the experience curve
    And I should count as exactly my current level in the skill "<skill>"

    Examples:
      | skill          | label           |
      | mining         | Mining          |
      | smelting       | Smelting        |
      | fishing        | Fishing         |
      | crafting       | Crafting        |
      | cooking        | Cooking         |
      | metaldetecting | Metal Detecting |
      | computing      | Computing       |
      | hacking        | Hacking         |

  @server
  Scenario: The skill catalogue lists exactly the configured skills
    Then the skill catalogue should list exactly the configured skills

  # server/main.lua:108-113 isLevel: tonumber, whole number, at least 1.
  @server @rejection
  Scenario Outline: Level checks only accept whole levels of at least one
    Then my "mining" level check against "<level>" should be "<result>"

    Examples:
      | level | result  |
      | 1     | true    |
      | 1.5   | false   |
      | 0     | false   |
      | -1    | false   |
      | lots  | false   |
      |       | false   |
      | 100   | false   |

  @server @rejection
  Scenario Outline: Skill lookups for a source without a character are refused
    Then skill lookups for the source "<source>" should be refused with "<reason>"

    Examples:
      | source              | reason                          |
      | 0                   | invalid player source           |
      | -1                  | invalid player source           |
      | 1.5                 | invalid player source           |
      | text                | invalid player source           |
      | an unused player id | player has no active character |

  # addRep checks skill and amount first, then playerSkills refuses inside
  # addRepLocked before any write (server/main.lua:134-136).
  @server @rejection
  Scenario Outline: A skill award for a source without a character is refused
    Given I remember my skill experience
    Then a skill award of 1 to "mining" for the source "<source>" should be refused with "<reason>"
    And my skill experience should be unchanged

    Examples:
      | source              | reason                          |
      | 0                   | invalid player source           |
      | 1.5                 | invalid player source           |
      | an unused player id | player has no active character |

  @server @rejection
  Scenario Outline: More malformed award amounts are refused
    Given I remember my skill experience
    Then a skill award of "<amount>" to "<skill>" should be refused with "<reason>"
    And my skill experience should be unchanged

    Examples:
      | amount | skill    | reason                                                               |
      | -0.5   | mining   | skill award must be a positive integer within the configured maximum |
      | 0.0001 | mining   | skill award must be a positive integer within the configured maximum |
      | 1e400  | hacking  | skill award must be a positive integer within the configured maximum |
      |        | cooking  | skill award must be a positive integer within the configured maximum |
      | 10     |          | unknown skill                                                        |
      | 10     | Mining   | unknown skill                                                        |

  # Location and distance checks, server/main.lua:115-128 and 158-167.
  @server @rejection
  Scenario Outline: An award with a bad location or distance is refused before any write
    Given I remember my skill experience
    Then a skill award of "<amount>" to "mining" at "<location>" within "<distance>" should be refused with "<reason>"
    And my skill experience should be unchanged

    Examples:
      | amount | location                 | distance | reason                                                               |
      | 1      | an empty table           | default  | invalid award location                                               |
      | 1      | a text                   | default  | invalid award location                                               |
      | 1      | text coordinates         | default  | invalid award location                                               |
      | 1      | a point 3000 metres away | 0        | invalid award distance                                               |
      | 1      | a point 3000 metres away | -5       | invalid award distance                                               |
      | 1      | a point 3000 metres away | 1000.5   | invalid award distance                                               |
      | 1      | a point 3000 metres away | 1.0      | player is too far from the award location                            |
      | 1      | a point 3000 metres away | 1000     | player is too far from the award location                            |
      | 1      | a point 3000 metres away | default  | player is too far from the award location                            |
      | 100000 | an empty table           | default  | invalid award location                                               |
      | 100001 | an empty table           | default  | skill award must be a positive integer within the configured maximum |
      | 0      | a point 3000 metres away | 1.0      | skill award must be a positive integer within the configured maximum |

  # README's example passes vector coords; server/main.lua isWithinDistance
  # accepts a vector as well as a plain { x, y, z } table.
  @server @rejection
  Scenario: An award at a vector location is judged by distance
    Given I remember my skill experience
    Then a skill award of "1" to "mining" at "a vector 3000 metres away" within "1.0" should be refused with "player is too far from the award location"
    And my skill experience should be unchanged

  @server
  Scenario Outline: Skill level scales each configured minigame field within its safe bounds
    Then the "<skill>" skill should scale a "<game>" check with "<field>" of <base> by its configured amount

    Examples:
      | skill          | game     | field           | base  |
      | mining         | skillbar | zoneSize        | 0.2   |
      | mining         | lockpick | tolerance       | 0.1   |
      | fishing        | skillbar | zoneSize        | 0.2   |
      | crafting       | circuit  | nodeCount       | 6.0   |
      | cooking        | skillbar | zoneSize        | 0.2   |
      | cooking        | mash     | requiredPresses | 20.0  |
      | metaldetecting | skillbar | zoneSize        | 0.2   |
      | computing      | circuit  | nodeCount       | 6.0   |
      | computing      | hacking  | solutionsize    | 5.0   |
      | hacking        | hacking  | solutionsize    | 5.0   |
      | hacking        | circuit  | nodeCount       | 6.0   |
      | mining         | skillbar | zoneSize        | 0.9   |
      | mining         | lockpick | tolerance       | 0.5   |
      | crafting       | circuit  | nodeCount       | 1.0   |
      | crafting       | circuit  | nodeCount       | 20.0  |
      | cooking        | mash     | requiredPresses | 200.0 |
      | hacking        | hacking  | solutionsize    | 5.5   |

  @server
  Scenario: Text and missing minigame fields are left alone
    Then the "mining" skill should keep a text "zoneSize" and leave a missing one unset in a "skillbar" check
    And the "crafting" skill should keep a text "nodeCount" and leave a missing one unset in a "circuit" check

  @server @rejection
  Scenario: An unknown skill hands minigame options back untouched
    Then the "fft_no_such_skill" skill should hand back a "skillbar" check unchanged with no skill data

  @ui
  Scenario: The skills panel shows every skill in the graph and the table
    When I run the command "skills"
    Then the skills panel should show every configured skill
    When I close the app
    Then no app should be open

  @ui
  Scenario: The open export shows the same panel
    When I open the skills panel through its export
    Then the app "kora_skills:progression" should be open
    And the skills panel should show every configured skill
    When I close the app
    Then no app should be open

  # Legacy metadata.skills is imported once and then removed (README, server/main.lua:27-30).
  @ui
  Scenario: Opening the panel retires a stale legacy skills blob without touching progress
    Given I remember my skill experience
    And my metadata holds a legacy skills blob with no experience
    When I run the command "skills"
    Then the app "kora_skills:progression" should be open
    And my legacy skills metadata should have been removed
    And my skill experience should be unchanged
    When I close the app
    Then no app should be open

  Scenario: Client exports mirror the replicated profile
    Then the client skill exports should mirror my replicated skills
    And the client level check for "mining" against "1" should be "true"
    And the client level check for "mining" against "100" should be "false"
    And the client level check for "fft_no_such_skill" against "1" should be "false"
    And the client level check for "mining" against "nothing" should be "false"
    And the client should scale a "skillbar" check with "zoneSize" of 0.2 for the skill "mining"
    And the client should scale a "circuit" check with "nodeCount" of 6.0 for the skill "computing"

  # The server refuses level 0 (server/main.lua isLevel); the client export
  # (client/main.lua isLevel) applies the same rule.
  @rejection
  Scenario: The client level check refuses level zero like the server
    Then the client level check for "mining" against "0" should be "false"
    And I should not count as level 0 in the skill "mining"
