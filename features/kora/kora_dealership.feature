@kora @kora_dealership
Feature: kora_dealership public showroom browsing and purchase
  Display vehicles carry the kora_target entity option "Browse dealership",
  which opens the AppShell app "kora_dealership:showroom"; its cards swap the
  display or buy the vehicle from the bank account. Scenarios use the seeded
  public dealership "pdm" (server/schema.lua: issi3 and asbo are listed, issi3
  is a default display). Placements and prices are database data, so the steps
  read them from GlobalState.Dealerships at run time; the display positions and
  the side a car can be targeted from are unverified until a live run.
  Purchases are limited to public dealerships (no stock or dealership funds are
  touched) and the bought vehicle, its keys and its row are removed in cleanup.
  The purchase confirmation prompt is a browser-side dialog and is not
  exercised; actions are answered at the NUI-callback level.

  Not covered: test drives (they move the tester to another routing bucket and
  an airfield for up to two minutes), offers, assisted sales and the
  management portal (need an owned dealership, a second player or the owner),
  the admin dealership creator (ACE gated; it edits live dealership data), the
  "no free spawn point" and out-of-stock refusals (need blocked spawns or an
  owned dealership). Test drives, offers and the owner/seller callbacks are
  driven only down their refusal paths.

  Background:
    Given resource "kora_dealership" is running

  @server
  Scenario: The public dealership publishes its catalogue and displays
    Then the dealership "pdm" should be a public dealership selling "issi3"
    And the dealership "pdm" should be a public dealership selling "asbo"
    And the dealership "pdm" should display "issi3" by default

  @world @ui
  Scenario: A display vehicle opens the showroom
    When I browse the "issi3" display of dealership "pdm"
    Then the app "kora_dealership:showroom" should be open
    When I close the app
    Then no app should be open

  @world @ui @slow
  Scenario: A vehicle is bought from the showroom with bank money
    Given I note the vehicles I own before visiting the dealership
    And my bank covers the "issi3" listed at dealership "pdm" with 250 to spare
    When I browse the "issi3" display of dealership "pdm"
    Then the app "kora_dealership:showroom" should be open
    When I trigger the app action "purchase:issi3" on "issi3"
    Then I should see a notification containing "Purchase successful!"
    And I should have paid the listed price of "issi3" at dealership "pdm" from my bank
    And the dealership should have delivered me one new "issi3" with its keys
    And I get out of the vehicle the dealership delivered

  @world @ui @rejection
  Scenario: A purchase is refused without enough bank money
    Given I note the vehicles I own before visiting the dealership
    And my bank is 1 short of the "issi3" listed at dealership "pdm"
    When I browse the "issi3" display of dealership "pdm"
    Then the app "kora_dealership:showroom" should be open
    When I trigger the app action "purchase:issi3" on "issi3"
    Then I should see a notification containing "Not enough money in your bank account."
    And the dealership should not have charged my bank
    And the dealership should not have delivered me a vehicle

  @world @ui @rejection
  Scenario: A purchase is refused after walking away from the display
    Given I note the vehicles I own before visiting the dealership
    And my bank covers the "issi3" listed at dealership "pdm" with 250 to spare
    When I browse the "issi3" display of dealership "pdm"
    Then the app "kora_dealership:showroom" should be open
    When I stand at -30.0 -1089.6 26.42 facing 340.0
    And I trigger the app action "purchase:issi3" on "issi3"
    Then I should see a notification containing "You are too far away."
    And the dealership should not have charged my bank
    And the dealership should not have delivered me a vehicle

  @world @ui @rejection
  Scenario: A vehicle that is not sold here has no purchase or swap action
    When I browse the "issi3" display of dealership "pdm"
    Then the app "kora_dealership:showroom" should be open
    And the app action "purchase:fft_not_a_car" should be unavailable
    And the app action "swap:fft_not_a_car" should be unavailable

  @world @ui @global
  Scenario: The display is swapped and reset for everyone
    When I browse the "issi3" display of dealership "pdm"
    Then the app "kora_dealership:showroom" should be open
    When I swap the showroom display to "asbo"
    Then the app should answer with a "success" notice containing "Display vehicle updated."
    And the "issi3" display of dealership "pdm" should show "asbo"
    When I wait 1200 milliseconds
    And I trigger the app action "swap:reset"
    Then the app should answer with a "success" notice containing "Display vehicle updated."
    And the "issi3" display of dealership "pdm" should show "issi3"

  @world @ui @rejection @global
  Scenario: Swapping twice within the cooldown is refused
    When I browse the "issi3" display of dealership "pdm"
    Then the app "kora_dealership:showroom" should be open
    When I swap the showroom display to "asbo"
    And I trigger the app action "swap:reset"
    Then the app should answer with a "destructive" notice containing "Slow down."
    And the "issi3" display of dealership "pdm" should show "asbo"
    When I wait 1200 milliseconds
    And I trigger the app action "swap:reset"
    Then the "issi3" display of dealership "pdm" should show "issi3"

  # -------------------------------------------------------------------------
  # The seeded public catalogue (server/schema.lua pdm row, published as
  # GlobalState.Dealerships by server/functions.lua)
  # -------------------------------------------------------------------------

  @server
  Scenario Outline: The public dealership sells "<model>" for <price>
    Then the dealership "pdm" should list "<model>" for <price>

    Examples:
      | model  | price |
      | asbo   | 4000  |
      | blista | 13000 |
      | club   | 8000  |
      | issi3  | 5000  |
      | panto  | 3200  |
      | asea   | 2500  |

  @server
  Scenario Outline: The public showroom displays "<model>" by default
    Then the dealership "pdm" should display "<model>" by default

    Examples:
      | model    |
      | club     |
      | regina   |
      | hotknife |
      | hellion  |
      | brioso3  |
      | baller   |
      | issi3    |

  @server
  Scenario: A public dealership never runs out of stock
    Then every vehicle listed at dealership "pdm" should have a stock of 9999
    And the dealership "pdm" should not list "sultan"

  # -------------------------------------------------------------------------
  # Purchases driven through kora_dealership:confirmPurchase
  # -------------------------------------------------------------------------

  @world @ui @slow
  Scenario: A vehicle other than the one on display can be bought from that display
    Given I note the vehicles I own before visiting the dealership
    And my bank covers the "asbo" listed at dealership "pdm" with 100 to spare
    When I browse the "issi3" display of dealership "pdm"
    Then the app "kora_dealership:showroom" should be open
    When I trigger the app action "purchase:asbo" on "asbo"
    Then I should see a notification containing "Purchase successful!"
    And I should have paid the listed price of "asbo" at dealership "pdm" from my bank
    And the dealership should have delivered me one new "asbo" with its keys
    And I get out of the vehicle the dealership delivered

  @world @slow
  Scenario: Exactly the listed price in the bank is enough
    Given I note the vehicles I own before visiting the dealership
    And my bank covers the "issi3" listed at dealership "pdm" with 0 to spare
    And I stand beside the "issi3" display of dealership "pdm"
    When I buy "issi3" at the "issi3" display of dealership "pdm" directly
    Then I should have paid the listed price of "issi3" at dealership "pdm" from my bank
    And the dealership should have delivered me one new "issi3" with its keys
    And I get out of the vehicle the dealership delivered

  @world @slow
  Scenario: The model name of a purchase is not case sensitive
    Given I note the vehicles I own before visiting the dealership
    And my bank covers the "issi3" listed at dealership "pdm" with 250 to spare
    And I stand beside the "issi3" display of dealership "pdm"
    When I buy "ISSI3" at the "issi3" display of dealership "pdm" directly
    Then I should have paid the listed price of "issi3" at dealership "pdm" from my bank
    And the dealership should have delivered me one new "issi3" with its keys
    And I get out of the vehicle the dealership delivered

  @world @rejection
  Scenario: A purchase at an unknown dealership is refused
    Given I note the vehicles I own before visiting the dealership
    And my bank covers the "issi3" listed at dealership "pdm" with 250 to spare
    And I stand beside the "issi3" display of dealership "pdm"
    Then asking to buy "issi3" at display "1" of dealership "fft_no_such_dealer" should be refused with "Unknown dealership."
    And the dealership should not have charged my bank
    And the dealership should not have delivered me a vehicle

  @world @rejection
  Scenario Outline: A purchase at display "<display>" is refused as an invalid location
    Given I note the vehicles I own before visiting the dealership
    And my bank covers the "issi3" listed at dealership "pdm" with 250 to spare
    And I stand beside the "issi3" display of dealership "pdm"
    Then asking to buy "issi3" at display "<display>" of dealership "pdm" should be refused with "Invalid location."
    And the dealership should not have charged my bank
    And the dealership should not have delivered me a vehicle

    Examples:
      | display |
      | 0       |
      | -1      |
      | 99      |
      | 1.5     |
      | abc     |

  @world @rejection
  Scenario: A vehicle that is not sold here cannot be bought at the display
    Given I note the vehicles I own before visiting the dealership
    And my bank covers the "issi3" listed at dealership "pdm" with 250 to spare
    And I stand beside the "issi3" display of dealership "pdm"
    Then asking to buy "sultan" at display "issi3" of dealership "pdm" should be refused with "That vehicle is not sold here."
    And the dealership should not have charged my bank
    And the dealership should not have delivered me a vehicle

  @world @rejection
  Scenario: A purchase from across the map is refused
    Given I note the vehicles I own before visiting the dealership
    And my bank covers the "issi3" listed at dealership "pdm" with 250 to spare
    And I stand at 1747.0 3273.7 41.6 facing 90.0
    Then asking to buy "issi3" at display "issi3" of dealership "pdm" should be refused with "You are too far away."
    And the dealership should not have charged my bank
    And the dealership should not have delivered me a vehicle

  @world @rejection
  Scenario: A second purchase request within two seconds is slowed down
    # Config.rateLimits.purchase = 2000 ms, started before any validation.
    Given I note the vehicles I own before visiting the dealership
    And my bank covers the "issi3" listed at dealership "pdm" with 250 to spare
    And I stand beside the "issi3" display of dealership "pdm"
    Then asking to buy "issi3" at display "0" of dealership "pdm" should be refused with "Invalid location."
    And asking again at once to buy "issi3" at display "issi3" of dealership "pdm" should be refused with "Slow down."
    And the dealership should not have charged my bank
    And the dealership should not have delivered me a vehicle

  # -------------------------------------------------------------------------
  # Test drives and offers: refusal paths only (a started test drive moves the
  # tester to another routing bucket; offers need an owned dealership)
  # -------------------------------------------------------------------------

  @world @rejection
  Scenario: A test drive at an unknown dealership is refused
    Given I stand beside the "issi3" display of dealership "pdm"
    Then asking to testdrive "issi3" at display "1" of dealership "fft_no_such_dealer" should be refused with "Unknown dealership."
    And no test drive should have started

  @world @rejection
  Scenario: A test drive of a vehicle that is not sold here is refused
    Given I stand beside the "issi3" display of dealership "pdm"
    Then asking to testdrive "sultan" at display "issi3" of dealership "pdm" should be refused with "That vehicle is not sold here."
    And no test drive should have started

  @world @rejection
  Scenario: A test drive from across the map is refused
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    Then asking to testdrive "issi3" at display "issi3" of dealership "pdm" should be refused with "You are too far away."
    And no test drive should have started

  @world @rejection
  Scenario: A test drive at an invalid display is refused
    Given I stand beside the "issi3" display of dealership "pdm"
    Then asking to testdrive "issi3" at display "99" of dealership "pdm" should be refused with "Invalid location."
    And no test drive should have started

  @world @rejection
  Scenario: Offers are refused at a public dealership
    Given I remember my "bank" balance
    And I stand beside the "issi3" display of dealership "pdm"
    Then asking to offer "issi3" at display "issi3" of dealership "pdm" should be refused with "Offers can only be made at owned dealerships."
    And my "bank" balance should be unchanged

  @world @rejection
  Scenario: Offers at an unknown dealership are refused
    Given I stand beside the "issi3" display of dealership "pdm"
    Then asking to offer "issi3" at display "1" of dealership "fft_no_such_dealer" should be refused with "Unknown dealership."

  # -------------------------------------------------------------------------
  # Display swaps driven through kora_dealership:swap (server/creator.lua)
  # -------------------------------------------------------------------------

  @world @rejection
  Scenario: Swaps naming an unknown dealership, display or vehicle are refused
    Given I stand beside the "issi3" display of dealership "pdm"
    Then asking to swap "asbo" at display "1" of dealership "fft_no_such_dealer" should be refused with "Unknown dealership."
    And asking to swap "asbo" at display "0" of dealership "pdm" should be refused with "Unknown display vehicle."
    And asking to swap "asbo" at display "99" of dealership "pdm" should be refused with "Unknown display vehicle."
    And asking to swap "asbo" at display "1.5" of dealership "pdm" should be refused with "Unknown display vehicle."
    And asking to swap "sultan" at display "issi3" of dealership "pdm" should be refused with "That vehicle is not sold here."
    And asking to swap display "issi3" of dealership "pdm" to a number should be refused with "Invalid vehicle."
    And the "issi3" display of dealership "pdm" should show "issi3"

  @world @rejection
  Scenario: A swap from across the map is refused
    Given I stand at 1747.0 3273.7 41.6 facing 90.0
    Then asking to swap "asbo" at display "issi3" of dealership "pdm" should be refused with "You are too far away."
    And the "issi3" display of dealership "pdm" should show "issi3"

  @world @global
  Scenario: A swap ignores the case of the model and swapping back to the default resets it
    Given I stand beside the "issi3" display of dealership "pdm"
    When I swap the "issi3" display of dealership "pdm" to "ASBO" directly
    Then the "issi3" display of dealership "pdm" should show "asbo"
    When I swap the "issi3" display of dealership "pdm" to "issi3" directly
    Then the "issi3" display of dealership "pdm" should show "issi3"

  @world @global
  Scenario: Swapping one display leaves the others alone
    Given I stand beside the "club" display of dealership "pdm"
    When I swap the "club" display of dealership "pdm" to "panto" directly
    Then the "club" display of dealership "pdm" should show "panto"
    And the "issi3" display of dealership "pdm" should show "issi3"
    And the "regina" display of dealership "pdm" should show "regina"

  # -------------------------------------------------------------------------
  # Owner, employee and seller callbacks at a dealership nobody owns
  # (server/Management.lua authorize, server/sales.lua authorizeSale)
  # -------------------------------------------------------------------------

  @rejection
  Scenario Outline: The owner callback "<callback>" is refused at the public dealership
    Given I remember my "bank" balance
    Then the dealership callback "<callback>" for dealership "pdm" should be refused with "This dealership is not owned."
    And the dealership callback "<callback>" for dealership "fft_no_such_dealer" should be refused with "This dealership is not owned."
    And my "bank" balance should be unchanged

    Examples:
      | callback                         |
      | management:openOwnerManagement   |
      | management:addEmployee           |
      | management:removeEmployee        |
      | management:savePermissions       |
      | management:saveSettings          |
      | management:savePlacement         |
      | management:depositFunds          |
      | management:withdrawFunds         |
      | management:orderVehicle          |
      | management:getOffers             |
      | management:resolveOffer          |
      | sales:open                       |
      | sales:confirm                    |
