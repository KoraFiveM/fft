@kora @kora_fishing
Feature: kora_fishing shop, fish buyer, salvage breakdown and pole zone rule
  Players buy poles and bait from the fishing shop, sell fish to the buyer and
  refine magnet-fishing salvage into crafting materials. Prices, positions and
  item names are Config values from kora_fishing/shared/config.lua.

  Not covered: catching. A catch needs a kora_lib minigame proof, which tests
  never force, and it awards Fishing XP that cannot be removed. Casting inside
  a zone is only driven where the server ends the cast before any minigame:
  without bait (beginCatch refuses) or with the pole used again in the same
  frame (the server reels the line in first). The shop, buyer and refine apps
  are driven at the NUI-callback level, so these scenarios prove the server's
  stock, price and payout rules, not the rendered menu. The server-side
  validations are also driven with the same net events and callbacks the apps
  send (request level), standing beside the NPC or bench without targeting it.
  The server rejects bad requests with a Lua assert, so refusal scenarios log
  a script error on the server by design and declare it.

  Background:
    Given resource "kora_fishing" is running

  @world @ui
  Scenario: Shop keeper opens the fishing shop
    Given I face the fishing shop keeper
    When I target "Open Fishing Shop"
    Then the app "kora_fishing:shop" should be open
    When I close the app
    Then no app should be open

  # Config.Shop.items[3] = worm, price 10, level 1.
  @world @ui
  Scenario: Buying bait charges the listed price per unit
    Given I have 500 in my "cash" account
    And any "worm" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I remember how many "worm" I have
    And I face the fishing shop keeper
    When I target "Open Fishing Shop"
    Then the app "kora_fishing:shop" should be open
    When I trigger the app action "kora_fishing:purchase" with:
      """
      { "itemId": "shop:3", "value": { "amount": 2 } }
      """
    Then I should have 2 more "worm" than before
    And my "cash" balance should have decreased by 20
    And a money change should have been recorded for "cash"

  # Config.Shop.items[1] = fishing_pole, price 100, level 1.
  @world @ui @rejection
  Scenario: Fishing shop sells nothing to a buyer without enough cash
    Given I have 5 in my "cash" account
    And any "fishing_pole" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I face the fishing shop keeper
    When I target "Open Fishing Shop"
    Then the app "kora_fishing:shop" should be open
    When I trigger the app action "kora_fishing:purchase" with:
      """
      { "itemId": "shop:1", "value": { "amount": 1 } }
      """
    Then my "cash" balance should be unchanged
    And I should have no "fishing_pole"

  @world @ui @rejection
  Scenario: Fishing shop rejects an amount of zero
    Given I have 500 in my "cash" account
    And any "worm" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I face the fishing shop keeper
    When I target "Open Fishing Shop"
    Then the app "kora_fishing:shop" should be open
    When I trigger the app action "kora_fishing:purchase" with:
      """
      { "itemId": "shop:3", "value": { "amount": 0 } }
      """
    Then the app should answer with a "destructive" notice containing "Enter a valid amount."
    And my "cash" balance should be unchanged
    And I should have no "worm"

  # Config.Shop.items[2] = magnet_pole, price 150, level 15. The menu hides it
  # below level 15; this sends the request anyway to prove the server's check.
  @world @ui @rejection
  Scenario: Server refuses a level-locked purchase the menu does not offer
    Given my fishing level should be below 15
    And I have 500 in my "cash" account
    And any "magnet_pole" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I face the fishing shop keeper
    When I target "Open Fishing Shop"
    Then the app "kora_fishing:shop" should be open
    # The server refuses with an assert (kora_fishing/server/shops.lua:19),
    # which FiveM prints to the server console as a SCRIPT ERROR.
    And I expect a console error from "kora_fishing" containing "Your fishing level is too low to purchase this item"
    When I trigger the app action "kora_fishing:purchase" with:
      """
      { "itemId": "shop:2", "value": { "amount": 1 } }
      """
    Then my "cash" balance should be unchanged
    And I should have no "magnet_pole"

  @world @rejection
  Scenario: Fish buyer turns away a player with nothing to sell
    Given I should have no "flounder"
    And I remember my "cash" balance
    And I face the fish buyer
    When I target "Open Buyer Menu"
    Then I should see a notification containing "You do not have any items to sell."
    And no app should be open
    And my "cash" balance should be unchanged

  # Config.Locations.buyer.items[1] = flounder, price 15.
  @world @ui
  Scenario: Selling fish pays the listed price per fish
    Given I hold 3 "flounder"
    And I remember my "cash" balance
    And I remember how many "flounder" I have
    And I face the fish buyer
    When I target "Open Buyer Menu"
    Then the app "kora_fishing:buyer" should be open
    When I trigger the app action "kora_fishing:sell" with:
      """
      { "itemId": "buyer:1", "value": { "amount": 2 } }
      """
    Then I should have 2 fewer "flounder" than before
    And my "cash" balance should have increased by 30
    And a money change should have been recorded for "cash"

  @world @ui @rejection
  Scenario: Fish buyer pays nothing for more fish than the seller holds
    Given I hold 1 "flounder"
    And I remember my "cash" balance
    And I face the fish buyer
    When I target "Open Buyer Menu"
    Then the app "kora_fishing:buyer" should be open
    When I trigger the app action "kora_fishing:sell" with:
      """
      { "itemId": "buyer:1", "value": { "amount": 5 } }
      """
    Then my "cash" balance should be unchanged
    And I should have 1 "flounder"

  @world @rejection
  Scenario: Breakdown bench turns away a player with no salvage
    Given I should have no "rusty_usb"
    And I note my crafting materials before refining fishing salvage
    And I face the fishing breakdown bench
    When I target "Open Refine Menu"
    Then I should see a notification containing "You do not have any items to refine."
    And no app should be open
    And refining fishing salvage should have paid nothing

  # Config.Locations.breakdown: rusty_usb is entry 1 with rank 1, so one roll of
  # receiveAmounts 4-10 of one random material after a 5 second progress bar.
  @world @ui
  Scenario: Refining salvage consumes it and pays crafting materials
    Given I hold 1 "rusty_usb"
    And I note my crafting materials before refining fishing salvage
    And I face the fishing breakdown bench
    When I target "Open Refine Menu"
    Then the app "kora_fishing:breakdown" should be open
    When I refine the fishing salvage entry "refine:1"
    Then the progress bar should finish
    And I should have no "rusty_usb"
    And refining fishing salvage should have paid between 4 and 10 crafting materials

  # The breakdown bench is inland, outside every Config.zones polygon.
  @world @rejection
  Scenario: A pole cannot be cast outside a fishing zone
    Given I hold 1 "fishing_pole"
    And I face the fishing breakdown bench
    When I use my fishing pole "fishing_pole"
    Then I should see a notification containing "You are not in a fishing zone."
    And no progress bar should be running
    And I should have 1 "fishing_pole"

  # ===========================================================================
  # Fishing shop: server rules (server/shops.lua purchaseItem)
  # ===========================================================================

  # Config.Shop.items: the level-locked entries. The menu hides them below the
  # level; the request is sent anyway to prove the server's own check.
  @world @rejection
  Scenario Outline: Server refuses shop item <index> "<item>" below fishing level <level>
    Given my fishing level should be below <level>
    And I have 1000 in my "cash" account
    And any "<item>" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I stand beside the fishing shop keeper
    # kora_fishing/server/shops.lua:19
    And I expect a console error from "kora_fishing" containing "Your fishing level is too low to purchase this item"
    When I ask the fishing shop to sell me 1 of shop item <index>
    Then my "cash" balance should be unchanged
    And I should have no "<item>"

    Examples:
      | index | item              | level |
      | 4     | plug_bait         | 15    |
      | 5     | soft_plastic_bait | 30    |
      | 6     | spinner_bait      | 45    |
      | 7     | magnet_2lb        | 15    |
      | 8     | magnet_5lb        | 30    |
      | 9     | magnet_10lb       | 45    |
      | 10    | magnet_20lb       | 60    |

  # Config.Shop.items[1] = fishing_pole, price 100.
  @world
  Scenario: Exactly enough cash buys a fishing pole
    Given I have 100 in my "cash" account
    And any "fishing_pole" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I remember how many "fishing_pole" I have
    And I stand beside the fishing shop keeper
    When I ask the fishing shop to sell me 1 of shop item 1
    Then I should have 1 more "fishing_pole" than before
    And my "cash" balance should have decreased by 100

  @world @rejection
  Scenario: One dollar short buys no fishing pole
    Given I have 99 in my "cash" account
    And any "fishing_pole" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I stand beside the fishing shop keeper
    When I ask the fishing shop to sell me 1 of shop item 1
    Then my "cash" balance should be unchanged
    And I should have no "fishing_pole"

  # Config.Shop.items[3] = worm, price 10.
  @world
  Scenario: Buying several worms charges the price for each
    Given I have 500 in my "cash" account
    And any "worm" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I remember how many "worm" I have
    And I stand beside the fishing shop keeper
    When I ask the fishing shop to sell me 5 of shop item 3
    Then I should have 5 more "worm" than before
    And my "cash" balance should have decreased by 50

  # Config.Shop.items[3].amount = 50 and the menu shows "In Stock: 50";
  # server/shops.lua refuses a larger purchase with an assert.
  @world @rejection
  Scenario: Fishing shop does not sell more worms than it has in stock
    Given I have 1000 in my "cash" account
    And I expect a console error from "kora_fishing" containing "The shop does not have that many in stock"
    And any "worm" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I stand beside the fishing shop keeper
    When I ask the fishing shop to sell me 51 of shop item 3
    Then my "cash" balance should be unchanged
    And I should have no "worm"

  @world @rejection
  Scenario: Fishing shop sells nothing when the total is unaffordable
    Given I have 500 in my "cash" account
    # 1000000 is also over the 50 in stock, which server/shops.lua checks first.
    And I expect a console error from "kora_fishing" containing "The shop does not have that many in stock"
    And any "worm" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I stand beside the fishing shop keeper
    When I ask the fishing shop to sell me 1000000 of shop item 3
    Then my "cash" balance should be unchanged
    And I should have no "worm"

  @world @rejection
  Scenario Outline: Fishing shop refuses shop item <index> as an unknown item
    Given I have 500 in my "cash" account
    And I remember my "cash" balance
    And I stand beside the fishing shop keeper
    # kora_fishing/server/shops.lua:15
    And I expect a console error from "kora_fishing" containing "Item does not exist"
    When I ask the fishing shop to sell me 1 of shop item <index>
    Then my "cash" balance should be unchanged

    Examples:
      | index |
      | 0     |
      | 11    |
      | 99    |

  @world @rejection
  Scenario Outline: Fishing shop refuses an amount of <amount>
    Given I have 500 in my "cash" account
    And any "worm" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I stand beside the fishing shop keeper
    # kora_fishing/server/shops.lua:13
    And I expect a console error from "kora_fishing" containing "shops.lua:13: Invalid amount"
    When I ask the fishing shop to sell me <amount> of shop item 3
    Then my "cash" balance should be unchanged
    And I should have no "worm"

    Examples:
      | amount |
      | 0      |
      | -3     |

  @world @rejection
  Scenario: Fishing shop refuses a fractional amount
    Given I have 500 in my "cash" account
    And any "worm" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I stand beside the fishing shop keeper
    # kora_fishing/server/shops.lua:13
    And I expect a console error from "kora_fishing" containing "shops.lua:13: Invalid amount"
    When I ask the fishing shop to sell me a fractional 1.5 of shop item 3
    Then my "cash" balance should be unchanged
    And I should have no "worm"

  @world @rejection
  Scenario: Fishing shop refuses an amount sent as text
    Given I have 500 in my "cash" account
    And any "worm" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I stand beside the fishing shop keeper
    # kora_fishing/server/shops.lua:13
    And I expect a console error from "kora_fishing" containing "shops.lua:13: Invalid amount"
    When I ask the fishing shop to sell me the text amount "2" of shop item 3
    Then my "cash" balance should be unchanged
    And I should have no "worm"

  # Config.Shop.locations has one entry.
  @world @rejection
  Scenario: Fishing shop refuses an unknown shop
    Given I have 500 in my "cash" account
    And I remember my "cash" balance
    And I stand beside the fishing shop keeper
    # kora_fishing/server/shops.lua:14
    And I expect a console error from "kora_fishing" containing "Shop does not exist"
    When I ask fishing shop number 2 to sell me 1 of shop item 3
    Then my "cash" balance should be unchanged

  @world @rejection
  Scenario: Fishing shop refuses a request without a shop
    Given I have 500 in my "cash" account
    And I remember my "cash" balance
    And I stand beside the fishing shop keeper
    # kora_fishing/server/shops.lua:11
    And I expect a console error from "kora_fishing" containing "Invalid shop key"
    When I ask the fishing shop for shop item 3 without naming the shop
    Then my "cash" balance should be unchanged

  @world @rejection
  Scenario: Fishing shop refuses a request without an item
    Given I have 500 in my "cash" account
    And I remember my "cash" balance
    And I stand beside the fishing shop keeper
    # kora_fishing/server/shops.lua:12
    And I expect a console error from "kora_fishing" containing "Invalid item key"
    When I ask the fishing shop for nothing in particular
    Then my "cash" balance should be unchanged

  # server/shops.lua:21: 5.0 m from Config.Shop.locations[1].
  @world @rejection
  Scenario: Fishing shop refuses a buyer standing far away
    Given I have 500 in my "cash" account
    And any "worm" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I stand beside the fishing breakdown bench
    And I expect a console error from "kora_fishing" containing "You are too far from the shop"
    When I ask the fishing shop to sell me 1 of shop item 3
    Then my "cash" balance should be unchanged
    And I should have no "worm"

  # server/shops.lua: kora_fishing:client:confirmOpenShop gates the shop app.
  @world
  Scenario: Fishing shop agrees to open for a player beside the keeper
    Given I stand beside the fishing shop keeper
    When I ask whether fishing shop number 1 will open for me
    Then the fishing server should have answered yes

  @world @rejection
  Scenario: Fishing shop does not open for a player far away
    Given I stand beside the fishing breakdown bench
    # server callback assert: SCRIPT ERROR on kora_fishing, "handler ... errored" on kora_lib
    And I expect a console error from "kora_fishing" containing "You are too far from the shop"
    And I expect a console error from "kora_lib" containing "You are too far from the shop"
    When I ask whether fishing shop number 1 will open for me
    Then the fishing server should have refused with "You are too far from the shop"

  @world @rejection
  Scenario: Fishing shop does not open an unknown shop
    Given I stand beside the fishing shop keeper
    # server callback assert: SCRIPT ERROR on kora_fishing, "handler ... errored" on kora_lib
    And I expect a console error from "kora_fishing" containing "Shop does not exist"
    And I expect a console error from "kora_lib" containing "Shop does not exist"
    When I ask whether fishing shop number 2 will open for me
    Then the fishing server should have refused with "Shop does not exist"

  # ===========================================================================
  # Fishing shop app: client-side validation (client/shops.lua onAction)
  # ===========================================================================

  @world @ui @rejection
  Scenario: Fishing shop app rejects a negative amount
    Given I have 500 in my "cash" account
    And any "worm" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I face the fishing shop keeper
    When I target "Open Fishing Shop"
    Then the app "kora_fishing:shop" should be open
    When I trigger the app action "kora_fishing:purchase" with:
      """
      { "itemId": "shop:3", "value": { "amount": -2 } }
      """
    Then the app should answer with a "destructive" notice containing "Enter a valid amount."
    And my "cash" balance should be unchanged
    And I should have no "worm"

  @world @ui @rejection
  Scenario: Fishing shop app rejects an amount that is not a number
    Given I have 500 in my "cash" account
    And any "worm" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I face the fishing shop keeper
    When I target "Open Fishing Shop"
    Then the app "kora_fishing:shop" should be open
    When I trigger the app action "kora_fishing:purchase" with:
      """
      { "itemId": "shop:3", "value": { "amount": "lots" } }
      """
    Then the app should answer with a "destructive" notice containing "Enter a valid amount."
    And my "cash" balance should be unchanged
    And I should have no "worm"

  @world @ui @rejection
  Scenario: Fishing shop app rejects a purchase without an amount
    Given I have 500 in my "cash" account
    And any "worm" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I face the fishing shop keeper
    When I target "Open Fishing Shop"
    Then the app "kora_fishing:shop" should be open
    When I trigger the app action "kora_fishing:purchase" with:
      """
      { "itemId": "shop:3" }
      """
    Then the app should answer with a "destructive" notice containing "Enter a valid amount."
    And my "cash" balance should be unchanged
    And I should have no "worm"

  @world @ui @rejection
  Scenario: Fishing shop app rejects a malformed item id
    Given I have 500 in my "cash" account
    And I remember my "cash" balance
    And I face the fishing shop keeper
    When I target "Open Fishing Shop"
    Then the app "kora_fishing:shop" should be open
    When I trigger the app action "kora_fishing:purchase" with:
      """
      { "itemId": "worm", "value": { "amount": 1 } }
      """
    Then the app should answer with a "destructive" notice containing "Enter a valid amount."
    And my "cash" balance should be unchanged

  # The app passes 1.5 on (it only checks > 0); the server's integer check refuses it.
  @world @ui @rejection
  Scenario: Fishing shop app forwards a fractional amount and the server refuses it
    Given I have 500 in my "cash" account
    And any "worm" bought from the fishing shop is handed back afterwards
    And I remember my "cash" balance
    And I face the fishing shop keeper
    When I target "Open Fishing Shop"
    Then the app "kora_fishing:shop" should be open
    # kora_fishing/server/shops.lua:13
    And I expect a console error from "kora_fishing" containing "shops.lua:13: Invalid amount"
    When I trigger the app action "kora_fishing:purchase" with:
      """
      { "itemId": "shop:3", "value": { "amount": 1.5 } }
      """
    Then my "cash" balance should be unchanged
    And I should have no "worm"

  @world @ui @rejection
  Scenario: Fishing shop app has no sell action
    Given I face the fishing shop keeper
    When I target "Open Fishing Shop"
    Then the app "kora_fishing:shop" should be open
    And the app action "kora_fishing:sell" should be unavailable

  # ===========================================================================
  # Fish buyer: server rules (server/sales.lua sellItem)
  # ===========================================================================

  # Config.Locations.buyer.items, in order.
  @world
  Scenario Outline: Fish buyer pays <price> for each <fish>
    Given I hold 2 "<fish>"
    And I remember my "cash" balance
    And I stand beside the fish buyer
    When I ask the fish buyer to buy 2 of buyer item <index>
    Then I should have no "<fish>"
    And my "cash" balance should have increased by <total>
    And a money change should have been recorded for "cash"

    Examples:
      | index | fish       | price | total |
      | 1     | flounder   | 15    | 30    |
      | 2     | reddrum    | 15    | 30    |
      | 3     | tuna       | 15    | 30    |
      | 4     | steelhead  | 30    | 60    |
      | 5     | blue_fish  | 30    | 60    |
      | 6     | halibut    | 30    | 60    |
      | 7     | catfish    | 50    | 100   |
      | 8     | white_bass | 50    | 100   |
      | 9     | salmon     | 50    | 100   |
      | 10    | trout      | 60    | 120   |
      | 11    | bass       | 60    | 120   |

  @world
  Scenario: Fish buyer takes only the number of fish asked for
    Given I hold 3 "flounder"
    And I remember my "cash" balance
    And I remember how many "flounder" I have
    And I stand beside the fish buyer
    When I ask the fish buyer to buy 1 of buyer item 1
    Then I should have 1 fewer "flounder" than before
    And my "cash" balance should have increased by 15

  @world @rejection
  Scenario: Fish buyer pays nothing for a listed fish the seller does not hold
    Given I hold 2 "flounder"
    And I should have no "reddrum"
    And I remember my "cash" balance
    And I remember how many "flounder" I have
    And I stand beside the fish buyer
    When I ask the fish buyer to buy 1 of buyer item 2
    Then my "cash" balance should be unchanged
    And I should have 0 fewer "flounder" than before

  # Two requests in the same frame for the only two fish: one is paid.
  @world
  Scenario: A doubled sell request to the fish buyer pays once
    Given I hold 2 "flounder"
    And I remember my "cash" balance
    And I stand beside the fish buyer
    When I ask the fish buyer twice at once to buy 2 of buyer item 1
    Then I should have no "flounder"
    And my "cash" balance should have increased by 30

  @world @rejection
  Scenario Outline: Fish buyer refuses buyer item <index> as unknown
    Given I hold 1 "flounder"
    And I remember my "cash" balance
    And I remember how many "flounder" I have
    And I stand beside the fish buyer
    # kora_fishing/server/sales.lua:16
    And I expect a console error from "kora_fishing" containing "sales.lua:16: Invalid item"
    When I ask the fish buyer to buy 1 of buyer item <index>
    Then my "cash" balance should be unchanged
    And I should have 0 fewer "flounder" than before

    Examples:
      | index |
      | 0     |
      | 12    |
      | 99    |

  @world @rejection
  Scenario Outline: Fish buyer refuses an amount of <amount>
    Given I hold 2 "flounder"
    And I remember my "cash" balance
    And I remember how many "flounder" I have
    And I stand beside the fish buyer
    # kora_fishing/server/sales.lua:12
    And I expect a console error from "kora_fishing" containing "sales.lua:12: Invalid amount"
    When I ask the fish buyer to buy <amount> of buyer item 1
    Then my "cash" balance should be unchanged
    And I should have 0 fewer "flounder" than before

    Examples:
      | amount |
      | 0      |
      | -1     |

  @world @rejection
  Scenario: Fish buyer refuses a fractional amount
    Given I hold 2 "flounder"
    And I remember my "cash" balance
    And I remember how many "flounder" I have
    And I stand beside the fish buyer
    # kora_fishing/server/sales.lua:12
    And I expect a console error from "kora_fishing" containing "sales.lua:12: Invalid amount"
    When I ask the fish buyer to buy a fractional 1.5 of buyer item 1
    Then my "cash" balance should be unchanged
    And I should have 0 fewer "flounder" than before

  @world @rejection
  Scenario: Fish buyer refuses an amount sent as text
    Given I hold 2 "flounder"
    And I remember my "cash" balance
    And I remember how many "flounder" I have
    And I stand beside the fish buyer
    # kora_fishing/server/sales.lua:12
    And I expect a console error from "kora_fishing" containing "sales.lua:12: Invalid amount"
    When I ask the fish buyer to buy the text amount "2" of buyer item 1
    Then my "cash" balance should be unchanged
    And I should have 0 fewer "flounder" than before

  @world @rejection
  Scenario: Fish buyer refuses a sale without an amount
    Given I hold 1 "flounder"
    And I remember my "cash" balance
    And I stand beside the fish buyer
    # kora_fishing/server/sales.lua:11
    And I expect a console error from "kora_fishing" containing "Invalid parameters"
    When I ask the fish buyer to buy buyer item 1 without an amount
    Then my "cash" balance should be unchanged
    And I should have 1 "flounder"

  @world @rejection
  Scenario: Fish buyer refuses an unknown buyer location
    Given I hold 1 "flounder"
    And I remember my "cash" balance
    And I stand beside the fish buyer
    # kora_fishing/server/sales.lua:13
    And I expect a console error from "kora_fishing" containing "Invalid buyer location key"
    When I ask fish buyer location 2 to buy 1 of buyer item 1
    Then my "cash" balance should be unchanged
    And I should have 1 "flounder"

  # server/sales.lua:14: 5 m from Config.Locations.buyer.locations[1].
  @world @rejection
  Scenario: Fish buyer refuses a seller standing far away
    Given I hold 1 "flounder"
    And I remember my "cash" balance
    And I stand beside the fishing breakdown bench
    And I expect a console error from "kora_fishing" containing "Player is too far from the buyer location"
    When I ask the fish buyer to buy 1 of buyer item 1
    Then my "cash" balance should be unchanged
    And I should have 1 "flounder"

  # server/sales.lua: kora_fishing:server:canOpenBuyerMenu gates the buyer app.
  @world
  Scenario: Fish buyer agrees to open for a player beside them
    Given I stand beside the fish buyer
    When I ask whether fish buyer location 1 will open for me
    Then the fishing server should have answered yes

  @world @rejection
  Scenario: Fish buyer does not open for a player far away
    Given I stand beside the fishing breakdown bench
    # server callback assert: SCRIPT ERROR on kora_fishing, "handler ... errored" on kora_lib
    And I expect a console error from "kora_fishing" containing "Player is too far from the buyer location"
    And I expect a console error from "kora_lib" containing "Player is too far from the buyer location"
    When I ask whether fish buyer location 1 will open for me
    Then the fishing server should have refused with "Player is too far from the buyer location"

  @world @rejection
  Scenario: Fish buyer does not open an unknown buyer location
    Given I stand beside the fish buyer
    # server callback assert: SCRIPT ERROR on kora_fishing, "handler ... errored" on kora_lib
    And I expect a console error from "kora_fishing" containing "Invalid buyer location key"
    And I expect a console error from "kora_lib" containing "Invalid buyer location key"
    When I ask whether fish buyer location 2 will open for me
    Then the fishing server should have refused with "Invalid buyer location key"

  # ===========================================================================
  # Salvage breakdown: server rules (server/breakdown.lua refineItem)
  # ===========================================================================

  # Config.Locations.breakdown.items: rank rolls of receiveAmounts 4-10 each.
  @world
  Scenario Outline: Breakdown bench refines <item> of rank <rank>
    Given I hold 1 "<item>"
    And I note my crafting materials before refining fishing salvage
    And I stand beside the fishing breakdown bench
    When I ask the fishing bench to refine salvage entry <index>
    Then I should have no "<item>"
    And refining fishing salvage should have paid between <low> and <high> crafting materials

    Examples:
      | index | item              | rank | low | high |
      | 1     | rusty_usb         | 1    | 4   | 10   |
      | 2     | rusty_motherboard | 1    | 4   | 10   |
      | 3     | rusty_scanner     | 1    | 4   | 10   |
      | 4     | rusty_antenna     | 1    | 4   | 10   |
      | 5     | copper_pipe       | 1    | 4   | 10   |
      | 6     | rusty_scrap_metal | 1    | 4   | 10   |
      | 7     | rusty_pistol      | 1    | 4   | 10   |
      | 8     | rusty_sign        | 2    | 8   | 20   |
      | 9     | rusty_chain       | 2    | 8   | 20   |
      | 10    | rusty_tire        | 2    | 8   | 20   |
      | 11    | rusty_box         | 2    | 8   | 20   |
      | 12    | rusty_shotgun     | 3    | 12  | 30   |
      | 13    | rusty_ak          | 3    | 12  | 30   |
      | 14    | rusty_bike        | 3    | 12  | 30   |
      | 15    | rusty_wheelchair  | 3    | 12  | 30   |
      | 16    | closed_safe       | 4    | 16  | 40   |

  @world
  Scenario: Breakdown bench refines one piece of salvage per request
    Given I hold 2 "rusty_usb"
    And I remember how many "rusty_usb" I have
    And I note my crafting materials before refining fishing salvage
    And I stand beside the fishing breakdown bench
    When I ask the fishing bench to refine salvage entry 1
    Then I should have 1 fewer "rusty_usb" than before
    And refining fishing salvage should have paid between 4 and 10 crafting materials

  @world @rejection
  Scenario: Breakdown bench pays nothing for salvage the player does not hold
    Given I hold 1 "rusty_usb"
    And I should have no "closed_safe"
    And I remember how many "rusty_usb" I have
    And I note my crafting materials before refining fishing salvage
    And I stand beside the fishing breakdown bench
    When I ask the fishing bench to refine salvage entry 16
    Then refining fishing salvage should have paid nothing
    And I should have 0 fewer "rusty_usb" than before

  @world @rejection
  Scenario Outline: Breakdown bench refuses salvage entry <index> as unknown
    Given I hold 1 "rusty_usb"
    And I remember how many "rusty_usb" I have
    And I note my crafting materials before refining fishing salvage
    And I stand beside the fishing breakdown bench
    # kora_fishing/server/breakdown.lua:16
    And I expect a console error from "kora_fishing" containing "breakdown.lua:16: Invalid item"
    When I ask the fishing bench to refine salvage entry <index>
    Then refining fishing salvage should have paid nothing
    And I should have 0 fewer "rusty_usb" than before

    Examples:
      | index |
      | 0     |
      | 17    |
      | 99    |

  @world @rejection
  Scenario: Breakdown bench refuses a request that names no salvage
    Given I hold 1 "rusty_usb"
    And I note my crafting materials before refining fishing salvage
    And I stand beside the fishing breakdown bench
    # kora_fishing/server/breakdown.lua:11
    And I expect a console error from "kora_fishing" containing "Invalid parameters"
    When I ask the fishing bench to refine without naming the salvage
    Then refining fishing salvage should have paid nothing
    And I should have 1 "rusty_usb"

  @world @rejection
  Scenario: Breakdown bench refuses an unknown breakdown location
    Given I hold 1 "rusty_usb"
    And I note my crafting materials before refining fishing salvage
    And I stand beside the fishing breakdown bench
    # kora_fishing/server/breakdown.lua:12
    And I expect a console error from "kora_fishing" containing "Invalid breakdown location key"
    When I ask fishing breakdown location 2 to refine salvage entry 1
    Then refining fishing salvage should have paid nothing
    And I should have 1 "rusty_usb"

  # server/breakdown.lua:13: 5 m from Config.Locations.breakdown.locations[1].
  @world @rejection
  Scenario: Breakdown bench refuses a player standing far away
    Given I hold 1 "rusty_usb"
    And I note my crafting materials before refining fishing salvage
    And I stand beside the fish buyer
    And I expect a console error from "kora_fishing" containing "Player is too far from the breakdown location"
    When I ask the fishing bench to refine salvage entry 1
    Then refining fishing salvage should have paid nothing
    And I should have 1 "rusty_usb"

  # server/breakdown.lua: kora_fishing:server:openRefineMenu gates the refine app.
  @world
  Scenario: Breakdown bench agrees to open for a player beside it
    Given I stand beside the fishing breakdown bench
    When I ask whether fishing breakdown location 1 will open for me
    Then the fishing server should have answered yes

  @world @rejection
  Scenario: Breakdown bench does not open for a player far away
    Given I stand beside the fish buyer
    # server callback assert: SCRIPT ERROR on kora_fishing, "handler ... errored" on kora_lib
    And I expect a console error from "kora_fishing" containing "Player is too far from the breakdown location"
    And I expect a console error from "kora_lib" containing "Player is too far from the breakdown location"
    When I ask whether fishing breakdown location 1 will open for me
    Then the fishing server should have refused with "Player is too far from the breakdown location"

  @world @rejection
  Scenario: Breakdown bench does not open an unknown breakdown location
    Given I stand beside the fishing breakdown bench
    # server callback assert: SCRIPT ERROR on kora_fishing, "handler ... errored" on kora_lib
    And I expect a console error from "kora_fishing" containing "Invalid breakdown location key"
    And I expect a console error from "kora_lib" containing "Invalid breakdown location key"
    When I ask whether fishing breakdown location 2 will open for me
    Then the fishing server should have refused with "Invalid breakdown location key"

  # client/breakdown.lua: the refine progress bar has canCancel = true; a
  # cancelled bar sends nothing to the server.
  @world @ui
  Scenario: Cancelling the refine progress bar keeps the salvage
    Given I hold 1 "rusty_usb"
    And I remember how many "rusty_usb" I have
    And I note my crafting materials before refining fishing salvage
    And I face the fishing breakdown bench
    When I target "Open Refine Menu"
    Then the app "kora_fishing:breakdown" should be open
    When I start refining the fishing salvage entry "refine:1" and cancel it midway
    Then no progress bar should be running
    And I should have 0 fewer "rusty_usb" than before
    And refining fishing salvage should have paid nothing

  @world @rejection
  Scenario: Breakdown bench turns away a player holding only items it cannot refine
    Given I hold 1 "flounder"
    And I should have no "rusty_usb"
    And I note my crafting materials before refining fishing salvage
    And I face the fishing breakdown bench
    When I target "Open Refine Menu"
    Then I should see a notification containing "You do not have any items to refine."
    And no app should be open
    And refining fishing salvage should have paid nothing

  @world @rejection
  Scenario: Fish buyer turns away a player holding only salvage
    Given I hold 1 "rusty_usb"
    And I should have no "flounder"
    And I remember my "cash" balance
    And I face the fish buyer
    When I target "Open Buyer Menu"
    Then I should see a notification containing "You do not have any items to sell."
    And no app should be open
    And my "cash" balance should be unchanged

  # ===========================================================================
  # Poles and zones (server/server.lua usable, client/fishing.lua zones)
  # ===========================================================================

  # Config.zones[1] "Sandy Bay Dock".
  @world @ui
  Scenario: Entering a fishing zone with a pole says the pole can be used
    Given I hold 1 "fishing_pole"
    When I stand on the Sandy Bay fishing dock
    Then I should see a notification containing "You can use your fishing pole here"

  @world @ui
  Scenario: Entering a fishing zone without a pole says nothing
    Given I should have no "fishing_pole"
    And I should have no "magnet_pole"
    When I stand on the Sandy Bay fishing dock
    Then I should not see a notification containing "You can use your fishing pole here"

  @world @ui
  Scenario: Leaving a fishing zone with a pole says so
    Given I hold 1 "fishing_pole"
    And I stand on the Sandy Bay fishing dock
    And I should see a notification containing "You can use your fishing pole here"
    When I stand beside the fishing breakdown bench
    Then I should see a notification containing "You have left the fishing zone"

  # Without bait the server refuses the first catch (beginCatch) and the client
  # ends the cast, so no minigame starts.
  @world @ui @rejection
  Scenario Outline: Casting a <pole> without bait in a zone ends the cast
    Given I hold 1 "<pole>"
    And I carry no bait for any fishing pole
    And I stand on the Sandy Bay fishing dock
    And I should see a notification containing "You can use your fishing pole here"
    When I use my fishing pole "<pole>"
    Then I should see a notification containing "You have no usable bait for this pole."
    And the fishing server should no longer have me fishing
    And I should have 1 "<pole>"

    Examples:
      | pole         |
      | fishing_pole |
      | magnet_pole  |

  # Two uses in the same server frame: the second finds the first cast active
  # and reels in before the client could start a catch.
  @world @ui
  Scenario: Using the pole again straight away reels the line in
    Given I hold 1 "fishing_pole"
    And I carry no bait for any fishing pole
    And I stand on the Sandy Bay fishing dock
    And I should see a notification containing "You can use your fishing pole here"
    When I use my fishing pole "fishing_pole" twice at once
    Then I should see a notification containing "You reel in your line."
    And the fishing server should no longer have me fishing

  # server/server.lua startCooldown: 2000 ms after a cast starts.
  @world @ui @rejection
  Scenario: A third use inside the cast cooldown is refused
    Given I hold 1 "fishing_pole"
    And I carry no bait for any fishing pole
    And I stand on the Sandy Bay fishing dock
    And I should see a notification containing "You can use your fishing pole here"
    When I use my fishing pole "fishing_pole" three times at once
    Then I should see a notification containing "You must wait before fishing again."
    And the fishing server should no longer have me fishing

  @rejection
  Scenario: The server will not begin a catch for a player who is not fishing
    When I ask the fishing server to begin a catch
    Then the fishing server should have answered no with "You are not currently fishing."

  # server/server.lua beginCatch: rateLimit max 2 per 1000 ms.
  @rejection
  Scenario: Catch requests are rate limited
    When I ask the fishing server to begin a catch 3 times at once
    Then at least one catch request should have been refused with "Callback rate limit exceeded"

  # A catch without a pending beginCatch authorization is ignored.
  @rejection
  Scenario: A forged catch pays no fish and no Fishing XP
    Given I note my fishing catch and Fishing XP
    When I send a forged fishing catch
    Then I wait 1000 milliseconds
    And my fishing catch and Fishing XP should be unchanged

  # ===========================================================================
  # Catalog (client/client_catalog.lua)
  # ===========================================================================

  @ui
  Scenario: Fish catalog command opens the catalog
    When I run the command "fishcatalog"
    Then the app "qb-fishing:catalog" should be open
    When I close the app
    Then no app should be open

  # openFishingCatalog returns early when the catalog is already open.
  @ui
  Scenario: Running the fish catalog command twice keeps one catalog open
    When I run the command "fishcatalog"
    Then the app "qb-fishing:catalog" should be open
    When I run the command "fishcatalog"
    Then the app "qb-fishing:catalog" should be open
    When I close the app
    Then no app should be open
