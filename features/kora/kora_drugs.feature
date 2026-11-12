@kora @kora_drugs
Feature: kora_drugs published production data, dealer roster and rejection paths
  kora_drugs publishes the production steps and lab entrances to clients,
  keeps corner-selling prices on the server, serves a dealer roster and
  rejects corner selling and joint rolling when the player has no stock.
  Step names come from kora_drugs/server/events.lua, the dealer products from
  shared/legacy_dealers.lua and the messages from server/Cornerselling.lua and
  server/Weed.lua.

  Uses the read-only hook kora_drugs/fft_hooks_server.lua (action
  "cornerSelling") because the corner-selling prices are server-only.

  Fixture: a server without the example data (Config.storage.exampleData, off
  by default) has an empty corner-selling price list, so the two corner-selling
  scenarios price "cocaine_baggy" at 20 themselves and cleanup restores the
  price list exactly. The price is saved through the admin callbacks the
  /drugCreator cornerselling page sends (client hook kora_drugs/fft_hooks.lua),
  so the tester must be allowed to use /drugCreator. While such a scenario
  runs the price is real for every player, hence @global: anyone carrying that
  item could corner-sell it at 20 for those few seconds.

  Not covered, on purpose:
  - Crafting, cooking and plant picking: the server drops a player on the
    fifth request inside a cooldown window, and no test may count towards it.
  - A completed corner sale, or /cornerSell with stock: it takes over an
    ambient ped other players can see, and the client keeps the offered deal
    cached after the command is toggled off, which would break the no-stock
    scenario on the next run.
  - Dealer deliveries and dealer shops: they depend on dealer rows in the
    database, the in-game hour and reputation, and move a delivery session
    that is stored per character.
  - Lab teleports and the meth cook: they move the player into shared
    interiors and run long progress bars and minigames.
  - The /drugCreator UI itself (search, price dialog, map placement). Its
    server callbacks are exercised directly, the way the creator page sends
    them: every refusal branch that answers before anything is written, the
    read-only event, plant and corner pages, and the corner price save.
    Successful creator writes other than the corner price (plants, recipes,
    custom drugs, deleting events) are not run: they change data every player
    uses. A refusal that is unexpectedly accepted is undone in cleanup.
  - ReloadEvents with a well-formed but unknown step: it adds an empty drug to
    GlobalState.Drugs for every player until restart (see the suite report).
  The lab-entrance and dealer scenarios pass without checking anything when
  the database holds no entrance or dealer rows.

  Background:
    Given resource "kora_drugs" is running

  @server
  Scenario: Production steps are published and server-only settings stay private
    Then the drug production registry should publish every public step with settings and locations
    And the drug production registry should keep server-only drug settings private

  @server
  Scenario: Published lab entrances are normalised enter and exit pairs
    Then every published drug lab entrance should have an enter and an exit position

  @server
  Scenario: Dealer roster lists the configured products for every dealer
    Then every drug dealer in the roster should list the 10 configured products

  @global
  Scenario: A corner selling price saved from the creator reaches the corner seller
    Given the corner seller buys "cocaine_baggy" for 20 during this scenario
    Then corner selling should price "cocaine_baggy" at 20
    And corner selling should have a positive price for at least one item

  @server
  Scenario: Reloading an unchanged step reports no change
    Then reloading the unchanged corner selling settings should report no change

  @ui @rejection @global
  Scenario: Corner selling does not start without sellable drugs
    Given the corner seller buys "cocaine_baggy" for 20 during this scenario
    And corner selling should have a positive price for at least one item
    And I carry nothing the corner seller would buy
    When I run the command "cornerSell"
    Then I should see a notification containing "You have no sellable items."
    And no text prompt should be shown

  @rejection
  Scenario: Rolling paper is kept when the player has no weed to roll
    Given I should carry no weed that rolling paper could use
    And I hold 1 "rolling_paper"
    And I remember how many "rolling_paper" I have
    When I use my drug item "rolling_paper"
    Then I should see a notification containing "You need a weed item to roll"
    And I should have 0 fewer "rolling_paper" than before

  # --- The drug creator's server callbacks ------------------------------------

  @server @rejection
  Scenario Outline: The drug creator refuses a request that breaks a rule
    Given I may use the drug creator
    Then the drug creator should refuse "<request>" with "<message>"

    Examples:
      | request                                                | message                                                                  |
      | reading an unknown event                               | Unknown event.                                                           |
      | reading the reserved Weed:pick event                   | Unknown event.                                                           |
      | saving an unknown event                                | Unknown event.                                                           |
      | saving corner settings without a patch table           | Nothing to save.                                                         |
      | saving corner settings whose data is not a table       | Invalid data.                                                            |
      | saving a corner price list that is not a table         | Invalid pricing.                                                         |
      | saving a corner price for a malformed item name        | Invalid item name in the price list.                                     |
      | saving a negative corner price                         | The price for cocaine_baggy must be between 0 and 1000000.               |
      | saving a corner price above the limit                  | The price for cocaine_baggy must be between 0 and 1000000.               |
      | saving a corner price that is not a number             | The price for cocaine_baggy must be between 0 and 1000000.               |
      | saving 501 corner prices                               | Too many items in the price list.                                        |
      | saving a max sell of 0                                 | Max sell must be between 1 and 1000.                                     |
      | saving a rip-off of 1.5                                | Rip-off must be between 0 and 1 (0.2 is 20%).                            |
      | saving a minimum police of 101                         | Minimum police must be between 0 and 100.                                |
      | saving a negative THC swing                            | THC / CBD swing must be between 0 and 1 (0.2 is 20%).                    |
      | deleting the permanent corner settings                 | This event cannot be deleted.                                            |
      | deleting an unknown event                              | This event cannot be deleted.                                            |
      | restoring the permanent recipe settings                | This event cannot be restored.                                           |
      | reading an unknown plant                               | Unknown plant.                                                           |
      | saving a plant without a patch table                   | Nothing to save.                                                         |
      | saving an unknown plant                                | Unknown plant.                                                           |
      | deleting an unknown plant                              | Unknown plant.                                                           |
      | creating a plant whose name starts with a digit        | Name must be letters and numbers only, starting with a letter.           |
      | creating a plant named like a GlobalState key          | That name is already in use by something else.                           |
      | creating a plant with a malformed model                | Enter a valid prop model.                                                |
      | creating a plant that gives an unknown item            | That item does not exist.                                                |
      | searching items for an unknown recipe                  | Unknown recipe.                                                          |
      | setting the items of an unknown recipe                 | Unknown recipe.                                                          |
      | setting the product of an unknown recipe               | Unknown recipe.                                                          |
      | deleting an unknown recipe                             | Unknown recipe.                                                          |
      | creating a recipe whose drug starts with a digit       | Name must be letters and numbers only, starting with a letter.           |
      | creating a recipe that makes an unknown item           | fft_no_such_item does not exist.                                         |
      | creating a recipe that makes 0 items                   | The amount made must be between 1 and 1000.                              |
      | creating a custom drug whose name starts with a digit  | Name must be letters and numbers only, starting with a letter, 24 at most. |
      | creating a custom drug named Weed                      | That name is already used.                                               |
      | creating a custom drug named weed in lower case        | That name is already used.                                               |
      | deleting an unknown custom drug                        | Unknown drug.                                                            |
      | creating a custom event whose name starts with a digit | Name must be letters, numbers and _, starting with a letter, 24 at most. |
      | creating a custom event for an unknown drug            | Unknown drug, or that name is not allowed.                               |
      | creating a custom event over a base event              | Unknown drug, or that name is not allowed.                               |
      | deleting a base event as a custom event                | Only custom events can be deleted.                                       |

  @server
  Scenario Outline: The drug creator opens every built-in event
    Given I may use the drug creator
    Then the drug creator should open the event "<step>" with its data and locations

    Examples:
      | step                   |
      | Cocaine:lab            |
      | Cocaine:powder         |
      | Cocaine:cutting        |
      | Cocaine:bagging        |
      | Crack:cook             |
      | Crack:bagging          |
      | Heroin:drying          |
      | Heroin:vials           |
      | Heroin:syringe         |
      | Meth:tele              |
      | Meth:pour              |
      | Meth:heat              |
      | Meth:smash             |
      | Meth:bag               |
      | Weed:lab               |
      | Weed:drying            |
      | Weed:breakNugs         |
      | Weed:bagWeed           |
      | CornerSelling:settings |
      | Recipes:settings       |

  @server
  Scenario: The drug creator lists every plant players can pick
    Given I may use the drug creator
    Then the drug creator should list every plant published to players

  # --- Corner prices -------------------------------------------------------------

  @global
  Scenario: A corner price saved from the creator shows on the creator's corner page
    Given the corner seller buys "cocaine_baggy" for 20 during this scenario
    Then the drug creator corner page should list "cocaine_baggy" at 20

  @global
  Scenario: The lowest whole corner price is accepted
    Given the corner seller buys "cocaine_baggy" for 1 during this scenario
    Then corner selling should price "cocaine_baggy" at 1
    And the drug creator corner page should list "cocaine_baggy" at 1

  @global
  Scenario: Changing a corner price twice keeps the last one
    Given the corner seller buys "cocaine_baggy" for 20 during this scenario
    And the corner seller buys "cocaine_baggy" for 25 during this scenario
    Then corner selling should price "cocaine_baggy" at 25

  @global
  Scenario: A corner price removed from the creator is no longer bought
    Given the corner seller buys "cocaine_baggy" for 20 during this scenario
    When the corner seller stops buying "cocaine_baggy" during this scenario
    Then corner selling should not price "cocaine_baggy"

  @ui @rejection @global
  Scenario: Holding an item the corner seller does not price is not a sellable item
    Given the corner seller buys "cocaine_baggy" for 20 during this scenario
    And the corner seller stops buying "cocaine_baggy" during this scenario
    And corner selling should not price "cocaine_baggy"
    And I hold 1 "cocaine_baggy"
    And I carry nothing the corner seller would buy
    When I run the command "cornerSell"
    Then I should see a notification containing "You have no sellable items."
    And no text prompt should be shown

  # --- Reloads, plants and dealers -----------------------------------------------

  @server @rejection
  Scenario Outline: ReloadEvents refuses a name it cannot reload
    Then reloading the drug step "<name>" should be refused

    Examples:
      | name          |
      | Weed:pick     |
      | Cocaine:pick  |
      | Weed          |
      | Weed:         |
      | :drying       |
      | Weed:dry ing  |

  @server
  Scenario: Every published plant has spots and settings
    Then every published drug plant should have spots and settings

  @server
  Scenario: The qb-drugs dealer export serves the same roster
    Then the qb-drugs dealer export should serve the same roster
