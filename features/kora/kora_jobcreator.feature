@kora @kora_jobcreator
Feature: kora_jobcreator businesses
  Admin-built businesses, exercised read-only against the shipped Burger Shot
  seed: the registry exports, staff presence and automatic duty at the
  perimeter, the job lock on a crafting bench, and the /jobcreator management
  console for a boss.

  Fixtures: the tester's job is set per scenario and restored afterwards. The
  tester is held in place inside the seed's zones (they are coordinate tests)
  and returned afterwards. The seed is first-boot only, so scenarios that use
  its layout first check that it has not been edited or deleted in-game.

  Not covered:
  - The refusal of /jobcreator to a trainee who manages nothing: it needs a
    tester who is not a job creator admin, and on the stock server.cfg the
    tester's admin and fft.use both come from group.admin (the tester's ace
    cannot be changed from a test, as in kora_crafting). The precondition step
    "I am not a job creator admin" stays defined for a run with such a tester.
  - Creating, editing or deleting a business or module: each change is
    broadcast to every client and written to the permanent business log, and a
    deleted seed is never re-seeded, so nothing created could be fully removed.
  - Crafting a recipe to completion: the Burger Shot ingredients and products
    are not defined as kora_core items on this server, so only the bench menu
    and its disabled recipes can be asserted.
  - Tills, stock, price changes and card payments: they open the inventory
    shop UI, charge another player and pay commission from a society account.
  - Stash and boss menu: they open kora_inventory and the boss menu UIs.
  - The panic button: it raises a dispatch alert for every officer online.
  - Automatic off-duty on leaving: the server only accepts it at the
    perimeter edge, which a teleporting tester never crosses.

  Background:
    Given resource "kora_jobcreator" is running

  @server
  Scenario: The Burger Shot seed is registered and listed under its job
    Then the Burger Shot seed business is registered
    And the business directory should list Burger Shot under its job

  @server @rejection
  Scenario: An unknown business is not in the registry and cannot be logged against
    Then the business registry should not know "fft_no_such_business"
    And a business log entry for the unknown business "fft_no_such_business" should be refused

  @world
  Scenario: An employee entering the perimeter is clocked on and counted as staff
    Given the Burger Shot seed business is unchanged
    And I am off duty as "burgershot" at grade 1
    And I remember how many Burger Shot staff are present
    When I stand inside the Burger Shot perimeter
    Then I should see a notification containing "You are now on duty"
    And I should be on duty
    And one more Burger Shot staff member should be present
    When I leave the Burger Shot perimeter
    Then the Burger Shot staff count should be back to what it was

  @world @rejection
  Scenario: Someone who does not work there is not clocked on or counted
    Given the Burger Shot seed business is unchanged
    And I am off duty as "taxi" at grade 1
    And I remember how many Burger Shot staff are present
    When I stand inside the Burger Shot perimeter
    Then I should not see a notification containing "You are now on duty"
    And I should be off duty
    And the Burger Shot staff count should not have changed

  @world @ui
  Scenario: An employee opens the grill and cannot cook without ingredients
    Given the Burger Shot seed business is unchanged
    And I should have no "burgermeat"
    And my job is "burgershot" at grade 1
    When I stand at the Burger Shot grill
    Then the interact selector should offer "Grill"
    When I choose "Grill" in the interact selector
    Then a menu titled "Grill" should open
    And the menu should list "Grilled beef"
    And the business bench recipe "Grilled beef" should be unavailable
    When I close the menu
    Then no menu should be open
    And no progress bar should be running

  @world @rejection
  Scenario: The grill is not offered to someone who does not work there
    Given the Burger Shot seed business is unchanged
    And my job is "taxi" at grade 1
    When I stand at the Burger Shot grill
    Then the business bench "Grill" should not be offered to me

  @ui
  Scenario: A Burger Shot manager opens the management console and refreshes it
    Given the Burger Shot seed business is registered
    And my job is "burgershot" at grade 4
    When I wait 1500 milliseconds
    And I run the command "jobcreator"
    Then the app "kora_jobcreator:management" should be open
    When I trigger the app action "businesses:select" on "burgershot"
    And I trigger the app action "businesses:refresh"
    Then the business console should answer with a "success" notice containing "Business data refreshed"
    When I close the app
    Then no app should be open

  # ---------------------------------------------------------------------------
  # Registry exports (server/admin.lua, server/state.lua). Read-only.
  # ---------------------------------------------------------------------------

  @server
  Scenario Outline: The Burger Shot seed carries each of its shipped modules
    Given the Burger Shot seed business is registered
    Then the Burger Shot seed should have a "<type>" module labelled "<label>"

    Examples:
      | type     | label          |
      | Zone     | Burger Shot    |
      | Blip     | Burger Shot    |
      | POS      | Front Till     |
      | Stash    | Walk-in Fridge |
      | Crafting | Grill          |
      | BossMenu | Manager Desk   |

  @server
  Scenario: The Grill offers the five Burger Shot recipes in order
    Given the Burger Shot seed business is unchanged
    Then the Burger Shot grill should offer the recipes "bs_beef, bs_slicedonion, bs_slicedpotato, bs_burger, bs_fries"

  @server
  Scenario: The business directory matches the registry and is sorted
    Given the Burger Shot seed business is registered
    Then the business directory entry for Burger Shot should match the registry
    And the business directory should be sorted by id
    And the business list for job "burgershot" should be sorted and only hold that job

  @server
  Scenario: A business returned by the registry is a copy
    Given the Burger Shot seed business is registered
    Then changing a copy of the Burger Shot business should not change the registry

  @server
  Scenario: Staff counts only name known businesses
    Then every business staff count should be a positive whole number

  @server @rejection
  Scenario Outline: The registry knows nothing under jobs without a business
    Then the business registry should not know "<name>"

    Examples:
      | name       |
      | police     |
      | unemployed |

  @server @rejection
  Scenario: A business log entry for an empty business id is refused
    Then a business log entry for the unknown business "" should be refused

  # ---------------------------------------------------------------------------
  # Presence and automatic duty (server/staff.lua)
  # ---------------------------------------------------------------------------

  @world
  Scenario Outline: Every Burger Shot grade is clocked on and counted at the perimeter
    Given the Burger Shot seed business is unchanged
    And I am off duty as "burgershot" at grade <grade>
    And I remember how many Burger Shot staff are present
    When I stand inside the Burger Shot perimeter
    Then I should see a notification containing "You are now on duty"
    And I should be on duty
    And one more Burger Shot staff member should be present
    When I leave the Burger Shot perimeter
    Then the Burger Shot staff count should be back to what it was

    Examples:
      | grade |
      | 2     |
      | 3     |
      | 4     |

  # setDuty answers false without a notice when the duty state already matches.
  @world
  Scenario: An employee already on duty is counted without a second clock-on
    Given the Burger Shot seed business is unchanged
    And I am on duty as "burgershot" at grade 1
    And I remember how many Burger Shot staff are present
    When I stand inside the Burger Shot perimeter
    Then one more Burger Shot staff member should be present
    And I should be on duty
    And I should not see a notification containing "You are now on duty"

  @world
  Scenario: Going off duty inside the perimeter stops being counted as staff
    Given the Burger Shot seed business is unchanged
    And I am off duty as "burgershot" at grade 1
    And I remember how many Burger Shot staff are present
    When I stand inside the Burger Shot perimeter
    Then one more Burger Shot staff member should be present
    When I go off duty through kora_core
    Then the Burger Shot staff count should be back to what it was

  @world
  Scenario: Changing job inside the perimeter stops being counted as staff
    Given the Burger Shot seed business is unchanged
    And I am off duty as "burgershot" at grade 1
    And I remember how many Burger Shot staff are present
    When I stand inside the Burger Shot perimeter
    Then one more Burger Shot staff member should be present
    Given my job is "mechanic" at grade 1
    Then the Burger Shot staff count should be back to what it was

  @world @rejection
  Scenario: An on-duty worker of another job is not counted as Burger Shot staff
    Given the Burger Shot seed business is unchanged
    And I am on duty as "mechanic" at grade 1
    And I remember how many Burger Shot staff are present
    When I stand inside the Burger Shot perimeter
    Then the Burger Shot staff count should not have changed
    And my job should be "mechanic"
    And I should be on duty

  # ---------------------------------------------------------------------------
  # The Grill bench (client/business.lua openCraftingMenu). Recipe labels and
  # ingredients are shared/recipes/burgershot.lua; none of the ingredients is
  # a kora_core item on this server, so every recipe is disabled.
  # ---------------------------------------------------------------------------

  @world @ui
  Scenario Outline: Every Grill recipe is listed and disabled without its ingredients
    Given the Burger Shot seed business is unchanged
    And I should have no "<ingredient>"
    And my job is "burgershot" at grade 2
    When I stand at the Burger Shot grill
    Then the interact selector should offer "Grill"
    When I choose "Grill" in the interact selector
    Then a menu titled "Grill" should open
    And the menu should list "<recipe>"
    And the business bench recipe "<recipe>" should be unavailable
    When I close the menu
    Then no progress bar should be running

    Examples:
      | recipe         | ingredient   |
      | Sliced onion   | onion        |
      | Sliced potato  | potato       |
      | Bleeder burger | beef         |
      | Fries          | slicedpotato |

  # ---------------------------------------------------------------------------
  # Other seed modules: which interactions each role is offered. Nothing is
  # selected (the till, fridge and desk open shop, inventory and boss menu UIs,
  # and the panic button alerts every officer).
  # ---------------------------------------------------------------------------

  @world @ui
  Scenario Outline: An employee at the Front Till is offered the staff options
    Given the Burger Shot "Front Till" module is where the seed put it
    And my job is "burgershot" at grade 1
    When I stand at the Burger Shot module "Front Till"
    Then the interact selector should offer "<option>"

    Examples:
      | option         |
      | Restock        |
      | Take a payment |
      | Panic button   |

  @world @rejection
  Scenario: A trainee at the Front Till is not offered the price editor
    Given the Burger Shot "Front Till" module is where the seed put it
    And my job is "burgershot" at grade 1
    When I stand at the Burger Shot module "Front Till"
    Then the business option "Set prices" should not be offered to me

  @world @ui
  Scenario: The manager at the Front Till is offered the price editor
    Given the Burger Shot "Front Till" module is where the seed put it
    And my job is "burgershot" at grade 4
    When I stand at the Burger Shot module "Front Till"
    Then the interact selector should offer "Set prices"

  @world @rejection
  Scenario Outline: A customer at the Front Till is offered no staff option
    Given the Burger Shot "Front Till" module is where the seed put it
    And my job is "mechanic" at grade 1
    When I stand at the Burger Shot module "Front Till"
    Then the business option "<option>" should not be offered to me

    Examples:
      | option         |
      | Restock        |
      | Set prices     |
      | Take a payment |
      | Panic button   |

  @world @ui
  Scenario: An employee at the Walk-in Fridge is offered the fridge
    Given the Burger Shot "Walk-in Fridge" module is where the seed put it
    And my job is "burgershot" at grade 1
    When I stand at the Burger Shot module "Walk-in Fridge"
    Then the interact selector should offer "Walk-in Fridge"

  @world @rejection
  Scenario: The Walk-in Fridge is not offered to someone who does not work there
    Given the Burger Shot "Walk-in Fridge" module is where the seed put it
    And my job is "mechanic" at grade 1
    When I stand at the Burger Shot module "Walk-in Fridge"
    Then the business option "Walk-in Fridge" should not be offered to me

  @world @ui
  Scenario: The manager is offered the Manager Desk
    Given the Burger Shot "Manager Desk" module is where the seed put it
    And my job is "burgershot" at grade 4
    When I stand at the Burger Shot module "Manager Desk"
    Then the interact selector should offer "Manager Desk"

  @world @rejection
  Scenario Outline: The Manager Desk is not offered below the manager grade
    Given the Burger Shot "Manager Desk" module is where the seed put it
    And my job is "burgershot" at grade <grade>
    When I stand at the Burger Shot module "Manager Desk"
    Then the business option "Manager Desk" should not be offered to me

    Examples:
      | grade |
      | 1     |
      | 3     |

  # ---------------------------------------------------------------------------
  # Management console (client/creator.lua actionHandler). Only navigation,
  # refresh and local debug actions run; nothing is created, edited or deleted.
  # ---------------------------------------------------------------------------

  @ui
  Scenario: Selecting Burger Shot opens its management view
    Given the Burger Shot seed business is registered
    And my job is "burgershot" at grade 4
    When I wait 1500 milliseconds
    And I run the command "jobcreator"
    Then the app "kora_jobcreator:management" should be open
    And the business console directory should list at least 1 business
    When I trigger the app action "businesses:select" on "burgershot"
    Then the business console should show the management view for "Burger Shot" of job "burgershot"

  @ui @rejection
  Scenario: The console refuses a business that does not exist
    Given the Burger Shot seed business is registered
    And my job is "burgershot" at grade 4
    When I wait 1500 milliseconds
    And I run the command "jobcreator"
    Then the app "kora_jobcreator:management" should be open
    When I trigger the app action "businesses:select" on "fft_no_such_business"
    Then the business console should answer with a "destructive" notice containing "That business is no longer available."

  @ui @rejection
  Scenario: The console refuses to refresh before a business is selected
    Given my job is "burgershot" at grade 4
    When I wait 1500 milliseconds
    And I run the command "jobcreator"
    Then the app "kora_jobcreator:management" should be open
    # client/creator.lua:505 declares businesses:refresh only on a selected
    # business's overview, so kora_lib refuses it before the handler runs.
    Then the app action "businesses:refresh" should be unavailable

  # The Modules tab and the debug tab exist for job creator admins only; the
  # tester is one on the stock server.cfg (see the last original scenario).
  @ui
  Scenario: An admin selects a seed module in the console
    Given the Burger Shot seed business is registered
    And my job is "burgershot" at grade 4
    When I wait 1500 milliseconds
    And I run the command "jobcreator"
    Then the app "kora_jobcreator:management" should be open
    When I trigger the app action "businesses:select" on "burgershot"
    And I trigger the app action "businesses:select-module" on "1"
    Then the business console should show the modules tab

  @ui @rejection
  Scenario Outline: The console refuses a module the business does not have
    Given the Burger Shot seed business is registered
    And my job is "burgershot" at grade 4
    When I wait 1500 milliseconds
    And I run the command "jobcreator"
    Then the app "kora_jobcreator:management" should be open
    When I trigger the app action "businesses:select" on "burgershot"
    And I trigger the app action "<action>" on "99"
    Then the business console should answer with a "destructive" notice containing "That module no longer exists."

    Examples:
      | action                   |
      | businesses:select-module |
      | businesses:remove-module |

  @ui
  Scenario: An admin toggles the local world debug and back
    Given the Burger Shot seed business is registered
    And my job is "burgershot" at grade 4
    When I wait 1500 milliseconds
    And I run the command "jobcreator"
    Then the app "kora_jobcreator:management" should be open
    When I trigger the app action "businesses:select" on "burgershot"
    Then toggling the business console world debug twice should switch it and switch it back
