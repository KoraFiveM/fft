@kora @kora_inventory
Feature: kora_inventory exports, inventory screen and the 24/7 shop
  The server exports are called for the test character only. Slots are never
  hard-coded: the character may already hold a physical cash stack, so every
  slot is looked up through getItemByName or getFreeSlot first.

  The shop scenarios use the 24/7 convenience shop (id `convenience`) at the
  Senora Fwy counter, which has no clerk ped, so the counter target zone offers
  "Open shop (24/7)" itself. The scenarios that expect "access denied" assume
  the character does not already stand within 2.25 m of a 24/7 counter.

  The one successful purchase is tagged @global: shop stock is finite, shared
  by every player and saved, and no safe export puts a sold item back, so each
  run sells one coffee out of the shop's 40.

  Not covered, on purpose: stashes and temporary stashes (created lazily and
  durably, with no export to delete them), drops (a world bag broadcast to
  every client), shopSet and registerShop, registering use handlers, give,
  hooks, inspection access and vehicle storage. clearInventory and setItems
  are covered because they only touch the test character, whose items the
  runner resets anyway. The handcuffed scenarios set the boolean
  `ishandcuffed` metadata that kora_police writes, and restore it afterwards.

  Background:
    Given resource "kora_inventory" is running

  @server
  Scenario: Adding and removing an item moves the count
    When the inventory gives me 3 "water_bottle"
    Then the inventory should count 3 "water_bottle" on me
    And I should have 3 "water_bottle"
    When the inventory takes 2 "water_bottle" from me
    Then the inventory should count 1 "water_bottle" on me
    When the inventory takes 1 "water_bottle" from the slot holding it
    Then the inventory should find no "water_bottle" by name

  @server @rejection
  Scenario: An unknown item cannot be added
    Then the inventory should refuse to give me 1 "fft_no_such_item" with "unknown item"
    And the inventory should find no "fft_no_such_item" by name

  @server @rejection
  Scenario: More than the carry weight cannot be added
    Given I remember my inventory weight
    Then the inventory should refuse to give me 100000 "water_bottle" with "over weight"
    And the inventory should find no "water_bottle" by name
    And my inventory weight should have increased by 0

  @server @rejection
  Scenario Outline: Invalid removals are refused and leave the stack alone
    Given the inventory gives me 2 "water_bottle"
    Then the inventory should refuse to take <amount> "<item>" from me with "<reason>"
    And the inventory should count 2 "water_bottle" on me

    Examples:
      | amount | item             | reason             |
      | 3      | water_bottle     | not enough of item |
      | 1      | coffee           | not enough of item |
      | 0      | water_bottle     | invalid amount     |
      | -1     | water_bottle     | invalid amount     |

  @server @rejection
  Scenario: Removing from a slot that holds a different item is refused
    Given the inventory gives me 2 "water_bottle"
    And the inventory gives me 1 "coffee"
    Then the inventory should refuse to take 1 "coffee" from the slot holding "water_bottle" with "item not in slot"
    And the inventory should count 2 "water_bottle" on me
    And the inventory should count 1 "coffee" on me

  @server
  Scenario: Items can be looked up by name, by slot and in any letter case
    Given the inventory gives me 4 "water_bottle"
    And the inventory gives me 2 "coffee"
    Then the inventory should find 4 "water_bottle" by name and by slot
    And the inventory should find 2 "coffee" by name and by slot
    And the inventory should find "water_bottle" when asked for "WATER_BOTTLE"
    And the inventory should count 6 across "water_bottle" and "coffee"
    And the inventory should count 4 across "water_bottle" and "fft_no_such_item"
    And the inventory should find no "lockpick" by name

  @server
  Scenario: hasItem accepts a name, a list and a count map
    Given the inventory gives me 3 "water_bottle"
    And the inventory gives me 1 "coffee"
    Then the inventory should confirm I have 1 "water_bottle"
    And the inventory should confirm I have 3 "water_bottle"
    And the inventory should confirm I have everything in:
      """
      ["water_bottle", "coffee"]
      """
    And the inventory should confirm I have everything in:
      """
      { "water_bottle": 3, "coffee": 1 }
      """

  @server @rejection
  Scenario: hasItem is false when any requested item or amount is missing
    Given the inventory gives me 3 "water_bottle"
    And the inventory gives me 1 "coffee"
    Then the inventory should deny I have 4 "water_bottle"
    And the inventory should deny I have 1 "lockpick"
    And the inventory should deny I have everything in:
      """
      ["water_bottle", "lockpick"]
      """
    And the inventory should deny I have everything in:
      """
      { "water_bottle": 3, "coffee": 2 }
      """
    And the inventory should deny I have 2 of everything in:
      """
      ["water_bottle", "coffee"]
      """
    But the inventory should confirm I have 1 of everything in:
      """
      ["water_bottle", "coffee"]
      """

  @server
  Scenario: Weight follows what is carried
    Given I remember my inventory weight
    Then my inventory weight limit should be 120000
    When the inventory gives me 2 "water_bottle"
    Then my inventory weight should have increased by 1000
    When the inventory gives me 1 "coffee"
    Then my inventory weight should have increased by 1200

  @server
  Scenario: canCarry answers without changing the inventory
    Given I remember my inventory weight
    Then the inventory should say I can carry 5 "water_bottle"
    And the inventory should say I cannot carry 100000 "water_bottle" because "over weight"
    And the inventory should say I cannot carry 1 "fft_no_such_item" because "unknown item"
    And the inventory should say I cannot carry 0 "water_bottle" because "unknown item"
    And the inventory should find no "water_bottle" by name
    And my inventory weight should have increased by 0

  @server
  Scenario: An item can be moved to a free slot
    Given the inventory gives me 2 "water_bottle"
    Then the inventory free slot should be an empty slot
    When the inventory moves my "water_bottle" to a free slot
    Then my "water_bottle" should now sit in the slot it was moved to
    And the inventory should count 2 "water_bottle" on me

  @server @rejection
  Scenario: Invalid moves are refused and leave both slots alone
    Given the inventory gives me 2 "water_bottle"
    And the inventory gives me 1 "coffee"
    Then the inventory should refuse to move an empty slot with "empty source slot"
    And the inventory should refuse to move my "water_bottle" to slot 0 with "invalid move"
    And the inventory should refuse to move my "water_bottle" to slot 42 with "invalid move"
    And the inventory should refuse to move 3 of my "water_bottle" to a free slot with "invalid move"
    And the inventory should refuse to move my "water_bottle" onto my "coffee" with "destination occupied"
    And the inventory should count 2 "water_bottle" on me
    And the inventory should count 1 "coffee" on me

  Scenario: The client HasItem export follows the server inventory
    Then my client inventory should report I lack 1 "water_bottle"
    When the inventory gives me 2 "water_bottle"
    Then my client inventory should report I have 2 "water_bottle"
    And my client inventory should report I lack 3 "water_bottle"
    And my client inventory should report I have everything in:
      """
      { "water_bottle": 2 }
      """
    And my client inventory should report I lack something in:
      """
      ["water_bottle", "lockpick"]
      """
    When the inventory takes 2 "water_bottle" from me
    Then my client inventory should report I lack 1 "water_bottle"

  @ui
  Scenario: The inventory command opens my own inventory and closeInv closes it
    When I run the command "inventory"
    Then my inventory screen should open on my own inventory
    When I run the command "closeInv"
    Then my inventory screen should be closed

  @server
  Scenario: The convenience shop lists its stock with prices
    Then the inventory shop "convenience" should stock "water_bottle" priced at 8
    And the inventory shop "convenience" should stock "coffee" priced at 7
    And the inventory shop "convenience" should stock "sandwich" priced at 18

  @server @rejection
  Scenario: An unknown shop cannot be read or bought from
    Given I remember my "cash" balance
    And inventory purchase receipts are being recorded
    Then the inventory should know no shop called "fft_no_such_shop"
    And the inventory should refuse to sell me slot 1 of shop "fft_no_such_shop" with "shop not found"
    And no inventory purchase receipt should exist
    And my "cash" balance should be unchanged

  @server @rejection
  Scenario: A shop refuses a purchase from someone who is not at its counter
    Given I have 0 in my "cash" account
    And inventory purchase receipts are being recorded
    Then the inventory should refuse to sell me slot 1 of shop "convenience" with "access denied"
    And no inventory purchase receipt should exist
    And the inventory should find no "water_bottle" by name

  @ui @rejection
  Scenario: Asking to open a shop away from its counter opens nothing
    When I ask to open the inventory shop "convenience"
    Then my inventory screen should stay closed

  @world @rejection
  Scenario: A shop refuses a purchase the buyer cannot afford
    Given I have 0 in my "cash" account
    And I remember my "cash" balance
    And inventory purchase receipts are being recorded
    And I stand at 2678.07 3279.35 55.24 facing 330.0
    Then the inventory should refuse to sell me slot 1 of shop "convenience" with "insufficient funds"
    And no inventory purchase receipt should exist
    And the inventory should find no "water_bottle" by name
    And my "cash" balance should be unchanged

  @ui @world @global
  Scenario: Buying a coffee at the 24/7 counter through the shop UI
    Given I have 50 in my "cash" account
    And I remember my "cash" balance
    And I remember how many "coffee" I have
    And inventory purchase receipts are being recorded
    And I stand at 2678.07 3279.35 55.24 facing 330.0
    And I aim at 2678.57 3280.22 54.34
    When I target "Open shop (24/7)"
    Then my inventory screen should open on a shop
    When I buy 1 "coffee" through the inventory UI
    Then an inventory purchase receipt should record 1 "coffee" from "convenience" for 7
    And I should have 1 more "coffee" than before
    And my "cash" balance should have decreased by 7

  @ui @world @rejection
  Scenario: The shop UI cannot buy a coffee without cash
    Given I have 0 in my "cash" account
    And I remember my "cash" balance
    And I remember how many "coffee" I have
    And inventory purchase receipts are being recorded
    And I stand at 2678.07 3279.35 55.24 facing 330.0
    And I aim at 2678.57 3280.22 54.34
    When I target "Open shop (24/7)"
    Then my inventory screen should open on a shop
    When I try to drag "coffee" out of the shop
    Then no inventory purchase receipt should exist
    And I should have 0 more "coffee" than before
    And my "cash" balance should be unchanged

  # ---------------------------------------------------------------------------
  # addItem: amounts and explicit slots
  # ---------------------------------------------------------------------------

  @server
  Scenario: Adding without an amount gives exactly one
    When the inventory gives me one "water_bottle" without saying how many
    Then the inventory should count 1 "water_bottle" on me

  @server
  Scenario: A fractional amount is rounded down
    When the inventory gives me 2.7 "water_bottle" as a fractional amount
    Then the inventory should count 2 "water_bottle" on me

  @server @rejection
  Scenario Outline: A non-positive amount cannot be added or carried
    Given I remember my inventory weight
    Then the inventory should refuse to give me <amount> "water_bottle" for any reason
    And the inventory should say I cannot carry <amount> "water_bottle" because "unknown item"
    And the inventory should find no "water_bottle" by name
    And my inventory weight should have increased by 0

    Examples:
      | amount |
      | 0      |
      | -3     |

  @server
  Scenario: An item can be given straight into a chosen free slot
    When the inventory gives me 2 "coffee" into the first free slot
    Then my "coffee" should sit in the slot it was given into
    And the inventory should count 2 "coffee" on me

  @server @rejection
  Scenario Outline: An item cannot be given into a slot that does not exist
    Given I remember my inventory weight
    Then the inventory should refuse to give me 1 "water_bottle" into slot <slot> with "invalid slot"
    And the inventory should find no "water_bottle" by name
    And my inventory weight should have increased by 0

    Examples:
      | slot |
      | 0    |
      | 42   |

  @server @rejection
  Scenario: An item cannot be given into a slot that holds a different item
    Given the inventory gives me 2 "water_bottle"
    Then the inventory should refuse to give me 1 "coffee" into the slot holding "water_bottle" with "no free slot"
    And the inventory should find no "coffee" by name
    And the inventory should find 2 "water_bottle" by name and by slot

  @server
  Scenario: Giving the same item again tops up the existing stack
    Given the inventory gives me 2 "water_bottle"
    When the inventory gives me 3 "water_bottle"
    Then the inventory should keep all my "water_bottle" in one slot
    When the inventory gives me 1 more "water_bottle" into the slot holding it
    Then the inventory should find 6 "water_bottle" by name and by slot

  # ---------------------------------------------------------------------------
  # Unique items, weapons and stackable throwables
  # ---------------------------------------------------------------------------

  @server
  Scenario: Unique items are spread over one slot each
    Given I remember my inventory weight
    When the inventory gives me 3 "radio"
    Then the inventory should keep my "radio" in 3 separate slots of one each
    And the inventory should count 3 "radio" on me
    And my inventory weight should have increased by 6000

  @server @rejection
  Scenario: More unique items than free slots cannot be carried or added
    Then the inventory should say I cannot carry 42 "radio" because "no free slot"
    And the inventory should refuse to give me 42 "radio" with "no free slot"
    And the inventory should find no "radio" by name

  @server
  Scenario: Every weapon added gets its own server serial
    When the inventory gives me 2 "weapon_knife"
    Then the inventory should keep my "weapon_knife" in 2 separate slots of one each
    And every "weapon_knife" I hold should carry its own weapon serial

  @server
  Scenario: A throwable listed as stackable shares one slot
    When the inventory gives me 3 "weapon_grenade"
    Then the inventory should find 3 "weapon_grenade" by name and by slot

  @server @rejection
  Scenario: Unique items cannot be stacked onto each other by moving
    Given the inventory gives me 2 "radio"
    Then the inventory should refuse to move one "radio" onto another with "destination occupied"
    And the inventory should keep my "radio" in 2 separate slots of one each

  # ---------------------------------------------------------------------------
  # removeItem through a slot and across stacks
  # ---------------------------------------------------------------------------

  @server @rejection
  Scenario: Taking more from a slot than it holds is refused
    Given the inventory gives me 3 "water_bottle"
    Then the inventory should refuse to take 4 "water_bottle" from the slot holding it with "not enough of item"
    And the inventory should count 3 "water_bottle" on me

  @server
  Scenario: A removal without a slot takes from several stacks
    Given the inventory gives me 4 "water_bottle"
    And the inventory splits 1 of my "water_bottle" into a free slot
    When the inventory takes 3 "water_bottle" from me
    Then the inventory should count 1 "water_bottle" on me
    When the inventory takes 1 "water_bottle" from me
    Then the inventory should find no "water_bottle" by name

  # ---------------------------------------------------------------------------
  # moveItem: split, merge, no-op and the last slot
  # ---------------------------------------------------------------------------

  @server
  Scenario: Part of a stack can be split off and merged back
    Given the inventory gives me 5 "water_bottle"
    When the inventory splits 2 of my "water_bottle" into a free slot
    Then my split "water_bottle" should hold 2 in the new slot and 3 in the old one
    And the inventory should count 5 "water_bottle" on me
    When the inventory merges my split "water_bottle" back onto its original stack
    Then the inventory should keep all my "water_bottle" in one slot
    And the inventory should find 5 "water_bottle" by name and by slot

  @server
  Scenario: Moving an item onto its own slot changes nothing
    Given the inventory gives me 2 "water_bottle"
    Then the inventory should accept moving my "water_bottle" onto its own slot
    And the inventory should find 2 "water_bottle" by name and by slot

  @server
  Scenario: The last player slot is usable
    Given the inventory gives me 2 "water_bottle"
    When the inventory moves my "water_bottle" to slot 41
    Then the inventory should find 2 "water_bottle" in slot 41

  # ---------------------------------------------------------------------------
  # Lookups, weight and the qb-style aliases
  # ---------------------------------------------------------------------------

  @server
  Scenario: Lookups of empty or impossible slots and names find nothing
    Then the inventory slot 0 should hold nothing of mine
    And the inventory slot 42 should hold nothing of mine
    And the inventory should count 0 for a numeric item name
    And the inventory should find no "fft_no_such_item" by name

  @server
  Scenario: hasItem ignores letter case in lists and count maps
    Given the inventory gives me 2 "water_bottle"
    Then the inventory should confirm I have 2 "WATER_BOTTLE"
    And the inventory should confirm I have everything in:
      """
      { "Water_Bottle": 2 }
      """
    And the inventory should confirm I have 2 of everything in:
      """
      ["WATER_BOTTLE"]
      """

  @server
  Scenario: Free weight is the limit minus what is carried
    Then my free inventory weight should be my weight limit minus my weight
    When the inventory gives me 4 "water_bottle"
    Then my free inventory weight should be my weight limit minus my weight

  @server
  Scenario: The qb-style export names act on the same inventory
    When the inventory gives me 3 "water_bottle" through the qb-style AddItem export
    Then the qb-style inventory exports should agree I hold 3 "water_bottle"
    And the inventory should count 3 "water_bottle" on me
    When the inventory takes 2 "water_bottle" from me through the qb-style RemoveItem export
    Then the qb-style inventory exports should agree I hold 1 "water_bottle"

  # ---------------------------------------------------------------------------
  # clearInventory and setItems (the test character only)
  # ---------------------------------------------------------------------------

  @server
  Scenario: clearInventory empties my inventory
    Given the inventory gives me 2 "water_bottle"
    And the inventory gives me 1 "coffee"
    When the inventory clears my items
    Then the inventory should find no "water_bottle" by name
    And the inventory should find no "coffee" by name

  @server
  Scenario: clearInventory keeps a named item
    Given the inventory gives me 2 "water_bottle"
    And the inventory gives me 1 "coffee"
    When the inventory clears my items except "coffee"
    Then the inventory should find no "water_bottle" by name
    And the inventory should count 1 "coffee" on me

  @server
  Scenario: clearInventory keeps every item in a list or a map
    Given the inventory gives me 2 "water_bottle"
    And the inventory gives me 1 "coffee"
    And the inventory gives me 1 "sandwich"
    When the inventory clears my items except everything in:
      """
      ["water_bottle", "coffee"]
      """
    Then the inventory should find no "sandwich" by name
    And the inventory should count 2 "water_bottle" on me
    When the inventory clears my items except everything in:
      """
      { "coffee": true }
      """
    Then the inventory should find no "water_bottle" by name
    And the inventory should count 1 "coffee" on me

  @server
  Scenario: setItems replaces my whole inventory
    Given the inventory gives me 2 "coffee"
    When the inventory replaces my items with:
      """
      { "5": { "name": "water_bottle", "amount": 3 } }
      """
    Then the inventory should find 3 "water_bottle" in slot 5
    And the inventory should find no "coffee" by name

  @server @rejection
  Scenario: setItems refuses a malformed or overweight replacement
    Given the inventory gives me 2 "coffee"
    Then the inventory should refuse to replace my items with something other than a table with "items must be a table"
    And the inventory should refuse to replace my items with "invalid item table" given:
      """
      { "1": { "name": "fft_no_such_item", "amount": 1 } }
      """
    And the inventory should refuse to replace my items with "invalid item table" given:
      """
      { "42": { "name": "water_bottle", "amount": 1 } }
      """
    And the inventory should refuse to replace my items with "invalid item table" given:
      """
      { "1": { "name": "water_bottle", "amount": 0 } }
      """
    And the inventory should refuse to replace my items with "over weight" given:
      """
      { "1": { "name": "water_bottle", "amount": 300 } }
      """
    And the inventory should count 2 "coffee" on me
    And the inventory should find no "water_bottle" by name

  # ---------------------------------------------------------------------------
  # useItem and the cuffed gate
  # ---------------------------------------------------------------------------

  @server @rejection
  Scenario: An item that is not held cannot be used
    Then the inventory should refuse to use my "plastic" with "item not found"

  @server @rejection
  Scenario: An item without a use handler is not consumed
    Given the inventory gives me 2 "plastic"
    Then the inventory should refuse to use my "plastic" with "no useable registered"
    And the inventory should count 2 "plastic" on me

  @server @ui @rejection
  Scenario: A handcuffed player cannot use items or open an inventory
    Given the inventory gives me 2 "plastic"
    And inventory sessions are being recorded
    And I am flagged as handcuffed for the inventory
    Then the inventory should refuse to use my "plastic" with "you cannot use items while cuffed"
    And the server should refuse to open my own inventory with "you cannot open inventories while cuffed"
    And no inventory session should have opened
    And the inventory should count 2 "plastic" on me

  @ui @rejection
  Scenario: The inventory command opens nothing while handcuffed
    Given I am flagged as handcuffed for the inventory
    When I run the command "inventory"
    Then my inventory screen should stay closed

  # ---------------------------------------------------------------------------
  # Server-opened sessions
  # ---------------------------------------------------------------------------

  @ui
  Scenario: The server can open and close my own inventory
    Given inventory sessions are being recorded
    When the server opens my own inventory
    Then an inventory session should have opened on my own inventory
    And my inventory screen should open on my own inventory
    When the server closes my inventory
    Then an inventory session should have closed because "requested"
    And my inventory screen should be closed
    And the server should find no inventory of mine to close

  @server @rejection
  Scenario: The server opens no shop that is unknown or out of reach
    Given inventory sessions are being recorded
    Then the server should refuse to open the inventory shop "fft_no_such_shop" with "inventory not found"
    And the server should refuse to open the inventory shop "convenience" with "access denied"
    And no inventory session should have opened

  @ui @rejection
  Scenario: Asking the client to open an unknown shop opens nothing
    When I ask to open the inventory shop "fft_no_such_shop"
    Then my inventory screen should stay closed

  @ui
  Scenario: The client openInventory export opens my own inventory and follows changes
    Given the inventory gives me 2 "water_bottle"
    When I ask the inventory to open my own inventory
    Then my inventory screen should open on my own inventory
    And my open inventory screen should list 2 "water_bottle"
    When the inventory gives me 3 "water_bottle"
    Then my open inventory screen should list 5 "water_bottle"
    When I run the command "closeInv"
    Then my inventory screen should be closed

  Scenario: The client HasItem export ignores letter case
    Given the inventory gives me 2 "water_bottle"
    Then my client inventory should report I have 2 "WATER_BOTTLE"
    And my client inventory should report I lack 3 "Water_Bottle"

  # ---------------------------------------------------------------------------
  # Audit trail
  # ---------------------------------------------------------------------------

  @server
  Scenario: Adds, removals and moves are audited for the character
    Given inventory audit records are being recorded
    When the inventory gives me 3 "water_bottle"
    Then an inventory audit record "add" should name 3 "water_bottle"
    When the inventory moves my "water_bottle" to a free slot
    Then an inventory move audit record should name 3 moved
    When the inventory takes 2 "water_bottle" from me
    Then an inventory audit record "remove" should name 2 "water_bottle"

  # ---------------------------------------------------------------------------
  # Other shops and BuyItem edge cases
  # ---------------------------------------------------------------------------

  @server
  Scenario Outline: Every configured shop lists its stock with prices
    Then the inventory shop "<shop>" should stock "<item>" priced at <price>

    Examples:
      | shop           | item         | price |
      | liquorstore    | beer         | 12    |
      | liquorstore    | whiskey      | 45    |
      | vendingmachine | water_bottle | 4     |
      | vendingmachine | soda         | 5     |
      | ammunation     | weapon_knife | 250   |

  @ui @world
  Scenario: The server opens the 24/7 shop for someone at its counter
    Given inventory sessions are being recorded
    And I stand at 2678.07 3279.35 55.24 facing 330.0
    When the server opens the inventory shop "convenience"
    Then my inventory screen should open on a shop
    When the server closes my inventory
    Then an inventory session should have closed because "requested"

  @world @rejection
  Scenario: The shop refuses an empty slot, a zero count or more than it stocks
    Given I have 50 in my "cash" account
    And I remember my "cash" balance
    And inventory purchase receipts are being recorded
    And I stand at 2678.07 3279.35 55.24 facing 330.0
    Then the inventory should refuse to sell me 1 from slot 16 of shop "convenience" with "out of stock"
    And the inventory should refuse to sell me 0 from slot 1 of shop "convenience" with "out of stock"
    And the inventory should refuse to sell me 100000 from slot 1 of shop "convenience" with "out of stock"
    And no inventory purchase receipt should exist
    And the inventory should find no "water_bottle" by name
    And my "cash" balance should be unchanged

  # Crafting exports (kora_inventory/server/crafting.lua). Recipes and hooks are
  # owned by fft and removed in cleanup. water_bottle and coffee are real items.

  @server
  Scenario: A craft recipe is registered and reads back exactly as defined
    Given I register the craft recipe "fft_test_coffee" turning 2 "water_bottle" into 1 "coffee"
    Then the craft recipe "fft_test_coffee" should read back 2 "water_bottle" into 1 "coffee"

  @server
  Scenario: Registering a recipe again replaces my own definition
    Given I register the craft recipe "fft_test_replace" turning 1 "water_bottle" into 1 "coffee"
    When I register the craft recipe "fft_test_replace" turning 1 "water_bottle" into 2 "coffee"
    Then the craft recipe "fft_test_replace" should read back 1 "water_bottle" into 2 "coffee"

  @server @rejection
  Scenario Outline: A craft recipe with a bad id or item is refused and not stored
    Then registering craft recipe "<id>" from "<ingredient>" into "<output>" should be refused with "<reason>"
    And the craft recipe "<id>" should be gone

    Examples:
      | id                    | ingredient       | output           | reason                      |
      | fft test bad          | water_bottle     | coffee           | invalid recipe id           |
      | fft_test/bad          | water_bottle     | coffee           | invalid recipe id           |
      | fft_test_bad_input    | fft_no_such_item | coffee           | unknown recipe ingredient   |
      | fft_test_bad_output   | water_bottle     | fft_no_such_item | unknown recipe output       |

  @server @rejection
  Scenario: A craft recipe id is limited to 96 characters
    Then a craft recipe id of 96 characters should be accepted
    And a craft recipe id of 97 characters should be refused

  @server
  Scenario: Crafting consumes the ingredients and grants the output once
    Given I hold 2 "water_bottle"
    And I register the craft recipe "fft_test_coffee" turning 2 "water_bottle" into 1 "coffee"
    And I remember how many "coffee" I have
    And I watch for crafting completions
    When crafting "fft_test_coffee" for me should succeed
    Then I should have 0 "water_bottle"
    And I should have 1 more "coffee" than before
    And a crafting completion of "fft_test_coffee" should have been recorded for me

  @server
  Scenario: A batch crafts every repetition and consumes the scaled ingredients
    Given I hold 6 "water_bottle"
    And I register the craft recipe "fft_test_coffee" turning 2 "water_bottle" into 1 "coffee"
    When crafting "fft_test_coffee" 3 times for me should succeed
    Then I should have 0 "water_bottle"
    And I should have 3 "coffee"

  @server @rejection
  Scenario: A craft with a short ingredient is refused and consumes nothing
    Given I hold 1 "water_bottle"
    And I register the craft recipe "fft_test_coffee" turning 2 "water_bottle" into 1 "coffee"
    When crafting "fft_test_coffee" for me should be refused with "missing crafting ingredient: water_bottle"
    Then I should have 1 "water_bottle"
    And I should have 0 "coffee"

  @server @rejection
  Scenario Outline: A craft amount that is not a whole batch from 1 to 100 is refused
    Given I hold 2 "water_bottle"
    And I register the craft recipe "fft_test_coffee" turning 2 "water_bottle" into 1 "coffee"
    When crafting "fft_test_coffee" with amount "<amount>" should be refused with "invalid crafting amount"
    Then I should have 2 "water_bottle"

    Examples:
      | amount |
      | 0      |
      | -1     |
      | 1.5    |
      | nan    |
      | inf    |
      | 101    |
      | abc    |

  @server
  Scenario: The largest batch is accepted for planning and then refused for missing stock
    Given I register the craft recipe "fft_test_coffee" turning 2 "water_bottle" into 1 "coffee"
    When crafting "fft_test_coffee" with amount "100" should be refused with "missing crafting ingredient: water_bottle"

  @server @rejection
  Scenario: A recipe access check that refuses stops the craft before anything is consumed
    Given I hold 2 "water_bottle"
    And I register the craft recipe "fft_test_gated" turning 2 "water_bottle" into 1 "coffee" gated by an access check that refuses with "Staff only"
    When crafting "fft_test_gated" for me should be refused with "Staff only"
    Then I should have 2 "water_bottle"

  @server @rejection
  Scenario: A recipe access check that throws refuses the craft with the policy failure
    Given I hold 2 "water_bottle"
    And I register the craft recipe "fft_test_faulty" turning 2 "water_bottle" into 1 "coffee" gated by an access check that errors
    When crafting "fft_test_faulty" for me should be refused with "crafting policy failed"
    Then I should have 2 "water_bottle"

  @server @rejection
  Scenario: A craft hook that refuses stops the craft and gives its reason
    Given I hold 2 "water_bottle"
    And I register the craft recipe "fft_test_coffee" turning 2 "water_bottle" into 1 "coffee"
    And I register a craft hook that refuses with "Hook says no"
    When crafting "fft_test_coffee" for me should be refused with "Hook says no"
    Then I should have 2 "water_bottle"
    And I should have 0 "coffee"

  @server
  Scenario: A craft hook is told the recipe, the batch size and who is crafting
    Given I hold 4 "water_bottle"
    And I register the craft recipe "fft_test_coffee" turning 2 "water_bottle" into 1 "coffee"
    And I register a craft hook that records what it sees
    When crafting "fft_test_coffee" 2 times for me should succeed
    Then the craft hook should have seen recipe "fft_test_coffee" for 2 times for me

  @server
  Scenario: A removed craft hook no longer refuses a craft
    Given I hold 2 "water_bottle"
    And I register the craft recipe "fft_test_coffee" turning 2 "water_bottle" into 1 "coffee"
    And I register a craft hook that refuses with "Hook says no"
    And removing the craft hook should return true
    When crafting "fft_test_coffee" for me should succeed
    And removing the craft hook should return false

  @server
  Scenario: The craft check reports makeability without consuming or running the gates
    Given I hold 2 "water_bottle"
    And I register the craft recipe "fft_test_gated" turning 2 "water_bottle" into 1 "coffee" gated by an access check that refuses with "Staff only"
    And I register a craft hook that refuses with "Hook says no"
    Then the craft recipe "fft_test_gated" should be makeable by me 1 times
    And the craft recipe "fft_test_gated" should not be makeable by me 2 times with "missing crafting ingredient: water_bottle"
    And I should have 2 "water_bottle"

  @server
  Scenario: The trusted craft check passes a full recipe and changes no items
    Given I hold 2 "water_bottle"
    Then a trusted craft check of 2 "water_bottle" into 1 "coffee" should pass
    And I should have 2 "water_bottle"
    And I should have 0 "coffee"

  @server @rejection
  Scenario: The trusted craft check refuses a short ingredient and an over-weight output
    Given I hold 1 "water_bottle"
    Then a trusted craft check of 2 "water_bottle" into 1 "coffee" should be refused
    And a trusted craft check of 1 "water_bottle" into 5000 "coffee" should be refused
    And I should have 1 "water_bottle"

  @server @rejection
  Scenario: A craft recipe can be removed once and an unknown one is not removed
    Given I register the craft recipe "fft_test_coffee" turning 2 "water_bottle" into 1 "coffee"
    Then removing craft recipe "fft_test_coffee" should return true
    And the craft recipe "fft_test_coffee" should be gone
    And removing craft recipe "fft_test_coffee" should return false
    And removing craft recipe "fft_test_never_made" should return false
