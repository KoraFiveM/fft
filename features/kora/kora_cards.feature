@kora @kora_cards
Feature: kora_cards City Legends app and Card Studio stations
  /cards opens the City Legends app. Card Studio employees clock in at the duty
  desk and buy film, blank cards and ink at the supply counter; the server
  checks job, duty, distance, quantity and cash on every action. App actions are
  driven at the NUI-callback level through kora_lib's hook, not by clicking
  rendered buttons. The off-duty refusals trigger actions whose buttons the app
  shows disabled, so they prove the server check behind the button.

  Station positions come from Config.studio.locations in kora_cards/config.lua
  (server reach Config.studio.actionDistance = 2.25 m). They and the aim points
  are unverified until run live.

  The 'kora_cards:server:action' callback behind every app action is also
  called directly as the tester, so job, duty, grade, station, payload and
  ownership checks are proven whatever the app shows. Only refusals and
  restorable mutations (supplies, the studio camera, duty) are driven.

  Not covered: starter claims (one per character, never undone), shop
  purchases, printing, deposit and withdraw of real prints, deck saves
  (serialized prints, deck rows and operation rows have no delete API), card
  photography (needs screenshot-basic and writes catalog rows and files),
  draft editing, activation, cloning and archiving that succeed (permanent
  catalog changes), matches and challenges that need a second player, the
  season admin commands (close a season server-wide), the 45-per-10 s action
  rate limit, and the private card viewer, portrait editor and match overlay
  (the resource's own NUI page). The empty deck draft opened by the deck
  scenario stays in the tester's client until relog.

  Background:
    Given resource "kora_cards" is running

  @ui
  Scenario: The cards command opens the binder
    When I run the command "cards"
    Then the app "kora_cards:city-legends" should be open
    And the City Legends app should show the "binder" page
    When I close the app
    Then no app should be open

  @ui @rejection
  Scenario: Studio tools are not offered to other jobs
    Given my job is "unemployed" at grade 1
    When I run the command "cards"
    Then the app "kora_cards:city-legends" should be open
    And the app action "cards:toggle-duty" should be unavailable
    And the app action "cards:buy-film" should be unavailable
    And I close the app

  @ui @world
  Scenario: An employee clocks in and out at the duty desk through the app
    Given I am off duty as "cardstudio" at grade 1
    And I stand at -1049.46 -235.54 39.01 facing 208.0
    When I run the command "cards"
    Then the app "kora_cards:city-legends" should be open
    When I trigger the app action "cards:toggle-duty"
    Then the app should answer with a "success" notice containing "Clocked in."
    And I should be on duty
    When I trigger the app action "cards:toggle-duty"
    Then the app should answer with a "success" notice containing "Clocked out."
    And I should be off duty
    And I close the app

  @world
  Scenario: The duty desk target clocks an employee in
    Given I am off duty as "cardstudio" at grade 1
    And I stand at -1048.83 -234.52 39.01 facing 208.0
    And I aim at -1049.46 -235.54 39.01
    When I target "Clock In / Out"
    Then I should see a notification containing "Clocked in."
    And I should be on duty

  @ui @world @rejection
  Scenario: Clocking in away from the duty desk is refused
    Given I am off duty as "cardstudio" at grade 1
    And I stand at -1045.22 -235.45 39.01 facing 302.0
    When I run the command "cards"
    Then the app "kora_cards:city-legends" should be open
    When I trigger the app action "cards:toggle-duty"
    Then the app should answer with a "destructive" notice containing "Move closer to the correct Card Studio station."
    And I should be off duty
    And I close the app

  @ui @world
  Scenario Outline: An on-duty employee buys supplies at the counter
    Given I am on duty as "cardstudio" at grade 1
    And I have 500 in my "cash" account
    And Card Studio supplies I buy are returned afterwards
    And I stand at -1045.22 -235.45 39.01 facing 302.0
    And I remember my "cash" balance
    And I remember how many "<item>" I have
    When I run the command "cards"
    Then the app "kora_cards:city-legends" should be open
    When I trigger the app action "<action>" with:
      """
      { "value": { "amount": <amount> } }
      """
    Then the app should answer with a "success" notice containing "Studio supplies purchased."
    And I should have <amount> more "<item>" than before
    And my "cash" balance should have decreased by <cost>
    And I close the app

    Examples:
      | action          | item       | amount | cost |
      | cards:buy-ink   | card_ink   | 2      | 20   |
      | cards:buy-film  | card_film  | 1      | 50   |
      | cards:buy-blank | blank_card | 3      | 45   |

  @ui @world @rejection
  Scenario: Supplies are refused while off duty
    Given I am off duty as "cardstudio" at grade 1
    And I have 500 in my "cash" account
    And Card Studio supplies I buy are returned afterwards
    And I stand at -1045.22 -235.45 39.01 facing 302.0
    And I remember my "cash" balance
    When I run the command "cards"
    Then the app "kora_cards:city-legends" should be open
    When I trigger the app action "cards:buy-film"
    Then the app should answer with a "destructive" notice containing "Clock in before using studio equipment."
    And I should have no "card_film"
    And my "cash" balance should be unchanged
    And I close the app

  @ui @world @rejection
  Scenario: Supplies are refused away from the counter
    Given I am on duty as "cardstudio" at grade 1
    And I have 500 in my "cash" account
    And Card Studio supplies I buy are returned afterwards
    And I stand at -1049.46 -235.54 39.01 facing 208.0
    And I remember my "cash" balance
    When I run the command "cards"
    Then the app "kora_cards:city-legends" should be open
    When I trigger the app action "cards:buy-blank"
    Then the app should answer with a "destructive" notice containing "Move closer to the correct Card Studio station."
    And I should have no "blank_card"
    And my "cash" balance should be unchanged
    And I close the app

  @ui @world @rejection
  Scenario: More than twenty of a supply cannot be bought at once
    Given I am on duty as "cardstudio" at grade 1
    And I have 500 in my "cash" account
    And Card Studio supplies I buy are returned afterwards
    And I stand at -1045.22 -235.45 39.01 facing 302.0
    And I remember my "cash" balance
    When I run the command "cards"
    Then the app "kora_cards:city-legends" should be open
    When I trigger the app action "cards:buy-ink" with:
      """
      { "value": { "amount": 21 } }
      """
    Then the app should answer with a "destructive" notice containing "Invalid studio supply purchase."
    And I should have no "card_ink"
    And my "cash" balance should be unchanged
    And I close the app

  @ui @world @rejection
  Scenario: Supplies are refused without enough cash
    Given I am on duty as "cardstudio" at grade 1
    And I have 5 in my "cash" account
    And Card Studio supplies I buy are returned afterwards
    And I stand at -1045.22 -235.45 39.01 facing 302.0
    And I remember my "cash" balance
    When I run the command "cards"
    Then the app "kora_cards:city-legends" should be open
    When I trigger the app action "cards:buy-film"
    Then the Card Studio app should decline the action
    And I should have no "card_film"
    And my "cash" balance should be unchanged
    And I close the app

  @ui @world @rejection
  Scenario: The studio camera is refused away from the locker
    Given I am on duty as "cardstudio" at grade 1
    And I stand at -1045.22 -235.45 39.01 facing 302.0
    When I run the command "cards"
    Then the app "kora_cards:city-legends" should be open
    When I trigger the app action "cards:checkout-camera"
    Then the app should answer with a "destructive" notice containing "Move closer to the correct Card Studio station."
    And I should have no "card_camera"
    And I close the app

  @ui @rejection
  Scenario: An empty deck cannot be saved
    When I run the command "cards"
    Then the app "kora_cards:city-legends" should be open
    When I trigger the app action "cards:new-deck"
    Then the app should answer with a "primary" notice containing "Choose 60 exact prints from your binder."
    When I trigger the app action "cards:save-deck" with:
      """
      { "value": { "name": "FFT empty deck" } }
      """
    Then the app should answer with a "destructive" notice containing "A deck must contain exactly 60 cards."
    And I close the app

  @ui @world
  Scenario: The public shop counter opens the shop page
    Given I stand at -1049.51 -231.45 39.01 facing 134.0
    And I aim at -1050.37 -230.62 39.01
    When I target "Browse City Legends"
    Then the app "kora_cards:city-legends" should be open
    And the City Legends app should show the "shop" page
    And I close the app

  # ===========================================================================
  # The 'kora_cards:server:action' callback, called directly as the tester.
  # Every app button and studio target funnels into it, so these prove the
  # server's own checks whatever the app shows or disables.
  # ===========================================================================

  # --- Dispatcher and snapshot ----------------------------------------------

  @rejection
  Scenario: Unknown City Legends actions are refused
    When I send the City Legends server action "fft:not-an-action"
    Then the City Legends server should refuse with "Unknown card action."
    When I send the City Legends server a numeric action
    Then the City Legends server should refuse with "Unknown card action."

  Scenario: The snapshot has no studio section for other jobs
    Given my job is "unemployed" at grade 1
    Then my City Legends snapshot should not include the studio

  Scenario Outline: The snapshot reports the employee's studio duty and grade
    Given I am <duty> as "cardstudio" at grade <grade>
    Then my City Legends snapshot should show the studio "<duty>" at grade <grade>

    Examples:
      | duty     | grade |
      | on duty  | 1     |
      | off duty | 3     |

  Scenario Outline: The snapshot offers each configured starter as exactly sixty cards
    Then my City Legends snapshot should offer the "<starter>" starter of 60 cards

    Examples:
      | starter        |
      | street_circuit |
      | harbor_guard   |

  Scenario: The shop only lists active designs that are for sale
    Then the City Legends shop should only list active designs for sale

  Scenario: Drafts stay out of the studio catalog while off duty
    Given I am off duty as "cardstudio" at grade 4
    Then the City Legends studio catalog should list no drafts

  # --- Binder, decks and starters: refusals only ----------------------------

  @rejection
  Scenario Outline: An invalid starter choice is refused before anything is claimed
    When I send the City Legends server action "claimStarter" with:
      """
      <payload>
      """
    Then the City Legends server should refuse with "Choose Street Circuit or Harbor Guard."

    Examples:
      | payload                    |
      | { "starter": "fft_deck" }  |
      | { "starter": "" }          |
      | { "starter": 7 }           |
      | { }                        |

  @rejection
  Scenario Outline: A deck that is not sixty cards from the binder is refused
    When I try to save a City Legends deck of <count> unknown prints
    Then the City Legends server should refuse with "<reason>"

    Examples:
      | count | reason                                  |
      | 0     | A deck must contain exactly 60 cards.   |
      | 59    | A deck must contain exactly 60 cards.   |
      | 60    | Every deck card must be in your binder. |
      | 61    | Deck payload is too large.              |

  @rejection
  Scenario Outline: Binder actions on prints the tester does not own are refused
    When I send the City Legends server action "<action>" with:
      """
      <payload>
      """
    Then the City Legends server should refuse with "<reason>"

    Examples:
      | action     | payload                               | reason                                  |
      | deleteDeck | { "deckId": "fft-missing-deck" }      | Deck not found.                         |
      | withdraw   | { "printId": "fft-missing-print" }    | That exact print is not in your binder. |
      | viewer     | { "printId": "fft-missing-print" }    | That print could not be verified.       |
      | showNearby | { "printId": "fft-missing-print" }    | That print could not be verified.       |
      | deposit    | { }                                   | Select a physical trading card slot.    |
      | deposit    | { "slot": 0 }                         | Select a physical trading card slot.    |
      | deposit    | { "slot": -3 }                        | Select a physical trading card slot.    |

  @rejection
  Scenario: A physical card without a trusted print id cannot be deposited or viewed
    Given I hold 1 "trading_card"
    Then my City Legends snapshot should list an unverified physical card
    When I send the City Legends server action "deposit" for that physical card
    Then the City Legends server should refuse with "This card has no trusted print ID."
    And I should have at least 1 "trading_card"
    When I send the City Legends server action "viewer" for that physical card
    Then the City Legends server should refuse with "That print could not be verified."

  @rejection
  Scenario: Deposit refuses an inventory slot that does not hold a trading card
    Given I hold 1 "card_ink"
    When I send the City Legends server action "deposit" with:
      """
      { "slot": 1 }
      """
    Then the City Legends server should refuse with "Select a physical trading card slot."
    And I should have at least 1 "card_ink"

  # --- Matches: refusals that need no second player -------------------------

  @rejection
  Scenario: A player cannot challenge themselves
    When I challenge myself to a City Legends match
    Then the City Legends server should refuse with "Choose a nearby player."

  @rejection
  Scenario Outline: Match actions without a match or challenge are refused
    When I send the City Legends server action "<action>" with:
      """
      <payload>
      """
    Then the City Legends server should refuse with "<reason>"

    Examples:
      | action           | payload                                              | reason                      |
      | challenge        | { "target": 0, "mode": "casual" }                    | Choose a nearby player.     |
      | challengeRespond | { "challengeId": "fft-missing", "accept": false }    | That challenge has expired. |
      | challengeRespond | { "challengeId": "fft-missing", "accept": true }     | That challenge has expired. |
      | matchAction      | { "matchId": "fft-missing", "actionId": "pass" }     | Match not found.            |

  # --- Shop: refusals only ----------------------------------------------------

  @world @rejection
  Scenario: The shop refuses a purchase away from the counter
    Given I have 1000 in my "bank" account
    And I stand at -1045.22 -235.45 39.01 facing 302.0
    And I remember my "bank" balance
    When I send the City Legends server action "buyShop" with:
      """
      { "id": "fft-missing-design" }
      """
    Then the City Legends server should refuse with "Move closer to the correct Card Studio station."
    And my "bank" balance should be unchanged

  @world @rejection
  Scenario Outline: The shop counter refuses designs that are not for sale
    Given I have 1000 in my "bank" account
    And I stand at -1050.37 -230.62 39.01 facing 207.0
    And I remember my "bank" balance
    When I send the City Legends server action "<action>" with:
      """
      <payload>
      """
    Then the City Legends server should refuse with "That card is not for sale."
    And my "bank" balance should be unchanged

    Examples:
      | action  | payload                              |
      | buyShop | { "id": "fft-missing-design" }       |
      | shopBuy | { "designId": "fft-missing-design" } |
      | buyShop | { }                                  |

  # --- Studio authorisation: job, duty, grade, station ----------------------

  @rejection
  Scenario Outline: Studio equipment is refused to people who do not work there
    Given my job is "unemployed" at grade 1
    When I send the City Legends server action "<action>"
    Then the City Legends server should refuse with "You do not work for the Card Studio."

    Examples:
      | action         |
      | toggleDuty     |
      | buySupply      |
      | checkoutCamera |
      | printDesign    |
      | activateDesign |
      | cloneDesign    |
      | archiveDesign  |
      | updateDraft    |

  @rejection
  Scenario Outline: Studio equipment is refused to an off-duty employee of any grade
    Given I am off duty as "cardstudio" at grade 4
    When I send the City Legends server action "<action>"
    Then the City Legends server should refuse with "Clock in before using studio equipment."

    Examples:
      | action         |
      | buySupply      |
      | checkoutCamera |
      | printDesign    |
      | activateDesign |
      | cloneDesign    |
      | archiveDesign  |
      | saveDraft      |

  @rejection
  Scenario Outline: Studio equipment above the employee's grade is refused
    Given I am on duty as "cardstudio" at grade <grade>
    When I send the City Legends server action "<action>" with:
      """
      { "designId": "fft-missing-design" }
      """
    Then the City Legends server should refuse with "Your studio grade cannot use this equipment."

    Examples:
      | action         | grade |
      | printDesign    | 1     |
      | activateDesign | 1     |
      | cloneDesign    | 1     |
      | cloneDesign    | 2     |
      | archiveDesign  | 1     |
      | archiveDesign  | 3     |

  @world @rejection
  Scenario Outline: Studio equipment is refused away from its station
    Given I am on duty as "cardstudio" at grade 4
    And I stand at -1049.51 -231.45 39.01 facing 134.0
    When I send the City Legends server action "<action>" with:
      """
      { "designId": "fft-missing-design", "item": "card_ink", "amount": 1 }
      """
    Then the City Legends server should refuse with "Move closer to the correct Card Studio station."

    Examples:
      | action         |
      | toggleDuty     |
      | buySupply      |
      | checkoutCamera |
      | printDesign    |
      | activateDesign |
      | cloneDesign    |
      | archiveDesign  |
      | updateDraft    |

  @world @rejection
  Scenario Outline: Studio stations refuse designs that do not exist
    Given I am on duty as "cardstudio" at grade 4
    And I stand at <x> <y> 39.01 facing <h>
    When I send the City Legends server action "<action>" with:
      """
      { "designId": "fft-missing-design" }
      """
    Then the City Legends server should refuse with "<reason>"

    Examples:
      | x        | y       | h    | action         | reason                              |
      | -1047.12 | -229.94 | 28.0 | printDesign    | Only active designs can be printed. |
      | -1044.83 | -232.24 | 29.0 | activateDesign | That draft is unavailable.          |
      | -1044.83 | -232.24 | 29.0 | updateDraft    | That draft is unavailable.          |
      | -1044.83 | -232.24 | 29.0 | cloneDesign    | Design not found.                   |
      | -1044.83 | -232.24 | 29.0 | archiveDesign  | Design not found.                   |

  @world @rejection
  Scenario Outline: An active design cannot be edited or activated again as a draft
    Given I am on duty as "cardstudio" at grade 3
    And I note an active City Legends design that can still be printed
    And I stand at -1044.83 -232.24 39.01 facing 29.0
    When I send the City Legends server action "<action>" for the noted design
    Then the City Legends server should refuse with "That draft is unavailable."

    Examples:
      | action         |
      | activateDesign |
      | updateDraft    |

  @world @rejection
  Scenario Outline: Printing needs both a blank card and ink
    Given I am on duty as "cardstudio" at grade 2
    And Card Studio supplies I buy are returned afterwards
    And I note an active City Legends design that can still be printed
    And I stand at -1047.12 -229.94 39.01 facing 28.0
    And I remember how many "trading_card" I have
    And I hold 1 "<held>"
    When I send the City Legends server action "printDesign" for the noted design
    Then the City Legends server should refuse with "Printing needs one blank card and one ink."
    And I should have 0 more "trading_card" than before
    And I should have at least 1 "<held>"

    Examples:
      | held       |
      | blank_card |
      | card_ink   |

  # --- Supplies through the server action -----------------------------------

  @world @rejection
  Scenario Outline: An invalid supply order is refused and charges nothing
    Given I am on duty as "cardstudio" at grade 1
    And I have 500 in my "cash" account
    And Card Studio supplies I buy are returned afterwards
    And I stand at -1045.22 -235.45 39.01 facing 302.0
    And I remember my "cash" balance
    When I send the City Legends server action "buySupply" with:
      """
      <payload>
      """
    Then the City Legends server should refuse with "Invalid studio supply purchase."
    And my "cash" balance should be unchanged
    And I should have no "card_film"
    And I should have no "card_camera"

    Examples:
      | payload                                  |
      | { "item": "card_film", "amount": 0 }     |
      | { "item": "card_film", "amount": -1 }    |
      | { "item": "card_film", "amount": 21 }    |
      | { "item": "card_film", "amount": 0.5 }   |
      | { "item": "card_camera", "amount": 1 }   |
      | { "item": "trading_card", "amount": 1 }  |
      | { "amount": 1 }                          |

  @world
  Scenario Outline: Supply orders are rounded down to whole units and default to one
    Given I am on duty as "cardstudio" at grade 1
    And I have 500 in my "cash" account
    And Card Studio supplies I buy are returned afterwards
    And I stand at -1045.22 -235.45 39.01 facing 302.0
    And I remember my "cash" balance
    And I remember how many "<item>" I have
    When I send the City Legends server action "buySupply" with:
      """
      <payload>
      """
    Then the City Legends server should report "amount" as "<amount>"
    And I should have <amount> more "<item>" than before
    And my "cash" balance should have decreased by <cost>

    Examples:
      | payload                                  | item       | amount | cost |
      | { "item": "card_film", "amount": 1.9 }   | card_film  | 1      | 50   |
      | { "item": "card_ink", "amount": "3" }    | card_ink   | 3      | 30   |
      | { "item": "blank_card" }                 | blank_card | 1      | 15   |
      | { "item": "blank_card", "amount": 20 }   | blank_card | 20     | 300  |

  @world
  Scenario: Supplies can be bought with exactly enough cash
    Given I am on duty as "cardstudio" at grade 1
    And I have 150 in my "cash" account
    And Card Studio supplies I buy are returned afterwards
    And I stand at -1045.22 -235.45 39.01 facing 302.0
    And I remember my "cash" balance
    When I send the City Legends server action "buySupply" with:
      """
      { "item": "card_film", "amount": 3 }
      """
    Then the City Legends server should accept the action
    And I should have at least 3 "card_film"
    And my "cash" balance should have decreased by 150

  @world @rejection
  Scenario: Supplies one dollar short are refused
    Given I am on duty as "cardstudio" at grade 1
    And I have 149 in my "cash" account
    And Card Studio supplies I buy are returned afterwards
    And I stand at -1045.22 -235.45 39.01 facing 302.0
    And I remember my "cash" balance
    When I send the City Legends server action "buySupply" with:
      """
      { "item": "card_film", "amount": 3 }
      """
    Then the City Legends server should refuse the action
    And I should have no "card_film"
    And my "cash" balance should be unchanged

  # --- Studio camera and duty -----------------------------------------------

  @world
  Scenario: The locker issues one studio camera and replaces it on a second checkout
    Given I am on duty as "cardstudio" at grade 1
    And any Card Studio camera issued to me is handed back afterwards
    And I stand at -1051.11 -233.77 39.01 facing 119.0
    And I remember how many "card_camera" I have
    When I send the City Legends server action "checkoutCamera"
    Then the City Legends server should report "checkedOut" as "true"
    And I should have 1 more "card_camera" than before
    When I send the City Legends server action "checkoutCamera"
    Then the City Legends server should report "checkedOut" as "true"
    And I should have 1 more "card_camera" than before

  @world
  Scenario: Clocking out at the duty desk hands the studio camera back
    Given I am on duty as "cardstudio" at grade 1
    And any Card Studio camera issued to me is handed back afterwards
    And I stand at -1051.11 -233.77 39.01 facing 119.0
    When I send the City Legends server action "checkoutCamera"
    Then I should have at least 1 "card_camera"
    When I stand at -1049.46 -235.54 39.01 facing 208.0
    And I send the City Legends server action "toggleDuty"
    Then the City Legends server should report "onDuty" as "false"
    And I should be off duty
    And I should have no "card_camera"

  @world @rejection
  Scenario: Clocking in away from the duty desk is refused by the server
    Given I am off duty as "cardstudio" at grade 1
    # The printer (config.lua Config.studio.locations.printer) is about 6 m from
    # the duty desk; actionDistance is 2.25. The locker is only 2.4 m away, too
    # close to tell a refusal from position drift. The wait lets the server see
    # the new position before it measures.
    And I stand at -1047.12 -229.94 39.01 facing 28.0
    And I wait 1000 milliseconds
    When I send the City Legends server action "toggleDuty"
    Then the City Legends server should refuse with "Move closer to the correct Card Studio station."
    And I should be off duty

  @world
  Scenario: The duty desk target clocks an employee out
    Given I am on duty as "cardstudio" at grade 1
    And I stand at -1048.83 -234.52 39.01 facing 208.0
    And I aim at -1049.46 -235.54 39.01
    When I target "Clock In / Out"
    Then I should see a notification containing "Clocked out."
    And I should be off duty

  @world @rejection
  Scenario: The duty desk target refuses people who do not work there
    Given my job is "unemployed" at grade 1
    And I stand at -1048.83 -234.52 39.01 facing 208.0
    And I aim at -1049.46 -235.54 39.01
    When I target "Clock In / Out"
    Then I should see a notification containing "You do not work for the Card Studio."

  # --- Studio app and station targets ---------------------------------------

  @ui @world
  Scenario Outline: Each studio station target opens the studio page
    Given I am off duty as "cardstudio" at grade 1
    And I stand at <x> <y> 39.01 facing 0.0
    And I aim at <aimX> <aimY> 39.01
    When I target "<label>"
    Then the app "kora_cards:city-legends" should be open
    And the City Legends app should show the "studio" page
    And I close the app

    Examples:
      | label               | x        | y        | aimX     | aimY    |
      | Card Studio Locker  | -1049.94 | -233.49  | -1051.11 | -233.77 |
      | Buy Studio Supplies | -1046.11 | -234.64  | -1045.22 | -235.45 |
      | Open Card Editor    | -1046.0  | -232.53  | -1044.83 | -232.24 |
      | Use Card Printer    | -1047.42 | -231.1   | -1047.12 | -229.94 |
