@kora @kora_truckerjob
Feature: kora_truckerjob freight dispatch
  Freight dispatch at the Elysian Island depot: the contract board, trucker
  skills, truck ownership and the dispatched truck's accept, cancel and return
  lifecycle. The dispatch app is a kora_lib AppShell app driven at the
  NUI-callback level through kora_lib's hook; rendered controls are not
  clicked, so a button the browser disables (or guards with a confirmation)
  still reaches the server, whose refusal is what these scenarios assert.

  Fixtures: the tester's `rep.trucker` metadata is replaced with a new driver's
  record and restored afterwards. A dispatched truck is deleted in cleanup,
  which also makes the resource abandon the contract and release its keys. An
  accepted and cancelled contract is removed from the shared board, as it is
  for any player who cancels.

  Not covered: delivering a load and its payout, XP and skill-point reward (a
  long drive and precise trailer parking that cannot finish inside the step
  limits), late and damage penalties, and the contract cooldown (disabled in
  config). The resource takes no deposit. Trailer dispatch at the port is
  covered up to the trailer spawning; the delivery drive is not.

  Malformed stored records are written directly into `rep.trucker` to drive
  the server's repair branches (normaliseTruckerRep), which run whenever the
  dispatch opens. Callback rate limits are per player, so the suite's own
  dispatch steps pace themselves under each limit.

  Background:
    Given resource "kora_truckerjob" is running

  @world @ui
  Scenario: Depot terminal opens freight dispatch
    Given I stand at 152.4 -3211.8 5.95 facing 270.0
    And I aim at 153.86 -3211.76 5.95
    When I target "Open freight dispatch"
    Then the app "kora_truckerjob:dispatch" should be open
    When I close the app
    Then no app should be open

  @ui
  Scenario: A new driver is offered a contract they qualify for
    Given my trucking record is reset with 0 skill points
    When I open the freight dispatch
    Then the app "kora_truckerjob:dispatch" should be open
    And the freight board should offer a contract my skills qualify for
    And the freight board should show no active contract of mine
    And my trucking skill "distance" should be level 1

  @ui
  Scenario: Spending a skill point raises a trucking skill
    Given my trucking record is reset with 1 skill points
    When I open the freight dispatch
    And I trigger the app action "trucker:upgrade" on "distance"
    Then the freight dispatch should answer with a "success" notice containing "Changes saved."
    And my trucking skill "distance" should be level 2
    And my trucking skill points should be 0

  @ui @rejection
  Scenario: A skill upgrade without skill points is refused
    Given my trucking record is reset with 0 skill points
    When I open the freight dispatch
    And I trigger the app action "trucker:upgrade" on "cargo"
    Then the freight dispatch should answer with a "destructive" notice containing "You do not have enough skill points."
    And my trucking skill "cargo" should be level 1
    And my trucking skill points should be 0

  @world @ui
  Scenario: Buying a truck at the depot charges the bank and unlocks it
    Given my trucking record is reset with 0 skill points
    And I have 30000 in my "bank" account
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    And I remember my "bank" balance
    When I open the freight dispatch
    And I trigger the app action "trucker:purchase" on "phantom"
    Then the freight dispatch should answer with a "success" notice containing "Changes saved."
    And my "bank" balance should have decreased by 25000
    And I should own the freight truck "phantom"
    When I trigger the app action "trucker:select" on "phantom"
    Then the freight dispatch should answer with a "success" notice containing "Changes saved."
    And my active freight truck should be "phantom"

  # kora_core lets the bank go negative (config.lua:29-30 allowNegative.bank,
  # minusLimit -50000; modules/money/server.lua:16-21, 514-518), so a 25000
  # truck bought with 100 in the bank succeeds on overdraft. Only a price past
  # the overdraft limit is refused: phantom3 costs 100000 (config.lua:83) and
  # removeMoney answers 'insufficient funds', which server.lua:493-494 relays.
  @world @ui @rejection
  Scenario: Buying a truck beyond the bank overdraft limit is refused
    Given my trucking record is reset with 0 skill points
    And I have 100 in my "bank" account
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    And I remember my "bank" balance
    When I open the freight dispatch
    And I trigger the app action "trucker:purchase" on "phantom3"
    Then the freight dispatch should answer with a "destructive" notice containing "insufficient funds"
    And my "bank" balance should be unchanged
    And I should not own the freight truck "phantom3"

  @ui @rejection
  Scenario: Buying a truck away from the depot is refused
    Given my trucking record is reset with 0 skill points
    And I have 30000 in my "bank" account
    And I remember my "bank" balance
    When I open the freight dispatch away from the depot
    And I trigger the app action "trucker:purchase" on "phantom"
    Then the freight dispatch should answer with a "destructive" notice containing "You are too far from the depot."
    And my "bank" balance should be unchanged
    And I should not own the freight truck "phantom"

  @ui @rejection
  Scenario: Selecting a truck that is not owned is refused
    Given my trucking record is reset with 0 skill points
    And my trucking record also owns the freight truck "packer"
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    When I open the freight dispatch
    And I trigger the app action "trucker:select" on "phantom"
    Then the freight dispatch should answer with a "destructive" notice containing "You do not own this truck."
    And my active freight truck should be "hauler"

  @ui @rejection
  Scenario: Accepting a contract away from the depot is refused
    Given my trucking record is reset with 0 skill points
    And freight trucks dispatched to me are removed afterwards
    When I open the freight dispatch away from the depot
    And I accept a freight contract my skills qualify for
    Then the freight dispatch should answer with a "destructive" notice containing "You are too far from the depot."
    And no freight truck should have been dispatched to me
    And the freight board should show no active contract of mine

  @world @ui @slow
  Scenario: Accepting a contract dispatches a truck and cancelling keeps it out until returned
    Given my trucking record is reset with 0 skill points
    And freight trucks dispatched to me are removed afterwards
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    When I open the freight dispatch
    And I accept a freight contract my skills qualify for
    Then the freight dispatch should answer with a "success" notice containing "Contract accepted."
    And a freight truck should have been dispatched to me
    When I open the freight dispatch
    And I trigger the app action "trucker:cancel"
    Then the freight dispatch should answer with a "success" notice containing "Contract cancelled."
    And the freight board should show no active contract of mine
    When I close the app
    And I stand at 187.07 -3219.34 5.86 facing 90.0
    Then the text prompt should show "Bring the truck to the return point first."
    And a freight truck should have been dispatched to me

  @world @ui @slow
  Scenario: Returning the truck to the depot after cancelling hands it back
    Given my trucking record is reset with 0 skill points
    And freight trucks dispatched to me are removed afterwards
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    When I open the freight dispatch
    And I accept a freight contract my skills qualify for
    Then a freight truck should have been dispatched to me
    When I open the freight dispatch
    And I trigger the app action "trucker:cancel"
    Then the freight dispatch should answer with a "success" notice containing "Contract cancelled."
    When I close the app
    And I take the wheel of my freight truck
    And I bring my freight truck to the depot return point
    Then the text prompt should show "Exit the vehicle to return the truck"
    When I step out of my freight truck
    Then I should see a notification containing "Truck returned to the depot."
    And my freight truck should have been collected

  # ---------------------------------------------------------------------------
  # Skills (server.lua skillUpgraded)
  # ---------------------------------------------------------------------------

  @ui
  Scenario Outline: Each trucking skill can be raised with a skill point
    Given my trucking record is reset with 1 skill points
    When I open the freight dispatch
    And I use the freight dispatch action "trucker:upgrade" on "<skill>"
    Then the freight dispatch should answer with a "success" notice containing "Changes saved."
    And my trucking skill "<skill>" should be level 2
    And my trucking skill points should be 0

    Examples:
      | skill    |
      | distance |
      | cargo    |
      | time     |

  @ui
  Scenario: Spending three skill points raises all three skills once
    Given my trucking record is reset with 3 skill points
    When I open the freight dispatch
    And I use the freight dispatch action "trucker:upgrade" on "distance"
    And I use the freight dispatch action "trucker:upgrade" on "cargo"
    And I use the freight dispatch action "trucker:upgrade" on "time"
    Then my trucking skill "distance" should be level 2
    And my trucking skill "cargo" should be level 2
    And my trucking skill "time" should be level 2
    And my trucking skill points should be 0

  # server.lua: `if trucker.skills[skill] >= 4` refuses before spending.
  @ui @rejection
  Scenario: A skill stops at level 4 and the remaining point is kept
    Given my trucking record is reset with 2 skill points
    And my trucking skills are distance 3 cargo 1 time 1
    When I open the freight dispatch
    And I use the freight dispatch action "trucker:upgrade" on "distance"
    Then the freight dispatch should answer with a "success" notice containing "Changes saved."
    And my trucking skill "distance" should be level 4
    And my trucking skill points should be 1
    When I use the freight dispatch action "trucker:upgrade" on "distance"
    Then the freight dispatch should answer with a "destructive" notice containing "That skill is already at its maximum level."
    And my trucking skill "distance" should be level 4
    And my trucking skill points should be 1

  @ui @rejection
  Scenario Outline: Upgrading a skill that does not exist is refused
    Given my trucking record is reset with 1 skill points
    When I open the freight dispatch
    And I use the freight dispatch action "trucker:upgrade" on "<skill>"
    Then the freight dispatch should answer with a "destructive" notice containing "Invalid skill."
    And my trucking skill points should be 1
    And my trucking skill "distance" should be level 1

    Examples:
      | skill    |
      | speed    |
      | Distance |
      |          |

  @ui
  Scenario: The freight board reports the server's unspent skill points
    Given my trucking record is reset with 2 skill points
    When I open the freight dispatch
    Then the freight board should report 2 skill points
    When I use the freight dispatch action "trucker:upgrade" on "cargo"
    Then the freight board should report 1 skill points

  # ---------------------------------------------------------------------------
  # Record repair on open (server.lua normaliseTruckerRep)
  # ---------------------------------------------------------------------------

  @ui
  Scenario: A character without a trucking record gets a new driver's record
    Given my trucking record is cleared
    When I open the freight dispatch
    Then the app "kora_truckerjob:dispatch" should be open
    And I should own the freight truck "hauler"
    And my active freight truck should be "hauler"
    And my trucking skill "distance" should be level 1
    And my trucking skill "cargo" should be level 1
    And my trucking skill "time" should be level 1
    And my trucking skill points should be 0
    And my trucking XP should be 0

  @ui
  Scenario Outline: An out-of-range stored skill level is repaired when the dispatch opens
    Given my trucking record is reset with 0 skill points
    And my trucking record stores the number "<stored>" in "skills.<skill>"
    When I open the freight dispatch
    Then my trucking skill "<skill>" should be level <level>

    Examples:
      | skill    | stored | level |
      | distance | 0      | 1     |
      | distance | 5      | 1     |
      | cargo    | 2.5    | 1     |
      | cargo    | -1     | 1     |
      | time     | 4      | 4     |

  @ui
  Scenario: A skill level stored as text is converted to a number
    Given my trucking record is reset with 0 skill points
    And my trucking record stores the text "3" in "skills.time"
    When I open the freight dispatch
    Then my trucking skill "time" should be level 3

  @ui
  Scenario: A malformed skills table is replaced by level 1 skills
    Given my trucking record is reset with 0 skill points
    And my trucking record stores the text "broken" in "skills"
    When I open the freight dispatch
    Then my trucking skill "distance" should be level 1
    And my trucking skill "cargo" should be level 1
    And my trucking skill "time" should be level 1

  @ui
  Scenario Outline: Invalid stored skill points are reset to zero
    Given my trucking record is reset with 0 skill points
    And my trucking record stores the <kind> "<stored>" in "skillPoints"
    When I open the freight dispatch
    Then my trucking skill points should be 0

    Examples:
      | kind   | stored |
      | number | -2     |
      | number | 1.5    |
      | text   | 4      |

  @ui
  Scenario Outline: Stored XP is kept when valid and reset when invalid
    Given my trucking record is reset with 0 skill points
    And my trucking record stores the <kind> "<stored>" in "XP"
    When I open the freight dispatch
    Then my trucking XP should be <xp>

    Examples:
      | kind   | stored | xp   |
      | number | 1234   | 1234 |
      | number | -5     | 0    |
      | text   | lots   | 0    |

  @ui
  Scenario Outline: An active truck that is unknown or not owned falls back to the depot truck
    Given my trucking record is reset with 0 skill points
    And my trucking record stores the <kind> "<stored>" in "activeTruck"
    When I open the freight dispatch
    Then my active freight truck should be "hauler"

    Examples:
      | kind   | stored  |
      | text   | adder   |
      | text   | phantom |
      | number | 7       |

  @ui
  Scenario: A malformed fleet is rebuilt with the depot truck only
    Given my trucking record is reset with 0 skill points
    And my trucking record stores the text "none" in "trucks"
    When I open the freight dispatch
    Then I should own the freight truck "hauler"
    And I should not own the freight truck "phantom"
    And my active freight truck should be "hauler"

  # ---------------------------------------------------------------------------
  # Fleet (server.lua truckPurchased, truckSelected; config.lua Trucks)
  # ---------------------------------------------------------------------------

  @world @ui
  Scenario Outline: Each truck for sale can be bought with exactly its price
    Given my trucking record is reset with 0 skill points
    And I have <price> in my "bank" account
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    And I remember my "bank" balance
    When I open the freight dispatch
    And I use the freight dispatch action "trucker:purchase" on "<truck>"
    Then the freight dispatch should answer with a "success" notice containing "Changes saved."
    And my "bank" balance should have decreased by <price>
    And I should own the freight truck "<truck>"
    And my active freight truck should be "hauler"

    Examples:
      | truck    | price  |
      | phantom  | 25000  |
      | packer   | 50000  |
      | phantom3 | 100000 |

  # kora_core money/server.lua: removeMoney refuses only `newValue < floor`,
  # floor = minusLimit -50000 for bank (kora_core config.lua allowNegative).
  @world @ui
  Scenario: A truck that takes the bank exactly to the overdraft limit can be bought
    Given my trucking record is reset with 0 skill points
    And I have 0 in my "bank" account
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    And I remember my "bank" balance
    When I open the freight dispatch
    And I use the freight dispatch action "trucker:purchase" on "packer"
    Then the freight dispatch should answer with a "success" notice containing "Changes saved."
    And my "bank" balance should have decreased by 50000
    And I should own the freight truck "packer"

  # server.lua truckPurchased: unknown names and price 0 (hauler) are "not for sale".
  @world @ui @rejection
  Scenario Outline: A truck that is not for sale cannot be bought
    Given my trucking record is reset with 0 skill points
    And I have 200000 in my "bank" account
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    And I remember my "bank" balance
    When I open the freight dispatch
    And I use the freight dispatch action "trucker:purchase" on "<truck>"
    Then the freight dispatch should answer with a "destructive" notice containing "That truck is not for sale."
    And my "bank" balance should be unchanged

    Examples:
      | truck  |
      | hauler |
      | adder  |
      |        |

  @world @ui @rejection
  Scenario: Buying a truck that is already owned is refused without a charge
    Given my trucking record is reset with 0 skill points
    And my trucking record also owns the freight truck "phantom"
    And I have 30000 in my "bank" account
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    And I remember my "bank" balance
    When I open the freight dispatch
    And I use the freight dispatch action "trucker:purchase" on "phantom"
    Then the freight dispatch should answer with a "destructive" notice containing "You already own this truck."
    And my "bank" balance should be unchanged
    And I should own the freight truck "phantom"

  @world @ui
  Scenario: Switching to an owned truck and back to the depot truck
    Given my trucking record is reset with 0 skill points
    And my trucking record also owns the freight truck "packer"
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    When I open the freight dispatch
    And I use the freight dispatch action "trucker:select" on "packer"
    Then the freight dispatch should answer with a "success" notice containing "Changes saved."
    And my active freight truck should be "packer"
    When I use the freight dispatch action "trucker:select" on "hauler"
    Then the freight dispatch should answer with a "success" notice containing "Changes saved."
    And my active freight truck should be "hauler"
    And I should own the freight truck "packer"

  @world @ui @rejection
  Scenario: Selecting a truck that does not exist is refused
    Given my trucking record is reset with 0 skill points
    And my trucking record also owns the freight truck "packer"
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    When I open the freight dispatch
    And I use the freight dispatch action "trucker:select" on "adder"
    Then the freight dispatch should answer with a "destructive" notice containing "That truck is unavailable."
    And my active freight truck should be "hauler"

  @ui @rejection
  Scenario: Selecting an owned truck away from the depot is refused
    Given my trucking record is reset with 0 skill points
    And my trucking record also owns the freight truck "packer"
    When I open the freight dispatch away from the depot
    And I use the freight dispatch action "trucker:select" on "packer"
    Then the freight dispatch should answer with a "destructive" notice containing "You are too far from the depot."
    And my active freight truck should be "hauler"

  # ---------------------------------------------------------------------------
  # Contracts (server.lua jobAccepted, vehicleRequested, jobCompleted)
  # ---------------------------------------------------------------------------

  # client/client.lua appDefinition only declares trucker:cancel with an active contract.
  @ui @rejection
  Scenario: Cancelling is not offered without an active contract
    Given my trucking record is reset with 0 skill points
    When I open the freight dispatch
    Then the app action "trucker:cancel" should be unavailable
    And the freight board should show no active contract of mine

  @world @ui @rejection
  Scenario Outline: Accepting a contract that is not on the board is refused
    Given my trucking record is reset with 0 skill points
    And freight trucks dispatched to me are removed afterwards
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    When I open the freight dispatch
    And I use the freight dispatch action "trucker:accept" on "<contract>"
    Then the freight dispatch should answer with a "destructive" notice containing "This job is no longer available."
    And no freight truck should have been dispatched to me
    And the freight board should show no active contract of mine

    Examples:
      | contract |
      | NOJOB0   |
      |          |

  # Rows need a matching contract on the shared, randomly generated board.
  @world @ui @rejection
  Scenario Outline: A contract above the driver's skill level is refused
    Given my trucking record is reset with 0 skill points
    And my trucking skills are distance <distance> cargo <cargo> time 1
    And freight trucks dispatched to me are removed afterwards
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    When I open the freight dispatch
    And I accept a freight contract that needs a higher "<skill>" skill
    Then the freight dispatch should answer with a "destructive" notice containing "<message>"
    And no freight truck should have been dispatched to me
    And the freight board should still list my contract as open

    Examples:
      | distance | cargo | skill    | message                                              |
      | 1        | 1     | distance | Increase your distance skill to take this job.       |
      | 4        | 1     | cargo    | Increase your cargo skill to handle this load.       |
      | 4        | 4     | time     | Increase your time skill to take this expedited job. |

  @world @ui @slow
  Scenario: An accepted contract is reserved and its truck comes with keys
    Given my trucking record is reset with 0 skill points
    And freight trucks dispatched to me are removed afterwards
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    When I open the freight dispatch
    And I accept a freight contract my skills qualify for
    Then the freight dispatch should answer with a "success" notice containing "Contract accepted."
    And exactly one freight truck should have been dispatched to me
    And I should hold keys to my dispatched freight truck
    And the freight board should show my accepted contract as active

  @world @ui @slow @rejection
  Scenario: A second contract cannot be accepted while one is active
    Given my trucking record is reset with 0 skill points
    And freight trucks dispatched to me are removed afterwards
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    When I open the freight dispatch
    And I accept a freight contract my skills qualify for
    Then a freight truck should have been dispatched to me
    When I open the freight dispatch
    And I accept another freight contract my skills qualify for
    Then the freight dispatch should answer with a "destructive" notice containing "You already have an active job."
    And exactly one freight truck should have been dispatched to me
    And the freight board should show my accepted contract as active

  @world @ui @slow
  Scenario: A cancelled contract leaves the board for good
    Given my trucking record is reset with 0 skill points
    And freight trucks dispatched to me are removed afterwards
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    When I open the freight dispatch
    And I accept a freight contract my skills qualify for
    Then a freight truck should have been dispatched to me
    When I open the freight dispatch
    And I use the freight dispatch action "trucker:cancel"
    Then the freight dispatch should answer with a "success" notice containing "Return your truck to the depot."
    And the freight board should no longer list my accepted contract
    And the freight board should show no active contract of mine
    And I should hold keys to my dispatched freight truck

  # client/client.lua watchTruck -> handleTruckLost (config.lua TruckLost).
  @world @ui @slow
  Scenario: Losing the truck closes the contract and takes the keys back
    Given my trucking record is reset with 0 skill points
    And freight trucks dispatched to me are removed afterwards
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    When I open the freight dispatch
    And I accept a freight contract my skills qualify for
    Then a freight truck should have been dispatched to me
    And I should hold keys to my dispatched freight truck
    When my dispatched freight truck disappears
    Then I should see a notification containing "Your truck is gone. The contract has been closed."
    And I should no longer hold keys to my dispatched freight truck
    And the freight board should no longer list my accepted contract
    And the freight board should show no active contract of mine

  # client/client.lua Kora.cache.onChange('vehicle'), config.lua Return.outsideMessage.
  @world @ui @slow
  Scenario: Leaving the truck outside the return point after cancelling explains where to take it
    Given my trucking record is reset with 0 skill points
    And freight trucks dispatched to me are removed afterwards
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    When I open the freight dispatch
    And I accept a freight contract my skills qualify for
    Then a freight truck should have been dispatched to me
    When I open the freight dispatch
    And I use the freight dispatch action "trucker:cancel"
    Then the freight dispatch should answer with a "success" notice containing "Contract cancelled."
    When I close the app
    And I take the wheel of my freight truck
    And I step out of my freight truck
    Then I should see a notification containing "Return the truck to the depot return point."
    And a freight truck should have been dispatched to me

  # server.lua vehicleRequested spawns trucker.activeTruck.
  @world @ui @slow
  Scenario Outline: The depot dispatches the driver's selected truck
    Given my trucking record is reset with 0 skill points
    And my trucking record drives the freight truck "<truck>"
    And freight trucks dispatched to me are removed afterwards
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    When I open the freight dispatch
    And I accept a freight contract my skills qualify for
    Then the dispatched freight truck should be a "<truck>"

    Examples:
      | truck    |
      | hauler   |
      | phantom  |
      | packer   |
      | phantom3 |

  # config.lua Coords.TrailerLocator 858.59 -3202.2 6.08 and TrailerPickup.prompt;
  # the truck parking spot near the office is unverified.
  @world @ui @slow
  Scenario: The assigned trailer is dispatched at the port and released on cancel
    Given my trucking record is reset with 0 skill points
    And freight trucks dispatched to me are removed afterwards
    And freight trailers dispatched to me are removed afterwards
    And I stand at 152.4 -3211.8 5.95 facing 270.0
    And I wait 1000 milliseconds
    When I open the freight dispatch
    And I accept a freight contract my skills qualify for
    Then a freight truck should have been dispatched to me
    When I take the wheel of my freight truck
    And I move my freight truck to 850.0 -3215.0 6.1 facing 90.0
    And I step out of my freight truck
    And I stand at 856.6 -3202.2 6.08 facing 270.0
    Then the text prompt should show "Press E to dispatch your assigned trailer"
    # The eye zone is a sphere around the locator; its only surface is the quay below it.
    When I aim at 858.59 -3202.2 5.1
    And I target "Dispatch assigned trailer"
    Then I should see a notification containing "Your trailer is in Bay K"
    And a freight trailer should have been dispatched to me
    When I open the freight dispatch away from the depot
    And I use the freight dispatch action "trucker:cancel"
    Then the freight dispatch should answer with a "success" notice containing "Contract cancelled."
    And my freight trailer should have been released
    And the freight board should show no active contract of mine
