@kora @kora_metaldetecting
Feature: kora_metaldetecting catalog, detector shop, detector toggle and wash station
  Players buy a metal detector from the shop keeper, sweep suitable ground for
  loot, wash clumps and sell what they found. Prices, positions and item names
  are Config values from kora_metaldetecting/shared/config.lua.

  Not covered: a find and a successful clump wash. Both need a kora_lib
  skillbar proof, which tests never force, and a find awards Metal Detecting
  XP that cannot be removed. The shop app is driven at the NUI-callback level,
  so these scenarios prove the server's price, stock and payout rules, not the
  rendered menu or its confirmation prompt. The server-side rules are also
  driven with the same kora_lib events and callbacks the shop, wash station
  and detector send (request level), standing beside the keeper without
  targeting the ped. Those events are rate limited per player (purchases 2 per 5
  seconds) and a limited call is dropped silently, so purchase scenarios first
  let the window pass. beginWash is only asked where it must refuse: a granted
  wash would authorize a skillbar. The detector scenarios switch the detector
  off within seconds, long before the find cooldown (55 seconds at level 1, 5
  at the maximum level) can start a skillbar.

  Background:
    Given resource "kora_metaldetecting" is running

  @ui
  Scenario: Catalog command opens the metal detecting catalog
    When I run the command "metaldetectcatalog"
    Then the app "kora_metaldetecting:catalog" should be open
    When I close the app
    Then no app should be open

  @world @ui
  Scenario: Shop keeper opens the metal detector shop
    Given I face the metal detector shop keeper
    When I target "Open Metal Detector Shop"
    Then the app "kora_metaldetecting:shop" should be open
    When I close the app
    Then no app should be open

  # Config.Selling.detectorPrice = 500.
  @world @ui
  Scenario: Buying a metal detector with cash charges the listed price
    Given I have 1000 in my "cash" account
    And any "metaldetector" bought from the metal detector shop is handed back afterwards
    And I remember my "cash" balance
    And I remember how many "metaldetector" I have
    And I face the metal detector shop keeper
    When I target "Open Metal Detector Shop"
    Then the app "kora_metaldetecting:shop" should be open
    When I trigger the app action "buy-cash"
    Then I should see a notification containing "Metal detector purchased."
    And I should have 1 more "metaldetector" than before
    And my "cash" balance should have decreased by 500
    And a money change should have been recorded for "cash"
    And no app should be open

  # Config.Loot.sellValues.bottle_cap = 20.
  @world @ui
  Scenario: Selling detected loot pays the listed value per item
    Given I should carry no metal detecting loot of my own
    And I hold 3 "bottle_cap"
    And I remember my "cash" balance
    And I remember how many "bottle_cap" I have
    And I face the metal detector shop keeper
    When I target "Open Metal Detector Shop"
    Then the app "kora_metaldetecting:shop" should be open
    When I trigger the app action "sell-item" with:
      """
      { "itemId": "bottle_cap", "viewId": "sell", "value": { "amount": 2 } }
      """
    Then the app should answer with a "success" notice containing "Selling 2 x bottle_cap..."
    And I should see a notification containing "Sold 2 item(s) for $40."
    And I should have 2 fewer "bottle_cap" than before
    And my "cash" balance should have increased by 40
    And a money change should have been recorded for "cash"

  @world @ui
  Scenario: Buying a metal detector by card charges the bank account
    Given I have 1000 in my "bank" account
    And any "metaldetector" bought from the metal detector shop is handed back afterwards
    And I remember my "bank" balance
    And I remember my "cash" balance
    And I remember how many "metaldetector" I have
    And I face the metal detector shop keeper
    When I target "Open Metal Detector Shop"
    Then the app "kora_metaldetecting:shop" should be open
    When I trigger the app action "buy-card"
    Then I should see a notification containing "Metal detector purchased."
    And I should have 1 more "metaldetector" than before
    And my "bank" balance should have decreased by 500
    And my "cash" balance should be unchanged

  @world @ui @rejection
  Scenario: Shop refuses to sell more loot than the player carries
    Given I should carry no metal detecting loot of my own
    And I hold 1 "bottle_cap"
    And I remember my "cash" balance
    And I remember how many "bottle_cap" I have
    And I face the metal detector shop keeper
    When I target "Open Metal Detector Shop"
    Then the app "kora_metaldetecting:shop" should be open
    When I trigger the app action "sell-item" with:
      """
      { "itemId": "bottle_cap", "viewId": "sell", "value": { "amount": 5 } }
      """
    Then I should see a notification containing "You do not have 5 x bottle_cap."
    And I should have 0 fewer "bottle_cap" than before
    And my "cash" balance should be unchanged

  @world @ui @rejection
  Scenario: Shop sells no detector to a buyer without enough cash
    Given I have 499 in my "cash" account
    And any "metaldetector" bought from the metal detector shop is handed back afterwards
    And I remember my "cash" balance
    And I remember how many "metaldetector" I have
    And I face the metal detector shop keeper
    When I target "Open Metal Detector Shop"
    Then the app "kora_metaldetecting:shop" should be open
    When I trigger the app action "buy-cash"
    Then I should see a notification containing "You cannot afford a metal detector."
    And my "cash" balance should be unchanged
    And I should have 0 more "metaldetector" than before

  @world @ui @rejection
  Scenario: Sell action is not offered to a player without loot
    Given I should carry no metal detecting loot of my own
    And I face the metal detector shop keeper
    When I target "Open Metal Detector Shop"
    Then the app "kora_metaldetecting:shop" should be open
    And the app action "sell-item" should be unavailable

  # Either ground message proves the detector is running: "Suitable ground —
  # the detector is searching." or "This ground is unsuitable for metal detecting."
  @ui
  Scenario: Using the detector switches it on and using it again switches it off
    Given I hold 1 "metaldetector"
    When I switch my metal detector on
    Then the text prompt should show "ground"
    When I switch my metal detector off
    Then no text prompt should be shown

  @ui @rejection
  Scenario: Metal detector cannot be started from a vehicle
    Given I hold 1 "metaldetector"
    And I am driving a temporary "blista"
    When I try to switch my metal detector on
    Then I should see a notification containing "You cannot use a metal detector in a vehicle."
    And no text prompt should be shown

  @world @ui @rejection
  Scenario: Wash station needs a clump
    Given I should have no "clump"
    And I stand at the metal detecting wash station
    Then the interact selector should offer "Wash metal clump"
    When I choose "Wash metal clump" in the interact selector
    Then I should see a notification containing "You need a clump to wash."

  # ===========================================================================
  # Selling loot: server rules (server/main.lua soldLoot)
  # ===========================================================================

  # Config.Loot.sellValues, every entry.
  @world @ui
  Scenario Outline: Shop pays <price> for each <item>
    Given I should carry no metal detecting loot of my own
    And I hold 2 "<item>"
    And I remember my "cash" balance
    And I stand beside the metal detector shop keeper
    When I offer 2 "<item>" to the metal detector shop
    Then I should see a notification containing "Sold 2 item(s) for $<total>."
    And I should have no "<item>"
    And my "cash" balance should have increased by <total>
    And a money change should have been recorded for "cash"

    Examples:
      | item                 | price | total |
      | clump                | 10    | 20    |
      | bobby_pin            | 25    | 50    |
      | bottle_cap           | 20    | 40    |
      | nails                | 30    | 60    |
      | toy_car              | 50    | 100   |
      | corno                | 60    | 120   |
      | car_keys_md          | 100   | 200   |
      | silver_ring_md       | 100   | 200   |
      | gold_ring_md         | 125   | 250   |
      | gold_chain_md        | 150   | 300   |
      | gold_bracelet_md     | 175   | 350   |
      | diamond_earring_md   | 200   | 400   |
      | diamond_ring_md      | 225   | 450   |
      | gold_diamond_ring_md | 250   | 500   |
      | antique_coin         | 275   | 550   |
      | ruby_ring_md         | 300   | 600   |

  @world @ui
  Scenario: Shop sells part of a stack and leaves the rest
    Given I should carry no metal detecting loot of my own
    And I hold 5 "nails"
    And I remember my "cash" balance
    And I remember how many "nails" I have
    And I stand beside the metal detector shop keeper
    When I offer 3 "nails" to the metal detector shop
    Then I should see a notification containing "Sold 3 item(s) for $90."
    And I should have 3 fewer "nails" than before
    And my "cash" balance should have increased by 90

  @world @ui @rejection
  Scenario Outline: Shop refuses to buy <amount> pieces of loot
    Given I should carry no metal detecting loot of my own
    And I hold 2 "bottle_cap"
    And I remember my "cash" balance
    And I remember how many "bottle_cap" I have
    And I stand beside the metal detector shop keeper
    When I offer <amount> "bottle_cap" to the metal detector shop
    Then I should see a notification containing "You do not have <amount> x bottle_cap."
    And I should have 0 fewer "bottle_cap" than before
    And my "cash" balance should be unchanged

    Examples:
      | amount |
      | 0      |
      | -2     |
      | 3      |

  # server/main.lua soldLoot: amount = math.floor(tonumber(amount) or 0).
  @world @ui
  Scenario: Shop rounds a fractional amount down
    Given I should carry no metal detecting loot of my own
    And I hold 3 "bottle_cap"
    And I remember my "cash" balance
    And I remember how many "bottle_cap" I have
    And I stand beside the metal detector shop keeper
    When I offer a fractional 2.7 "bottle_cap" to the metal detector shop
    Then I should see a notification containing "Sold 2 item(s) for $40."
    And I should have 2 fewer "bottle_cap" than before
    And my "cash" balance should have increased by 40

  # tonumber("2") = 2, so a numeric string is a valid amount.
  @world @ui
  Scenario: Shop reads an amount sent as numeric text
    Given I should carry no metal detecting loot of my own
    And I hold 2 "bottle_cap"
    And I remember my "cash" balance
    And I stand beside the metal detector shop keeper
    When I offer the text amount "2" of "bottle_cap" to the metal detector shop
    Then I should see a notification containing "Sold 2 item(s) for $40."
    And I should have no "bottle_cap"
    And my "cash" balance should have increased by 40

  # metalscrap is detecting loot (Config.Loot.items) but has no sell value.
  @world @rejection
  Scenario: Shop ignores loot that has no sell value
    Given I hold 2 "metalscrap"
    And I remember my "cash" balance
    And I remember how many "metalscrap" I have
    And I stand beside the metal detector shop keeper
    When I offer 2 "metalscrap" to the metal detector shop
    Then I wait 1000 milliseconds
    And I should have 0 fewer "metalscrap" than before
    And my "cash" balance should be unchanged

  # Config.Selling.interactionDistance = 5.0 from the shop coords.
  @world @rejection
  Scenario: Shop ignores a sale from a player far away
    Given I should carry no metal detecting loot of my own
    And I hold 2 "bottle_cap"
    And I remember my "cash" balance
    And I remember how many "bottle_cap" I have
    And I stand at the metal detecting wash station
    When I offer 2 "bottle_cap" to the metal detector shop
    Then I wait 1000 milliseconds
    And I should have 0 fewer "bottle_cap" than before
    And my "cash" balance should be unchanged

  @world @rejection
  Scenario: Shop ignores a sale to an unknown shop
    Given I should carry no metal detecting loot of my own
    And I hold 2 "bottle_cap"
    And I remember my "cash" balance
    And I remember how many "bottle_cap" I have
    And I stand beside the metal detector shop keeper
    When I offer 2 "bottle_cap" to metal detector shop number 2
    Then I wait 1000 milliseconds
    And I should have 0 fewer "bottle_cap" than before
    And my "cash" balance should be unchanged

  # Two sales of the only two caps in the same frame: the second finds none.
  @world @ui
  Scenario: A doubled loot sale pays once
    Given I should carry no metal detecting loot of my own
    And I hold 2 "bottle_cap"
    And I remember my "cash" balance
    And I stand beside the metal detector shop keeper
    When I offer 2 "bottle_cap" to the metal detector shop twice at once
    Then I should see a notification containing "Sold 2 item(s) for $40."
    And I should see a notification containing "You do not have 2 x bottle_cap."
    And I should have no "bottle_cap"
    And my "cash" balance should have increased by 40

  # client/shop.lua onAction: amount < 1 returns before any server request.
  @world @ui @rejection
  Scenario: Shop app ignores a sale of zero items
    Given I should carry no metal detecting loot of my own
    And I hold 1 "bottle_cap"
    And I remember my "cash" balance
    And I remember how many "bottle_cap" I have
    And I face the metal detector shop keeper
    When I target "Open Metal Detector Shop"
    Then the app "kora_metaldetecting:shop" should be open
    When I trigger the app action "sell-item" with:
      """
      { "itemId": "bottle_cap", "viewId": "sell", "value": { "amount": 0 } }
      """
    Then I should not see a notification containing "x bottle_cap"
    And I should have 0 fewer "bottle_cap" than before
    And my "cash" balance should be unchanged

  # ===========================================================================
  # Buying a detector: server rules (server/main.lua purchasedDetector)
  # Purchases are limited to 2 per 5 seconds per player, so each scenario first
  # lets the previous scenario's window pass.
  # ===========================================================================

  # Config.Selling.detectorPrice = 500.
  @world @ui
  Scenario: Exactly the detector price in cash buys a detector
    Given I wait 5000 milliseconds
    And I have 500 in my "cash" account
    And any "metaldetector" bought from the metal detector shop is handed back afterwards
    And I remember my "cash" balance
    And I remember how many "metaldetector" I have
    And I stand beside the metal detector shop keeper
    When I order a metal detector paying by "cash"
    Then I should see a notification containing "Metal detector purchased."
    And I should have 1 more "metaldetector" than before
    And my "cash" balance should have decreased by 500

  @world @ui @rejection
  Scenario: Card purchase is refused when the bank is one dollar short
    Given I wait 5000 milliseconds
    And I have 499 in my "bank" account
    And I have 1000 in my "cash" account
    And any "metaldetector" bought from the metal detector shop is handed back afterwards
    And I remember my "bank" balance
    And I remember my "cash" balance
    And I remember how many "metaldetector" I have
    And I stand beside the metal detector shop keeper
    When I order a metal detector paying by "bank"
    Then I should see a notification containing "You cannot afford a metal detector."
    And my "bank" balance should be unchanged
    And my "cash" balance should be unchanged
    And I should have 0 more "metaldetector" than before

  @world @rejection
  Scenario: Shop ignores a purchase from an account other than cash or bank
    Given I wait 5000 milliseconds
    And I have 1000 in my "cash" account
    And any "metaldetector" bought from the metal detector shop is handed back afterwards
    And I remember my "cash" balance
    And I remember how many "metaldetector" I have
    And I stand beside the metal detector shop keeper
    When I order a metal detector paying by "crypto"
    Then I wait 1000 milliseconds
    And my "cash" balance should be unchanged
    And I should have 0 more "metaldetector" than before

  @world @rejection
  Scenario: Shop ignores a purchase from an unknown shop
    Given I wait 5000 milliseconds
    And I have 1000 in my "cash" account
    And any "metaldetector" bought from the metal detector shop is handed back afterwards
    And I remember my "cash" balance
    And I remember how many "metaldetector" I have
    And I stand beside the metal detector shop keeper
    When I order a metal detector from shop number 2 paying by "cash"
    Then I wait 1000 milliseconds
    And my "cash" balance should be unchanged
    And I should have 0 more "metaldetector" than before

  @world @rejection
  Scenario: Shop ignores a purchase from a player far away
    Given I wait 5000 milliseconds
    And I have 1000 in my "cash" account
    And any "metaldetector" bought from the metal detector shop is handed back afterwards
    And I remember my "cash" balance
    And I remember how many "metaldetector" I have
    And I stand at the metal detecting wash station
    When I order a metal detector paying by "cash"
    Then I wait 1000 milliseconds
    And my "cash" balance should be unchanged
    And I should have 0 more "metaldetector" than before

  # server/main.lua purchasedDetector: rateLimit max 2 per 5000 ms; the third
  # request in the same moment is dropped.
  @world @ui
  Scenario: Detector purchases are limited to two in quick succession
    Given I wait 5000 milliseconds
    And I have 2000 in my "cash" account
    And any "metaldetector" bought from the metal detector shop is handed back afterwards
    And I remember my "cash" balance
    And I remember how many "metaldetector" I have
    And I stand beside the metal detector shop keeper
    When I order a metal detector paying by "cash" 3 times at once
    Then I should have 2 more "metaldetector" than before
    And my "cash" balance should have decreased by 1000

  # ===========================================================================
  # Wash station: server rules (server/main.lua beginWash / washedClump)
  # ===========================================================================

  @world @ui @rejection
  Scenario Outline: Wash station <station> needs a clump
    Given I should have no "clump"
    And I stand at metal detecting wash station <station>
    Then the interact selector should offer "Wash metal clump"
    When I choose "Wash metal clump" in the interact selector
    Then I should see a notification containing "You need a clump to wash."

    Examples:
      | station |
      | 2       |
      | 3       |

  @world @rejection
  Scenario: Server will not begin a wash without a clump
    Given I should have no "clump"
    And I stand at the metal detecting wash station
    When I ask to begin washing a clump at wash station 1
    Then the metal detecting server should have answered no

  # Config.Selling.wash has three stations.
  @world @rejection
  Scenario: Server will not begin a wash at an unknown station
    Given I hold 1 "clump"
    And I stand at the metal detecting wash station
    When I ask to begin washing a clump at wash station 4
    Then the metal detecting server should have answered no
    And I should have 1 "clump"

  @world @rejection
  Scenario: Server will not begin a wash for a player far from the station
    Given I hold 1 "clump"
    And I stand beside the metal detector shop keeper
    When I ask to begin washing a clump at wash station 1
    Then the metal detecting server should have answered no
    And I should have 1 "clump"

  # Without a beginWash authorization and a skillbar proof the clump stays.
  @world @rejection
  Scenario: A forged clump wash keeps the clump and finds nothing
    Given I hold 1 "clump"
    And I note my metal detecting loot and XP
    And I stand at the metal detecting wash station
    When I send a forged clump wash at wash station 1
    Then I wait 1000 milliseconds
    And I should have 1 "clump"
    And my metal detecting loot and XP should be unchanged

  @world @ui @rejection
  Scenario: Washing without a clump is refused by the server too
    Given I should have no "clump"
    And I stand at the metal detecting wash station
    When I send a forged clump wash at wash station 1
    Then I should see a notification containing "You do not have a clump to wash."

  @world @rejection
  Scenario: A wash sent from far away is ignored
    Given I hold 1 "clump"
    And I note my metal detecting loot and XP
    And I stand beside the metal detector shop keeper
    When I send a forged clump wash at wash station 1
    Then I wait 1000 milliseconds
    And I should not see a notification containing "You do not have a clump to wash."
    And I should have 1 "clump"
    And my metal detecting loot and XP should be unchanged

  # ===========================================================================
  # Detector: server find rules (server/main.lua beginFind / completedFind)
  # ===========================================================================

  # 1288448767 is the first entry of Config.Detection.allowedGrounds.
  @rejection
  Scenario: Server will not begin a find while the detector is off
    Given I hold 1 "metaldetector"
    When I ask the metal detector to begin a find on ground 1288448767
    Then the metal detecting server should have answered no

  # The find cooldown (55 s at level 1, 5 s at the top level) starts when the
  # detector is switched on.
  @ui @rejection
  Scenario: Server will not begin a find before the find cooldown has passed
    Given I hold 1 "metaldetector"
    When I switch my metal detector on
    Then the text prompt should show "ground"
    When I ask the metal detector to begin a find on ground 1288448767
    Then the metal detecting server should have answered no
    When I switch my metal detector off
    Then no text prompt should be shown

  @ui @rejection
  Scenario: Server will not begin a find on ground that is not allowed
    Given I hold 1 "metaldetector"
    When I switch my metal detector on
    Then the text prompt should show "ground"
    When I ask the metal detector to begin a find on ground 12345
    Then the metal detecting server should have answered no
    When I switch my metal detector off
    Then no text prompt should be shown

  @rejection
  Scenario: A forged find pays no loot and no XP
    Given I hold 1 "metaldetector"
    And I note my metal detecting loot and XP
    When I send a forged metal detecting find on ground 1288448767
    Then I wait 1000 milliseconds
    And my metal detecting loot and XP should be unchanged

  # ===========================================================================
  # Detector: client rules (client/main.lua)
  # ===========================================================================

  @ui
  Scenario: Detector can be switched on again after being switched off
    Given I hold 1 "metaldetector"
    When I switch my metal detector on
    Then the text prompt should show "ground"
    When I switch my metal detector off
    Then no text prompt should be shown
    When I switch my metal detector on
    Then the text prompt should show "ground"
    When I switch my metal detector off
    Then no text prompt should be shown

  # client/main.lua Kora.cache.onChange('vehicle'): stops and tells the server.
  @ui @rejection
  Scenario: Getting into a vehicle stops the detector
    Given I hold 1 "metaldetector"
    When I switch my metal detector on
    Then the text prompt should show "ground"
    When I am driving a temporary "blista"
    Then my metal detector has been switched off for me
    And my metal detector is switched off afterwards
    And I should see a notification containing "Metal detecting stopped in a vehicle."
    And no text prompt should be shown

  # ===========================================================================
  # Catalog (client/catalog.lua)
  # ===========================================================================

  # client/catalog.lua returns early when the catalog is already open.
  @ui
  Scenario: Running the catalog command twice keeps one catalog open
    When I run the command "metaldetectcatalog"
    Then the app "kora_metaldetecting:catalog" should be open
    When I run the command "metaldetectcatalog"
    Then the app "kora_metaldetecting:catalog" should be open
    When I close the app
    Then no app should be open
