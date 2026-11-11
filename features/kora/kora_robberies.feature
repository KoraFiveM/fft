@kora @kora_robberies
Feature: kora_robberies house and store robberies
  Houses are broken into at their door with a lockpick; stores have registers
  and safes gated by the police count. Houses and stores are database rows
  (seeded in server/schema.lua, editable in /robberyCreator), so each scenario
  first checks the live row against the coordinates it uses. World positions are
  unverified until run live. Every scenario reads server state through the
  resource's FFT hook, which is built on the approved seam.

  Searching props, robbing a register (skill-check minigame), opening or blowing
  a safe and the creator are not covered.

  Background:
    Given resource "kora_robberies" is running

  @server @seam
  Scenario: Seeded house and store are loaded
    Then the robbery house "lester_shell_1" is free at -480.73 6266.6 13.58
    And the robbery house "lester_shell_1" should need "lockpick" and 0 police to break in
    And the robbery store "24_7" should have register 1 at -47.2 -1757.61 29.6
    And the robbery store "24_7" should have safe 1 at -43.69 -1748.2 28.86

  @world @seam
  Scenario: Free house offers a break-in at its door
    Given the robbery house "lester_shell_1" is free at -480.73 6266.6 13.58
    And I stand at -480.73 6266.6 13.58 facing 0.0
    When I look around for the robbery option "Break in"
    Then the target option "Break in" should be visible

  @world @seam @rejection
  Scenario: Break-in without a lockpick is refused after the attempt
    Given the robbery house "lester_shell_1" is free at -480.73 6266.6 13.58
    And the robbery house "lester_shell_1" should need "lockpick" and 0 police to break in
    And I carry no "lockpick" for the robbery
    And I stand at -480.73 6266.6 13.58 facing 0.0
    When I look around for the robbery option "Break in"
    And I target "Break in"
    Then a progress bar labelled "Breaking in..." should start
    And the progress bar should finish
    And I should see a notification containing "You need: Lockpick"
    And the robbery house "lester_shell_1" should stay "available"
    And I should not be inside the robbery house "lester_shell_1"

  # The open state is broadcast to every client: other players see "Enter" at
  # this door until the reset at the end of the scenario.
  @world @seam @global @slow
  Scenario: Break-in with a lockpick opens the house and uses the lockpick
    Given the robbery house "lester_shell_1" is free at -480.73 6266.6 13.58
    And the robbery house "lester_shell_1" should need "lockpick" and 0 police to break in
    And I claim the robbery house "lester_shell_1" for this test
    And I hold 1 "lockpick"
    And I remember how many "lockpick" I have
    And I stand at -480.73 6266.6 13.58 facing 0.0
    When I look around for the robbery option "Break in"
    And I target "Break in"
    Then a progress bar labelled "Breaking in..." should start
    And the progress bar should finish
    And the robbery house "lester_shell_1" should be "open"
    And I should be inside the robbery house "lester_shell_1"
    And I should have 1 fewer "lockpick" than before
    And I should have been moved away from -480.73 6266.6 13.58
    When the robbery house "lester_shell_1" test state is reset
    Then I should see a notification containing "The robbery is over. You have been sent out."
    And I should be back near -480.73 6266.6 13.58
    And the robbery house "lester_shell_1" should be "available"

  # The cooldown state is broadcast to every client for the length of the scenario.
  @world @seam @global @rejection
  Scenario: Recently robbed house refuses a break-in
    Given the robbery house "lester_shell_1" is free at -480.73 6266.6 13.58
    And the robbery house "lester_shell_1" is on a test cooldown
    And I stand at -480.73 6266.6 13.58 facing 0.0
    When I look around for the robbery option "Recently robbed"
    And I target "Recently robbed"
    Then I should see a notification containing "Someone broke in here recently. Try again in"
    And no progress bar should be running
    And the robbery house "lester_shell_1" should stay "cooldown"
    When the robbery house "lester_shell_1" test state is reset
    Then the robbery house "lester_shell_1" should be "available"

  @world @seam @rejection
  Scenario: Store register is refused without enough police
    Given the robbery store "24_7" should have register 1 at -47.2 -1757.61 29.6
    And the robbery store "24_7" needs more police than are on duty
    And I remember my "cash" balance
    # Register 1 is a 1 m box on the counter: stand beside it, not on it.
    When I face the robbery store register at -47.2 -1757.61 29.6
    And I target "Rob Register"
    Then I should see a notification containing "Not enough police in the city."
    And no progress bar should be running
    And my "cash" balance should be unchanged

  @world @seam @ui @rejection
  Scenario: Store safe code is refused without enough police
    Given the robbery store "24_7" should have safe 1 at -43.69 -1748.2 28.86
    And the robbery store "24_7" needs more police than are on duty
    And I remember my "cash" balance
    # Safe 1 is a 1 m box at floor height: stand beside it, not on it.
    When I face the robbery store safe at -43.69 -1748.2 28.86
    And I target "Enter Code"
    Then an input dialog should open
    When I submit the input dialog with:
      """
      { "code": 1234 }
      """
    Then I should see a notification containing "Not enough police in the city."
    And my "cash" balance should be unchanged

  # Seed rows in server/schema.lua (kora_robberies_houses). breakItem falls back
  # to the shell's, then to Config defaults ('lockpick').
  @server @seam
  Scenario Outline: Seeded house <house> is loaded with its break-in rules
    Then the robbery house "<house>" is free at <x> <y> <z>
    And the robbery house "<house>" should need "<item>" and <police> police to break in

    Examples:
      | house           | x        | y        | z      | item             | police |
      | lester_shell_23 | 282.0    | -1694.8  | 28.65  | lockpick         | 1      |
      | michael_shell_4 | -819.11  | 696.33   | 147.95 | hacking_laptop   | 0      |
      | modern_motel_1  | -1304.29 | 318.58   | 65.63  | lockpick         | 0      |
      | trevor_shell_1  | -1182.52 | -1064.23 | 2.27   | lockpick         | 0      |
      | trevor_shell_10 | -1118.44 | -1619.0  | 4.4    | advancedlockpick | 2      |

  # Seed rows in server/schema.lua (kora_robberies_stores).
  @server @seam
  Scenario Outline: Seeded store <store> is loaded with its register and safe
    Then the robbery store "<store>" should have register 1 at <rx> <ry> <rz>
    And the robbery store "<store>" should have safe 1 at <sx> <sy> <sz>
    And the robbery store "<store>" should need 2 police

    Examples:
      | store   | rx       | ry       | rz     | sx       | sy       | sz     |
      | 24_7    | -47.2    | -1757.61 | 29.6   | -43.69   | -1748.2  | 28.86  |
      | 24_7_2  | -1486.26 | -378.0   | 40.16  | -1478.94 | -375.5   | 39.16  |
      | 24_7_5  | 24.47    | -1344.99 | 29.49  | 28.21    | -1339.14 | 29.49  |
      | 24_7_8  | 373.14   | 328.62   | 103.56 | 378.17   | 333.44   | 103.56 |
      | 24_7_10 | -2966.46 | 390.89   | 15.04  | -2959.64 | 387.08   | 14.04  |
      | 24_7_18 | -161.07  | 6321.23  | 31.5   | -168.4   | 6318.8   | 30.58  |

  @world @seam
  Scenario: Clients are told the house doors and stores as the server holds them
    Given the robbery house "lester_shell_1" is free at -480.73 6266.6 13.58
    Then the robbery house listing should show "lester_shell_1" available at -480.73 6266.6 13.58
    And the robbery store listing should show "24_7" with 2 registers and 1 safe with nothing in use

  @world @seam
  Scenario: Robbery creator data lists the seeded house and store
    Given I have the robbery creator permission
    Then the robbery creator data should list the house "lester_shell_1" and the store "24_7"

  # server/robbery.lua kora_robberies:breakin; validId() limits ids to 48 word characters.
  @world @seam @rejection
  Scenario Outline: Break-in of an unknown house "<id>" is refused
    Given I wait 2100 milliseconds
    And I stand at -480.73 6266.6 13.58 facing 0.0
    When I try to break into the robbery house "<id>" directly
    Then robbery answer 1 should be refused with "Unknown house."

    Examples:
      | id                                                |
      | fft_unknown_house                                 |
      | not a house!                                      |
      | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |

  @world @seam @rejection
  Scenario: Break-in attempts are rate limited
    Given I wait 2100 milliseconds
    And I stand at -480.73 6266.6 13.58 facing 0.0
    When I try to break into the robbery house "fft_unknown_house" directly
    And I try to break into the robbery house "fft_unknown_house" directly
    Then robbery answer 1 should be refused with "Unknown house."
    And robbery answer 2 should be refused with "Slow down."

  @world @seam @rejection
  Scenario: Break-in from across the map is refused
    Given the robbery house "lester_shell_1" is free at -480.73 6266.6 13.58
    And I wait 2100 milliseconds
    And I stand at -47.2 -1757.61 29.6 facing 0.0
    When I try to break into the robbery house "lester_shell_1" directly
    Then robbery answer 1 should be refused with "You are too far away."
    And the robbery house "lester_shell_1" should stay "available"
    And I should not be inside the robbery house "lester_shell_1"

  @world @seam @rejection
  Scenario: Break-in without the break-in item names the missing item
    Given the robbery house "lester_shell_1" is free at -480.73 6266.6 13.58
    And I claim the robbery house "lester_shell_1" for this test
    And I carry no "lockpick" for the robbery
    And I wait 2100 milliseconds
    And I stand at -480.73 6266.6 13.58 facing 0.0
    When I try to break into the robbery house "lester_shell_1" directly
    Then robbery answer 1 should be refused with "You need: Lockpick."
    And the robbery house "lester_shell_1" should stay "available"

  @world @seam @rejection
  Scenario: Break-in is refused while the house needs more police
    Given the robbery house "lester_shell_23" is free at 282.0 -1694.8 28.65
    And the robbery house "lester_shell_23" should need "lockpick" and 1 police to break in
    And the robbery house "lester_shell_23" needs more police than are on duty
    And I claim the robbery house "lester_shell_23" for this test
    And I hold 1 "lockpick"
    And I remember how many "lockpick" I have
    And I wait 2100 milliseconds
    And I stand at 282.0 -1694.8 28.65 facing 0.0
    When I try to break into the robbery house "lester_shell_23" directly
    Then robbery answer 1 should be refused with "Not enough police in the city."
    And I should have 0 fewer "lockpick" than before
    And the robbery house "lester_shell_23" should stay "available"

  # The cooldown is broadcast to every client for the length of the scenario.
  @world @seam @global @rejection
  Scenario: Break-in during the cooldown reports the minutes left
    Given the robbery house "lester_shell_1" is free at -480.73 6266.6 13.58
    And the robbery house "lester_shell_1" is on a test cooldown
    And I wait 2100 milliseconds
    And I stand at -480.73 6266.6 13.58 facing 0.0
    When I try to break into the robbery house "lester_shell_1" directly
    Then robbery answer 1 should be refused with "Someone broke in here recently. Try again in 2 minutes."
    And the robbery house "lester_shell_1" should stay "cooldown"
    When the robbery house "lester_shell_1" test state is reset
    Then the robbery house "lester_shell_1" should be "available"

  # The open state is broadcast to every client until the reset.
  @world @seam @global
  Scenario: An opened house offers Enter, and a player already inside is turned away
    Given the robbery house "lester_shell_1" is free at -480.73 6266.6 13.58
    And I claim the robbery house "lester_shell_1" for this test
    And I hold 1 "lockpick"
    And I remember how many "lockpick" I have
    And I wait 2100 milliseconds
    And I stand at -480.73 6266.6 13.58 facing 0.0
    When I try to break into the robbery house "lester_shell_1" directly
    Then robbery answer 1 should describe the inside of a "lester_shell"
    And the robbery house "lester_shell_1" should be "open"
    And I should be inside the robbery house "lester_shell_1"
    And I should have 1 fewer "lockpick" than before
    When I wait 2100 milliseconds
    And I look around for the robbery option "Enter"
    And I target "Enter"
    Then I should see a notification containing "You are already inside."
    And I should have 1 fewer "lockpick" than before
    When the robbery house "lester_shell_1" test state is reset
    Then the robbery house "lester_shell_1" should be "available"

  @world @seam @global
  Scenario: Leaving an open house and coming back does not use another lockpick
    Given the robbery house "lester_shell_1" is free at -480.73 6266.6 13.58
    And I claim the robbery house "lester_shell_1" for this test
    And I hold 2 "lockpick"
    And I remember how many "lockpick" I have
    And I wait 2100 milliseconds
    And I stand at -480.73 6266.6 13.58 facing 0.0
    When I try to break into the robbery house "lester_shell_1" directly
    Then robbery answer 1 should be accepted
    And I should have 1 fewer "lockpick" than before
    When I leave the robbery house "lester_shell_1" directly
    Then robbery answer 2 should be accepted
    And I should not be inside the robbery house "lester_shell_1"
    And the robbery house "lester_shell_1" should stay "open"
    When I wait 2100 milliseconds
    And I try to break into the robbery house "lester_shell_1" directly
    Then robbery answer 3 should describe the inside of a "lester_shell"
    And I should be inside the robbery house "lester_shell_1"
    And I should have 1 fewer "lockpick" than before
    When the robbery house "lester_shell_1" test state is reset
    Then the robbery house "lester_shell_1" should be "available"

  @world @seam @rejection
  Scenario: Leaving with an invalid house id is refused
    Given I stand at -480.73 6266.6 13.58 facing 0.0
    When I leave the robbery house "not a house!" directly
    Then robbery answer 1 should be refused without a reason

  @world @seam @rejection
  Scenario: Searching is refused outside the house
    Given the robbery house "lester_shell_1" is free at -480.73 6266.6 13.58
    And I wait 1100 milliseconds
    And I stand at -480.73 6266.6 13.58 facing 0.0
    When I try to start searching spot 1 of the robbery house "lester_shell_1"
    And I try to finish searching spot 1 of the robbery house "lester_shell_1"
    Then robbery answer 1 should be refused with "You are not inside."
    And robbery answer 2 should be refused with "You are not inside."

  # lester_shell props (server/schema.lua kora_robberies_shells): spot 1 has the
  # easy_cabinet list and a 5000 ms search; spot 4 has no list.
  # Entered through the real door option and progress bar, so the tester stands
  # in the spawned shell while the search callbacks are asked.
  @world @seam @global @slow @rejection
  Scenario: Inside a house, empty spots, early finishes and parallel searches are refused
    Given the robbery house "lester_shell_1" is free at -480.73 6266.6 13.58
    And I claim the robbery house "lester_shell_1" for this test
    And I hold 1 "lockpick"
    And I wait 2100 milliseconds
    And I stand at -480.73 6266.6 13.58 facing 0.0
    When I look around for the robbery option "Break in"
    And I target "Break in"
    Then a progress bar labelled "Breaking in..." should start
    And the progress bar should finish
    And I should be inside the robbery house "lester_shell_1"
    And I should have been moved away from -480.73 6266.6 13.58
    When I try to start searching spot 4 of the robbery house "lester_shell_1"
    And I wait 600 milliseconds
    And I try to start searching spot 99 of the robbery house "lester_shell_1"
    And I try to finish searching spot 2 of the robbery house "lester_shell_1"
    Then robbery answer 1 should be refused with "There is nothing here."
    And robbery answer 2 should be refused with "There is nothing here."
    And robbery answer 3 should be refused with "You are not searching that."
    When I wait 600 milliseconds
    And I try to start searching spot 1 of the robbery house "lester_shell_1"
    And I try to finish searching spot 1 of the robbery house "lester_shell_1"
    Then robbery answer 4 should start a search lasting 5000 milliseconds
    And robbery answer 5 should be refused with "Too fast."
    When I wait 600 milliseconds
    And I try to start searching spot 1 of the robbery house "lester_shell_1"
    And I wait 600 milliseconds
    And I try to start searching spot 2 of the robbery house "lester_shell_1"
    Then robbery answer 6 should start a search lasting 5000 milliseconds
    And robbery answer 7 should be refused with "Finish what you are doing first."
    When I stop searching spot 1 of the robbery house "lester_shell_1"
    And I wait 600 milliseconds
    And I try to start searching spot 2 of the robbery house "lester_shell_1"
    Then robbery answer 8 should start a search lasting 5000 milliseconds
    When the robbery house "lester_shell_1" test state is reset
    Then the robbery house "lester_shell_1" should be "available"

  # server/robbery.lua searchable(): 120 m from the shell spawn point. The store
  # (-47.2 -1757.61) is about 8 km from the Paleto door, so this holds whatever lowerZ is.
  @world @seam @global @rejection
  Scenario: Searching from across the map is refused while in the house session
    Given the robbery house "lester_shell_1" is free at -480.73 6266.6 13.58
    And I claim the robbery house "lester_shell_1" for this test
    And I hold 1 "lockpick"
    And I wait 2100 milliseconds
    And I stand at -480.73 6266.6 13.58 facing 0.0
    When I try to break into the robbery house "lester_shell_1" directly
    Then robbery answer 1 should be accepted
    And I should be inside the robbery house "lester_shell_1"
    When I stand at -47.2 -1757.61 29.6 facing 0.0
    And I try to start searching spot 1 of the robbery house "lester_shell_1"
    Then robbery answer 2 should be refused with "You are too far away."
    When the robbery house "lester_shell_1" test state is reset
    Then the robbery house "lester_shell_1" should be "available"

  # server/store.lua spotFor: unknown store or index answers 'Unknown spot.'.
  @world @seam @rejection
  Scenario Outline: Register <index> of store "<store>" is an unknown spot
    Given I wait 600 milliseconds
    And I stand at -47.2 -1757.61 29.6 facing 0.0
    When I try to start robbing register <index> of the robbery store "<store>"
    Then robbery answer 1 should be refused with "Unknown spot."

    Examples:
      | store             | index |
      | fft_unknown_store | 1     |
      | 24_7              | 99    |
      | 24_7              | 0     |
      | not a store!      | 1     |

  @world @seam @rejection
  Scenario: Register and safe callbacks are refused away from the store
    Given the robbery store "24_7" should have register 1 at -47.2 -1757.61 29.6
    And I remember my "cash" balance
    And I wait 1100 milliseconds
    And I stand at -480.73 6266.6 13.58 facing 0.0
    When I try to start robbing register 1 of the robbery store "24_7"
    And I try to finish robbing register 1 of the robbery store "24_7"
    And I try the code 1234 on safe 1 of the robbery store "24_7"
    And I wait 1100 milliseconds
    And I try to loot safe 1 of the robbery store "24_7"
    Then robbery answer 1 should be refused with "You are too far away."
    And robbery answer 2 should be refused with "You are too far away."
    And robbery answer 3 should be refused with "You are too far away."
    And robbery answer 4 should be refused with "You are too far away."
    And my "cash" balance should be unchanged

  @world @seam @rejection
  Scenario: Register attempts are rate limited
    Given the robbery store "24_7" should have register 1 at -47.2 -1757.61 29.6
    And the robbery store "24_7" needs more police than are on duty
    And I wait 600 milliseconds
    And I stand at -47.2 -1757.61 29.6 facing 0.0
    When I try to start robbing register 1 of the robbery store "24_7"
    And I try to start robbing register 1 of the robbery store "24_7"
    Then robbery answer 1 should be refused with "Not enough police in the city."
    And robbery answer 2 should be refused with "Slow down."

  # server/store.lua: the police gate comes before the thermite and loot checks.
  @world @seam @rejection
  Scenario: Safe blowing and looting are refused without enough police
    Given the robbery store "24_7" should have safe 1 at -43.69 -1748.2 28.86
    And the robbery store "24_7" needs more police than are on duty
    And I hold 1 "thermite"
    And I remember how many "thermite" I have
    And I remember my "cash" balance
    And I wait 1100 milliseconds
    And I stand at -43.69 -1748.2 29.6 facing 0.0
    When I try to blow safe 1 of the robbery store "24_7"
    And I wait 1100 milliseconds
    And I try to loot safe 1 of the robbery store "24_7"
    Then robbery answer 1 should be refused with "Not enough police in the city."
    And robbery answer 2 should be refused with "Not enough police in the city."
    And I should have 0 fewer "thermite" than before
    And my "cash" balance should be unchanged
