@kora @kora_customs
Feature: kora_customs public custom shops
  Benny's (Config.shops.bennys in kora_customs/config.lua) offers cosmetic
  customisation and, when no mechanic is on duty, a $750 self-service repair
  charged to the bank (Config.selfRepair). The shop app and the repair
  confirmation are answered at the NUI-callback level through kora_lib's hook;
  the zone options are selected through kora_target's real targeting loop while
  sitting in the driver seat, which depends on the camera ray (@world).
  "Discard changes" answers { close = true } and the browser then closes the
  shell; at the callback level the discard step settles the app the same way
  after asserting that answer.

  Repair scenarios use the approved seam (a reset of the tester's own repair
  cooldown, kora_customs/fft_hooks_server.lua) and are tagged @seam. They also
  need no other mechanic on duty: the option is hidden for everyone otherwise.

  Preview scenarios paint the temporary vehicle palette 0/0 first, then read
  the running total from the shop's view description ("Pending total: $N"):
  the open payload through kora_lib's hook, later changes from the updateApp
  messages its hook logs. Prices are Config.prices.

  Not covered: a successful purchase (kora_customs:quote and kora_customs:purchase
  need an owned vehicle that is out and driven by the tester, and a paid order
  permanently rewrites the stored mods of that row; the unowned refusal is
  covered), the factory-look baseline (same owned-row need), freecam (camera
  loop that only ends on a key press), vehicle extras (model dependent),
  cancelling the repair progress bar (kora_lib's hook has no cancel action),
  the server's "mechanic on duty" refusal (needs a second player on duty) and
  the callback rate limits.

  Background:
    Given resource "kora_customs" is running

  @ui
  Scenario: Shop app opens for a driver and discarding closes it
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    When I open the custom shop "bennys"
    Then the app "kora_customs:shop" should be open
    When I discard the custom shop changes
    Then no app should be open

  @ui @world
  Scenario: Target option opens the shop app from the driver seat
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    When I target "Customise vehicle at Benny's Original Motor Works"
    Then the app "kora_customs:shop" should be open
    When I discard the custom shop changes
    Then no app should be open

  @ui @rejection
  Scenario: Checkout without a previewed change charges nothing
    Given I have 5000 in my "bank" account
    And I remember my "bank" balance
    And I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    When I open the custom shop "bennys"
    Then the app "kora_customs:shop" should be open
    When I trigger the app action "checkout"
    Then the app should answer with a "warning" notice containing "No changes are selected."
    And my "bank" balance should be unchanged
    When I discard the custom shop changes
    Then no app should be open

  @ui @rejection
  Scenario: Shop refuses to open on foot
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    When I open the custom shop "bennys"
    Then I should see a notification containing "Sit in the driver seat of your vehicle."
    And no app should be open

  @world @rejection
  Scenario: Shop zone offers nothing on foot
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    Then no target option should be visible

  @seam @ui @world @slow
  Scenario: Self-service repair fixes the vehicle and charges the bank
    Given my custom shop repair cooldown is cleared
    And I have 1000 in my "bank" account
    And I remember my "bank" balance
    And I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    And the vehicle I am driving is damaged for the custom shop
    When I target "Repair vehicle ($750)"
    Then a confirmation should open
    When I confirm
    Then a progress bar labelled "Repairing vehicle" should start
    When I wait 9000 milliseconds
    Then the progress bar should finish
    And I should see a notification containing "Vehicle repaired for $750."
    And my "bank" balance should have decreased by 750
    And a money change should have been recorded for "bank"
    And the vehicle I am driving should be fully repaired

  @seam @ui @world @rejection @slow
  Scenario: Repair is refused without enough money in the bank
    Given my custom shop repair cooldown is cleared
    And I have 100 in my "bank" account
    And I remember my "bank" balance
    And I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    And the vehicle I am driving is damaged for the custom shop
    When I target "Repair vehicle ($750)"
    Then a confirmation should open
    When I confirm
    Then a progress bar labelled "Repairing vehicle" should start
    When I wait 9000 milliseconds
    Then the progress bar should finish
    And I should see a notification containing "insufficient funds"
    And my "bank" balance should be unchanged
    And the vehicle I am driving should still need a repair

  @seam @ui @world @rejection
  Scenario: Declining the repair confirmation charges nothing
    Given my custom shop repair cooldown is cleared
    And I have 1000 in my "bank" account
    And I remember my "bank" balance
    And I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    And the vehicle I am driving is damaged for the custom shop
    When I target "Repair vehicle ($750)"
    Then a confirmation should open
    When I decline
    Then no progress bar should be running
    And my "bank" balance should be unchanged
    And the vehicle I am driving should still need a repair

  @ui @world @rejection
  Scenario: Undamaged vehicle is not offered a paid repair
    Given I have 1000 in my "bank" account
    And I remember my "bank" balance
    And I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    When I target "Repair vehicle ($750)"
    Then I should see a notification containing "This vehicle does not need a repair."
    And my "bank" balance should be unchanged

  @seam @ui @world @rejection @slow
  Scenario: Second repair inside the cooldown is refused
    Given my custom shop repair cooldown is cleared
    And I have 2000 in my "bank" account
    And I remember my "bank" balance
    And I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    And the vehicle I am driving is damaged for the custom shop
    When I target "Repair vehicle ($750)"
    And I confirm
    Then a progress bar labelled "Repairing vehicle" should start
    When I wait 9000 milliseconds
    Then the progress bar should finish
    And I should see a notification containing "Vehicle repaired for $750."
    Given the vehicle I am driving is damaged for the custom shop
    When I target "Repair vehicle ($750)"
    And I confirm
    Then I should see a notification containing "you can repair here again in"
    And my "bank" balance should have decreased by 750
    And the vehicle I am driving should still need a repair

  @world @rejection
  Scenario: Repair option is hidden while a mechanic is on duty
    # The tester is the on-duty mechanic (Config.selfRepair.mechanicJobs), so
    # only the customise option passes canInteract.
    Given I am on duty as "mechanic" at grade 1
    And I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    Then the custom shop zone should offer only "Customise vehicle at Benny's Original Motor Works"

  # ---------------------------------------------------------------------------
  # Every shop in Config.shops (config.lua): zone option, app title = label.
  # ---------------------------------------------------------------------------

  @ui @world
  Scenario Outline: The <shop> zone opens its own shop
    Given I stand at <x> <y> <z> facing 0.0
    And I am driving a temporary "sultan"
    When I target "Customise vehicle at <label>"
    Then the app "kora_customs:shop" should be open
    And the custom shop app should be titled "<label>"
    And the custom shop should show nothing selected
    When I discard the custom shop changes
    Then no app should be open

    Examples:
      | shop    | label                        | x       | y        | z     |
      | bennys  | Benny's Original Motor Works | -211.55 | -1324.55 | 30.89 |
      | laMesa  | La Mesa Customs              | 731.68  | -1088.78 | 22.17 |
      | route68 | Route 68 Customs             | 1174.76 | 2640.15  | 37.75 |

  @world @rejection
  Scenario: A passenger is offered nothing at the shop
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    And I sit as a passenger in a temporary "sultan"
    Then no target option should be visible

  @ui @rejection
  Scenario: A passenger cannot open the shop
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    And I sit as a passenger in a temporary "sultan"
    When I open the custom shop "bennys"
    Then I should see a notification containing "Sit in the driver seat of your vehicle."
    And no app should be open

  # client/main.lua open(): an unknown shop id returns before anything else.
  @ui @rejection
  Scenario: An unknown shop id opens nothing
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    When I open the custom shop "fft_no_such_shop"
    Then no app should be open
    And I should not see a notification containing "Sit in the driver seat"

  # The session guard closes a shop whose zone is further than
  # Config.interaction.checkoutDistance (12.0) from the vehicle.
  @ui @rejection
  Scenario: A shop opened far from its zone closes straight away
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    When I open the custom shop "laMesa"
    Then I should see a notification containing "You left the custom shop; previews were reverted."
    And no app should be open

  @ui @rejection
  Scenario: A second session cannot be opened over the first
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    When I open the custom shop "bennys"
    Then the app "kora_customs:shop" should be open
    When I open the custom shop "bennys"
    Then I should see a notification containing "A customisation session is already open."
    And the app "kora_customs:shop" should be open
    When I discard the custom shop changes
    Then no app should be open

  # ---------------------------------------------------------------------------
  # Previews and prices (client/main.lua preview/total, shared/catalog.lua
  # Customs.price with Config.prices). The vehicle starts on palette 0/0.
  # ---------------------------------------------------------------------------

  @ui
  Scenario Outline: Previewing <action> costs <total>
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    And the vehicle I am driving has plain paint 0 and 0
    When I open the custom shop "bennys"
    Then the app "kora_customs:shop" should be open
    And the custom shop should show nothing selected
    When I preview the custom shop option "<action>" with "<value>"
    Then the custom shop should show a pending total of "<total>"
    When I discard the custom shop changes
    Then no app should be open
    And the vehicle I am driving should have primary paint 0

    Examples:
      | action                | value   | total |
      | set:color1            | 27      | $350  |
      | set:color2            | 27      | $300  |
      | set:pearlescentColor  | 27      | $300  |
      | set:wheelColor        | 27      | $250  |
      | set:windowTint        | 3       | $350  |
      | set:plateIndex        | 5       | $250  |
      | set:wheels            | 4       | $750  |
      | toggle:modXenon       |         | $300  |
      | toggle:neonEnabled    |         | $300  |
      | color:color1          | #ff0000 | $600  |
      | color:color2          | #ff0000 | $500  |
      | color:neonColor       | #00ff00 | $300  |
      | color:tyreSmokeColor  | #ff0000 | $600  |
      | step:color1:1         |         | $350  |
      | step:color1:-1        |         | $350  |

  # client/main.lua setField / pickColor drop values outside the row's range
  # or that are not a 6-digit hex colour; nothing is previewed.
  @ui @rejection
  Scenario Outline: Previewing <action> with "<value>" is ignored
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    And the vehicle I am driving has plain paint 0 and 0
    When I open the custom shop "bennys"
    Then the app "kora_customs:shop" should be open
    When I preview the custom shop option "<action>" with "<value>"
    Then the custom shop should show nothing selected
    And the vehicle I am driving should have primary paint 0
    When I discard the custom shop changes
    Then no app should be open

    Examples:
      | action       | value   |
      | set:color1   | 161     |
      | set:color1   | -1      |
      | set:color1   | 2.5     |
      | set:color1   | red     |
      | color:color1 | red     |
      | color:color1 | #12345  |

  # Only the cosmetic rows are declared; kora_lib refuses anything else.
  @ui @rejection
  Scenario Outline: The shop offers no "<action>" action
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    When I open the custom shop "bennys"
    Then the app "kora_customs:shop" should be open
    And the app action "<action>" should be unavailable
    When I discard the custom shop changes
    Then no app should be open

    Examples:
      | action             |
      | set:modTurbo       |
      | step:modEngine:1   |
      | toggle:modArmor    |
      | color:fft_nothing  |

  @ui
  Scenario: The step wraps from the first palette colour to the last
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    And the vehicle I am driving has plain paint 0 and 0
    When I open the custom shop "bennys"
    Then the app "kora_customs:shop" should be open
    When I trigger the app action "step:color1:-1"
    Then the vehicle I am driving should have primary paint 160
    When I trigger the app action "step:color1:1"
    Then the vehicle I am driving should have primary paint 0
    And the custom shop should show nothing selected
    When I discard the custom shop changes
    Then no app should be open

  @ui
  Scenario: A field is charged once however often it is previewed
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    And the vehicle I am driving has plain paint 0 and 0
    When I open the custom shop "bennys"
    Then the app "kora_customs:shop" should be open
    When I preview the custom shop option "set:color1" with "27"
    And I preview the custom shop option "set:color1" with "40"
    Then the custom shop should show a pending total of "$350"
    And the vehicle I am driving should have primary paint 40
    When I preview the custom shop option "set:color2" with "27"
    Then the custom shop should show a pending total of "$650"
    When I preview the custom shop option "set:color1" with "0"
    Then the custom shop should show a pending total of "$300"
    When I discard the custom shop changes
    Then no app should be open
    And the vehicle I am driving should have primary paint 0

  @ui
  Scenario: Discarding puts a custom paint preview back
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    And the vehicle I am driving has plain paint 0 and 0
    When I open the custom shop "bennys"
    Then the app "kora_customs:shop" should be open
    When I preview the custom shop option "color:color1" with "#ff0000"
    Then the vehicle I am driving should have custom primary paint 255 0 0
    And the custom shop should show a pending total of "$600"
    When I discard the custom shop changes
    Then no app should be open
    And the vehicle I am driving should have primary paint 0

  # ---------------------------------------------------------------------------
  # Session guards and checkout (client/main.lua open() guard thread, checkout).
  # ---------------------------------------------------------------------------

  @ui @rejection
  Scenario: Leaving the driver seat ends the session and reverts the preview
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    And the vehicle I am driving has plain paint 0 and 0
    When I open the custom shop "bennys"
    Then the app "kora_customs:shop" should be open
    When I preview the custom shop option "set:color1" with "27"
    Then the vehicle I am driving should have primary paint 27
    When I leave the driver seat
    Then I should see a notification containing "You must remain in the driver seat."
    And no app should be open
    And the temporary vehicle should have primary paint 0

  @ui @rejection
  Scenario: Driving out of the shop ends the session and reverts the preview
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    And the vehicle I am driving has plain paint 0 and 0
    When I open the custom shop "bennys"
    Then the app "kora_customs:shop" should be open
    When I preview the custom shop option "set:color1" with "27"
    Then the vehicle I am driving should have primary paint 27
    When the vehicle I am driving is moved 20 metres forward
    Then I should see a notification containing "You left the custom shop; previews were reverted."
    And no app should be open
    And the vehicle I am driving should have primary paint 0

  @ui @rejection
  Scenario: Hiding the menu keeps the preview until the driver leaves
    Given I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    And the vehicle I am driving has plain paint 0 and 0
    When I open the custom shop "bennys"
    Then the app "kora_customs:shop" should be open
    When I preview the custom shop option "set:color1" with "27"
    And I hide the custom shop menu
    Then no app should be open
    And the vehicle I am driving should have primary paint 27
    When I leave the driver seat
    Then I should see a notification containing "You must remain in the driver seat."
    And no app should be open
    And the temporary vehicle should have primary paint 0

  # A temporary vehicle has no player_vehicles row: the server quote refuses it
  # (server/main.lua ownedRow), the client reverts and closes (checkout abort).
  @ui @rejection
  Scenario: Checkout of an unowned vehicle is refused and reverted
    Given I have 5000 in my "bank" account
    And I remember my "bank" balance
    And I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    And the vehicle I am driving has plain paint 0 and 0
    When I open the custom shop "bennys"
    Then the app "kora_customs:shop" should be open
    When I preview the custom shop option "set:color1" with "27"
    Then the custom shop should show a pending total of "$350"
    When I trigger the app action "checkout"
    Then I should see a notification containing "this vehicle is not owned"
    And no app should be open
    And no custom shop purchase confirmation should be open
    And my "bank" balance should be unchanged
    And the vehicle I am driving should have primary paint 0

  # ---------------------------------------------------------------------------
  # Self-service repair (Config.selfRepair: $750 bank, 10 s, no mechanic on duty).
  # ---------------------------------------------------------------------------

  @seam @ui @world @slow
  Scenario: The repair is paid with exactly the price in the bank
    Given my custom shop repair cooldown is cleared
    And I have 750 in my "bank" account
    And I remember my "bank" balance
    And I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    And the vehicle I am driving is damaged for the custom shop
    When I target "Repair vehicle ($750)"
    Then a confirmation should open
    When I confirm
    Then a progress bar labelled "Repairing vehicle" should start
    And the repair progress bar should last 10000 milliseconds
    When I wait 9000 milliseconds
    Then the progress bar should finish
    And I should see a notification containing "Vehicle repaired for $750."
    And my "bank" balance should have decreased by 750
    And the vehicle I am driving should be fully repaired

  @seam @ui @world @slow
  Scenario Outline: The repair is offered at <label>
    Given my custom shop repair cooldown is cleared
    And I have 1000 in my "bank" account
    And I remember my "bank" balance
    And I stand at <x> <y> <z> facing 0.0
    And I am driving a temporary "sultan"
    And the vehicle I am driving is damaged for the custom shop
    When I target "Repair vehicle ($750)"
    Then a confirmation should open
    When I confirm
    Then a progress bar labelled "Repairing vehicle" should start
    When I wait 9000 milliseconds
    Then the progress bar should finish
    And I should see a notification containing "Vehicle repaired for $750."
    And my "bank" balance should have decreased by 750
    And the vehicle I am driving should be fully repaired

    Examples:
      | label            | x       | y        | z     |
      | La Mesa Customs  | 731.68  | -1088.78 | 22.17 |
      | Route 68 Customs | 1174.76 | 2640.15  | 37.75 |

  # Only on-duty mechanics hide the option (Customs.mechanicsOnDuty counts
  # GlobalState.OnDuty); an off-duty mechanic is a normal customer.
  @ui @world
  Scenario: An off-duty mechanic is still offered the repair
    Given I am off duty as "mechanic" at grade 1
    And I stand at -211.55 -1324.55 30.89 facing 0.0
    And I am driving a temporary "sultan"
    When I target "Repair vehicle ($750)"
    Then I should see a notification containing "This vehicle does not need a repair."
