@kora @kora_pawnshop
Feature: kora_pawnshop counter
  Players sell valuables for cash and melt jewellery into bars at the pawn
  counter, through the "qb-pawnshop:app" AppShell app. App actions are driven
  at the NUI-callback level through kora_lib's hook, not by clicking rendered
  controls.

  HAZARD: the server permanently bans a player whose sell, melt or pickup
  event arrives from outside 3 m of the counter, names an item that is not on
  the config list, or (for a sale) carries an amount that is not a positive
  integer. Those rejections are therefore NOT tested. Every scenario that
  sends one of those events uses this suite's guarded steps only: they send
  nothing unless the item is on the allow-list, the amount is a small positive
  integer, the app is open and the frozen ped is within 2 m of the counter,
  and the server's own view of the ped position is asserted just before. Do
  not add the generic "I trigger the app action" steps to this feature.

  Opening hours follow the client's in-game clock, so scenarios pin the clock
  on the tester's client only (kora_weathersync is suspended locally and
  resumed in cleanup; no other player is affected).

  Also not covered: the remaining melting recipes, a full inventory at pickup,
  and melts lost at logout (pending melts are session-only).

  # Counter is Config.PawnLocation[1] = 412.34, 314.81, 103.13, reach 3.0.
  Background:
    Given resource "kora_pawnshop" is running

  @ui @world
  Scenario: Counter opens the pawnshop app during opening hours
    Given the pawnshop clock reads 12 hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the app "qb-pawnshop:app" should be open
    # Nothing sellable is held, so the app declares neither item action.
    And the app action "qb-pawnshop:sell" should be unavailable
    And the app action "qb-pawnshop:melt" should be unavailable
    When I close the app
    Then no app should be open

  @ui @world @rejection
  Scenario: Counter is closed outside opening hours
    # Config.TimeOpen = 7, Config.TimeClosed = 17.
    Given the pawnshop clock reads 20 hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then I should see a notification containing "Pawnshop is closed"
    And no app should be open

  @ui @world
  Scenario: Selling valuables pays cash within the price range
    Given I hold 2 "goldchain"
    And I remember my "cash" balance
    And the pawnshop clock reads 12 hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the app "qb-pawnshop:app" should be open
    And the server should place me within safe reach of the pawnshop counter
    When I pawn 2 "goldchain" at the pawnshop counter
    Then I should see a notification containing "You sold 2x"
    And I should have no "goldchain"
    And the pawnshop payout for 2 items should be within the configured price range
    And a money change should have been recorded for "cash"

  @ui @world @rejection
  Scenario: Selling more than is held pays nothing
    Given I hold 1 "rolex"
    And I remember my "cash" balance
    And the pawnshop clock reads 12 hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the app "qb-pawnshop:app" should be open
    And the server should place me within safe reach of the pawnshop counter
    When I pawn 3 "rolex" at the pawnshop counter
    Then I should see a notification containing "don't have enough of that item"
    And my "cash" balance should be unchanged
    And I should have at least 1 "rolex"

  @ui @world @rejection
  Scenario: App refuses a zero amount without asking the server
    Given I hold 1 "tablet"
    And I remember my "cash" balance
    And the pawnshop clock reads 12 hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the app "qb-pawnshop:app" should be open
    When I ask the pawnshop to buy 0 "tablet"
    Then the app should answer with a "destructive" notice containing "negative amount"
    And my "cash" balance should be unchanged
    And I should have at least 1 "tablet"

  @ui @world @slow
  Scenario: Melting a gold chain yields gold bars
    # Config.MeltingItems: goldchain melts in 0.15 minutes (9 s) into 2 goldbar.
    Given I hold 1 "goldchain"
    And I remember how many "goldbar" I have
    And the pawnshop clock reads 12 hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the app "qb-pawnshop:app" should be open
    And the server should place me within safe reach of the pawnshop counter
    When I melt 1 "goldchain" at the pawnshop counter
    Then I should see a notification containing "Your items are melting"
    And I should have no "goldchain"
    When I wait 9000 milliseconds
    Then I should see a notification containing "finished melting"
    And the server should place me within safe reach of the pawnshop counter
    When I collect my melted items at the pawnshop counter
    Then I should see a notification containing "You received 2x"
    And I should have 2 more "goldbar" than before

  # ---------------------------------------------------------------------------
  # Round 3. Only the guarded steps reach the server; see the HAZARD above.
  # ---------------------------------------------------------------------------

  # isOpen() in client/client.lua: open while TimeOpen (7) <= hour < TimeClosed (17).
  @ui @world
  Scenario Outline: Counter is open at <hour> hundred hours
    Given the pawnshop clock reads <hour> hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the app "qb-pawnshop:app" should be open
    When I close the app
    Then no app should be open

    Examples:
      | hour |
      | 7    |
      | 16   |

  @ui @world @rejection
  Scenario Outline: Counter is closed at <hour> hundred hours
    Given the pawnshop clock reads <hour> hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the pawnshop should say it is closed until 7 hundred hours
    And I should see a notification containing "Come back between 07:00 and 17:00."
    And no app should be open

    Examples:
      | hour |
      | 0    |
      | 6    |
      | 17   |
      | 23   |

  # Config.PawnItems in shared/config.lua; Config.BankMoney = false pays cash.
  @ui @world
  Scenario Outline: Pawning one "<item>" pays cash and takes the item
    Given I hold 1 "<item>"
    And I remember my "cash" balance
    And I remember my "bank" balance
    And the pawnshop clock reads 12 hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the app "qb-pawnshop:app" should be open
    And the server should place me within safe reach of the pawnshop counter
    When I pawn 1 "<item>" at the pawnshop counter
    Then I should see a notification containing "You sold 1x"
    And I should have no "<item>"
    And the pawnshop payout for 1 items should be within the configured price range
    And my "bank" balance should be unchanged

    Examples:
      | item          |
      | goldchain     |
      | diamond_ring  |
      | rolex         |
      | tenkgoldchain |
      | tablet        |
      | iphone        |
      | samsungphone  |
      | laptop        |

  @ui @world
  Scenario: Pawning part of a stack keeps the rest
    Given I hold 3 "laptop"
    And I remember my "cash" balance
    And the pawnshop clock reads 12 hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the app "qb-pawnshop:app" should be open
    And the server should place me within safe reach of the pawnshop counter
    When I pawn 1 "laptop" at the pawnshop counter
    Then I should see a notification containing "You sold 1x"
    And I should have 2 "laptop"
    And the pawnshop payout for 1 items should be within the configured price range

  # The price is rolled once at resource start, so a later sale pays the
  # same per item.
  @ui @world
  Scenario: Consecutive sales pay the same price per item
    Given I hold 3 "iphone"
    And I remember my "cash" balance
    And the pawnshop clock reads 12 hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the app "qb-pawnshop:app" should be open
    And the server should place me within safe reach of the pawnshop counter
    When I pawn 2 "iphone" at the pawnshop counter
    And the server should place me within safe reach of the pawnshop counter
    And I pawn 1 "iphone" at the pawnshop counter
    Then I should have no "iphone"
    And the pawnshop sales of 2 and then 1 items should pay one price per item

  # A listed item the player does not hold: RemoveItem fails, no ban (the
  # item and amount are valid), error.no_items is sent.
  @ui @world @rejection
  Scenario: Pawning a listed item that is not held pays nothing
    Given I hold 1 "rolex"
    And I remember my "cash" balance
    And the pawnshop clock reads 12 hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the app "qb-pawnshop:app" should be open
    And the server should place me within safe reach of the pawnshop counter
    When I pawn 1 "samsungphone" at the pawnshop counter
    Then I should see a notification containing "don't have enough of that item"
    And my "cash" balance should be unchanged
    And I should have 1 "rolex"

  # Melt actions are declared only for held Config.MeltingItems; a tablet is
  # sellable but not meltable.
  @ui @world
  Scenario: A sellable item that cannot be melted offers no melt action
    Given I hold 1 "tablet"
    And the pawnshop clock reads 12 hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the app "qb-pawnshop:app" should be open
    And the app action "qb-pawnshop:melt" should be unavailable
    When I ask the pawnshop to buy 0 "tablet"
    Then the app should answer with a "destructive" notice containing "negative amount"
    And I should have 1 "tablet"

  @ui @world @rejection
  Scenario Outline: App refuses a malformed sale without asking the server: <case>
    Given I hold 1 "goldchain"
    And I remember my "cash" balance
    And the pawnshop clock reads 12 hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the app "qb-pawnshop:app" should be open
    When <request>
    Then the app should answer with a "destructive" notice containing "Trying to sell a negative amount?"
    And my "cash" balance should be unchanged
    And I should have 1 "goldchain"

    Examples:
      | case               | request                                                         |
      | negative amount    | I ask the pawnshop to buy -5 "goldchain"                        |
      | no item chosen     | I ask the pawnshop to buy without choosing an item              |
      | item id unprefixed | I ask the pawnshop to buy "goldchain" without the item prefix   |
      | no amount          | I ask the pawnshop to buy "goldchain" without an amount         |
      | melt of zero       | I ask the pawnshop to melt 0 "goldchain"                        |
      | melt negative      | I ask the pawnshop to melt -1 "goldchain"                       |

  @ui @world @rejection
  Scenario: Melting more than is held keeps the items
    Given I hold 1 "diamond_ring"
    And the pawnshop clock reads 12 hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the app "qb-pawnshop:app" should be open
    And the server should place me within safe reach of the pawnshop counter
    When I melt 2 "diamond_ring" at the pawnshop counter
    Then I should see a notification containing "don't have enough of that item"
    And I should not see a notification containing "Your items are melting"
    And I should have 1 "diamond_ring"

  # meltItemRemove returns early while the last batch is still melting.
  @ui @world @slow
  Scenario: A second melt is not accepted while one is in progress
    Given I hold 2 "goldchain"
    And I remember how many "goldbar" I have
    And the pawnshop clock reads 12 hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the app "qb-pawnshop:app" should be open
    And the server should place me within safe reach of the pawnshop counter
    When I melt 1 "goldchain" at the pawnshop counter
    Then I should see a notification containing "Your items are melting"
    And I should have 1 "goldchain"
    And the server should place me within safe reach of the pawnshop counter
    When I try to melt 1 "goldchain" again at the pawnshop counter
    Then I should have 1 "goldchain"
    When I wait 9000 milliseconds
    Then I should see a notification containing "finished melting"
    And the server should place me within safe reach of the pawnshop counter
    When I collect my melted items at the pawnshop counter
    Then I should have 2 more "goldbar" than before
    And I should have 1 "goldchain"

  # meltTime is minutes per item: 2 x 0.15 min = 18 s, shown rounded up as 1 minute.
  @ui @world @slow
  Scenario: Melting two gold chains takes twice as long and yields four bars
    Given I hold 2 "goldchain"
    And I remember how many "goldbar" I have
    And the pawnshop clock reads 12 hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the app "qb-pawnshop:app" should be open
    And the server should place me within safe reach of the pawnshop counter
    When I melt 2 "goldchain" at the pawnshop counter
    Then I should see a notification containing "Come back in 1 minutes"
    And I should have no "goldchain"
    When I wait 10000 milliseconds
    Then I should not see a notification containing "finished melting"
    When I wait 9000 milliseconds
    Then I should see a notification containing "finished melting"
    And the server should place me within safe reach of the pawnshop counter
    When I collect my melted items at the pawnshop counter
    Then I should have 4 more "goldbar" than before

  # Config.MeltingItems rewards per item.
  @ui @world @slow
  Scenario Outline: Melting a "<item>" yields its configured rewards
    Given I hold 1 "<item>"
    And I remember how many "diamond" I have
    And I remember how many "goldbar" I have
    And I remember how many "electronickit" I have
    And the pawnshop clock reads 12 hundred hours
    And I stand at 412.75 315.6 103.13 facing 152.6
    When I aim at 412.34 314.81 103.13
    And I target "Pawn Store"
    Then the app "qb-pawnshop:app" should be open
    And the server should place me within safe reach of the pawnshop counter
    When I melt 1 "<item>" at the pawnshop counter
    Then I should see a notification containing "Your items are melting"
    And I should have no "<item>"
    When I wait 9000 milliseconds
    Then I should see a notification containing "finished melting"
    And the server should place me within safe reach of the pawnshop counter
    When I collect my melted items at the pawnshop counter
    Then I should have <diamond> more "diamond" than before
    And I should have <goldbar> more "goldbar" than before
    And I should have <kit> more "electronickit" than before

    Examples:
      | item          | diamond | goldbar | kit |
      | diamond_ring  | 1       | 1       | 0   |
      | rolex         | 1       | 1       | 1   |
      | tenkgoldchain | 5       | 1       | 0   |
