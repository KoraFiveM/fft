@kora @kora_lib-playground
Feature: kora_lib-playground development command playground
  The playground gives developers a chat command for every kora_lib surface
  and a launcher app (HOME or F6) that runs the same commands. These scenarios
  run the real commands and answer the surfaces they open through kora_lib's
  test hook, at the NUI-callback level: no rendered control is clicked.

  The playground only prints what a menu, dialog or alert returned, so those
  scenarios assert that the expected surface opened with the expected content
  and closed when answered. The values kora_lib hands back to a caller are
  asserted in the kora_lib suite.

  Not covered: the four minigame commands (never forced), /fb (uploads a
  screenshot and posts to Discord), /testtemporary_access (grants roles),
  /testrevive, /testvehicle and /testlegion (world changes behind cooldowns),
  /testambulance_911, /testpolice_backup and /testchat_message (reach other
  players), /testclipboard, the zone, blip, entity and target fixtures (world
  and streaming dependent, print-only results) and the commands that merely
  forward to another resource's own interface, which that resource's suite owns.
  The dialogs of /fb, /testtemporary_access, /testvehicle and the zone creator
  are only opened and cancelled, never submitted. Waypoint commands restore the
  tester's previous waypoint, and the target toggle is put back as it was.

  Background:
    Given resource "kora_lib-playground" is running

  @ui
  Scenario: Notify command sends the sample success notification
    When I run the command "testnotify"
    Then I should see a notification containing "This is a test notification from kora_lib-playground."
    And the kora_lib notification titled "Test Notification" should have type "success"

  @ui
  Scenario: Menu command opens the sample menu and closes on a choice
    When I run the command "testmenu"
    Then a menu titled "Test Menu" should open
    And the menu should list "Option One"
    And the menu should list "Option Two"
    When I choose "Option Two" in the menu
    Then no menu should be open

  @ui
  Scenario: Nested menu command only settles on a leaf entry
    When I run the command "testnested"
    Then a menu titled "Nested menu" should open
    And the menu should list "Top-level action"
    And the menu should list "Unlock"
    And choosing "Vehicle" in the kora_lib menu should be refused as "submenu"
    # "Lock" sits two levels down: Vehicle > Doors > Lock.
    When I choose "Lock" in the menu
    Then no menu should be open

  @ui
  Scenario: Radial command opens the four-entry radial menu
    When I run the command "testradial"
    Then a menu should open
    And the open kora_lib menu should be a "openRadialMenu" menu
    And the menu should list "Inventory"
    And the menu should list "Settings"
    When I choose "Phone" in the menu
    Then no menu should be open

  @ui
  Scenario: Input command opens the every-field dialog and accepts valid values
    When I run the command "testinput"
    Then an input dialog should open
    And the kora_lib input dialog should be titled "Every field type"
    And the kora_lib input dialog should have the field "pin"
    And the kora_lib input dialog should have the field "colour"
    When I submit the input dialog with:
      """
      { "name": "Functional Tester", "amount": 2, "agree": true, "colour": "green" }
      """
    Then the kora_lib input dialog should be closed

  @ui @rejection
  Scenario: Input command keeps the dialog open without its required name
    When I run the command "testinput"
    Then an input dialog should open
    And submitting the kora_lib input dialog should be refused as "invalid" with:
      """
      { "name": "", "colour": "red" }
      """
    When I cancel the input dialog
    Then the kora_lib input dialog should be closed

  @ui
  Scenario Outline: Alert command opens the destructive confirmation
    When I run the command "testalert"
    Then a confirmation should open
    And the kora_lib confirmation should be titled "Delete everything?"
    When I <answer>
    Then the kora_lib confirmation should be closed

    Examples:
      | answer  |
      | confirm |
      | decline |

  @ui @rejection
  Scenario: Acknowledge command opens an alert that cannot be declined
    When I run the command "testalert_ack"
    Then a confirmation should open
    And the kora_lib confirmation should be titled "Acknowledge"
    And declining the kora_lib confirmation should be refused as locked
    When I confirm
    Then the kora_lib confirmation should be closed

  @ui
  Scenario: Progress bar command runs its eight second bar to the end
    # /testprogressbar: duration 8000 ms, movement and combat disabled meanwhile.
    When I run the command "testprogressbar"
    Then a progress bar labelled "Testing progress bar" should start
    And the progress bar should finish
    And no progress bar should be running

  @ui
  Scenario: Interact command offers only the available rows
    When I run the command "testinteract"
    Then the interact selector should offer "Inspect vehicle"
    And the interact selector should offer "Open storage"
    And the kora_lib interact selector should not offer "Unavailable row"
    When I choose "Open storage" in the interact selector
    Then the kora_lib interact selector should be closed

  @ui @rejection
  Scenario: Resource health command opens a read-only menu
    When I run the command "testresources"
    Then a menu titled "Resource health" should open
    And the menu should list "kora_lib"
    And choosing "kora_lib" in the kora_lib menu should be refused as "disabled"
    When I close the menu
    Then no menu should be open

  @ui
  Scenario: Launcher refuses undeclared actions and runs a declared command
    When I press the playground launcher key
    Then the app "kora_lib-playground:launcher" should be open
    And the app action "playground:run-command:fft_no_such_command" should be unavailable
    And the app action "fft:not-a-playground-action" should be unavailable
    # Declared leaf actions close the launcher before the command runs.
    When I trigger the app action "playground:run-command:testnotify"
    Then the app should answer with a "primary" notice containing "Running /testnotify"
    And I should see a notification containing "This is a test notification from kora_lib-playground."
    And no app should be open

  Scenario: Callback command reaches the server ping handler
    When I run the command "testcallback"
    Then the playground ping callback should answer "pong: hello from fft" to "hello from fft"

  @ui
  Scenario: Give item command adds the requested items
    Given I may use the playground item fixture for "water_bottle"
    And I remember how many "water_bottle" I have
    When I run the command "testgiveitem"
    Then an input dialog should open
    And the kora_lib input dialog should be titled "Give item"
    When I submit the input dialog with:
      """
      { "item": "water_bottle", "amount": 2 }
      """
    Then I should see a notification containing "2x water_bottle"
    And I should have 2 more "water_bottle" than before

  @ui @rejection
  Scenario: Give item command refuses an unknown item
    # Refused by the ACE gate or by kora_inventory, whichever applies to the
    # tester: either way the command reports the failure and grants nothing.
    When I run the command "testgiveitem"
    Then an input dialog should open
    When I submit the input dialog with:
      """
      { "item": "fft_no_such_item", "amount": 1 }
      """
    Then I should see a notification containing "Could not give item"
    And I should not see a notification containing "Item given"
    And I should have no "fft_no_such_item"

  # ---------------------------------------------------------------------------
  # Basic kora_lib surfaces: the remaining answers and refusals
  # ---------------------------------------------------------------------------

  @ui
  Scenario: Closing the sample menu cancels it
    When I run the command "testmenu"
    Then a menu titled "Test Menu" should open
    And the open kora_lib menu should have 2 entries
    And the open kora_lib menu entry "Option One" should be described as "The first option"
    When I close the menu
    Then no menu should be open

  @ui @rejection
  Scenario: Nested menu refuses every branch row and settles on the second branch
    When I run the command "testnested"
    Then a menu titled "Nested menu" should open
    And choosing "Player" in the kora_lib menu should be refused as "submenu"
    And choosing "Doors" in the kora_lib menu should be refused as "submenu"
    And choosing "fft_no_such_entry" in the kora_lib menu should be refused as "not_visible"
    When I choose "Heal" in the menu
    Then no menu should be open

  @ui @rejection
  Scenario: Nested radial drills two levels and refuses its branches
    When I run the command "testradial_nested"
    Then a menu should open
    And the open kora_lib menu should be a "openRadialMenu" menu
    And the menu should list "Quick action"
    And the menu should list "Roll down"
    And choosing "Vehicle" in the kora_lib menu should be refused as "submenu"
    And choosing "Windows" in the kora_lib menu should be refused as "submenu"
    When I choose "Roll up" in the menu
    Then no menu should be open

  @ui
  Scenario: Nested radial settles on its top-level leaf
    When I run the command "testradial_nested"
    Then a menu should open
    When I choose "Quick action" in the menu
    Then no menu should be open

  @ui @rejection
  Scenario: Paged radial lists fifteen options and refuses the disabled one
    When I run the command "testradial_paged"
    Then a menu should open
    And the open kora_lib menu should be a "openRadialMenu" menu
    And the open kora_lib menu should have 15 entries
    And the open kora_lib menu entry "Option 15" should be described as "Paged radial option 15 of 15"
    And choosing "Option 8" in the kora_lib menu should be refused as "disabled"
    When I choose "Option 12" in the menu
    Then no menu should be open

  @ui
  Scenario: Closing the radial menu cancels it
    When I run the command "testradial"
    Then a menu should open
    And the open kora_lib menu should have 4 entries
    When I close the menu
    Then no menu should be open

  @ui @rejection
  Scenario Outline: Input command refuses <case>
    When I run the command "testinput"
    Then an input dialog should open
    And submitting the kora_lib input dialog should be refused as "<code>" with:
      """
      <values>
      """
    When I cancel the input dialog
    Then the kora_lib input dialog should be closed

    Examples:
      | case                     | code        | values                                                  |
      | an empty required select | invalid     | { "name": "Functional Tester", "colour": "" }          |
      | a missing required name  | invalid     | { "colour": "blue" }                                    |
      | a field it does not have | not_visible | { "name": "Functional Tester", "fft_unknown": "x" }     |

  @ui
  Scenario: Input command dialog offers every field type
    When I run the command "testinput"
    Then an input dialog should open
    And the kora_lib input dialog should have the field "name"
    And the kora_lib input dialog should have the field "plain"
    And the kora_lib input dialog should have the field "notes"
    And the kora_lib input dialog should have the field "amount"
    And the kora_lib input dialog should have the field "volume"
    And the kora_lib input dialog should have the field "fine"
    And the kora_lib input dialog should have the field "agree"
    When I cancel the input dialog
    Then the kora_lib input dialog should be closed

  @ui
  Scenario: Progress bar cancel command stops the running bar early
    When I run the command "testprogressbar"
    Then a progress bar labelled "Testing progress bar" should start
    When I run the command "testprogressbar_cancel"
    Then the progress bar should stop within 3000 milliseconds

  @ui
  Scenario: Progress bar cancel command without a bar changes nothing
    When I run the command "testprogressbar_cancel"
    Then no progress bar should be running

  @ui
  Scenario: Interact command runs the first available row
    When I run the command "testinteract"
    Then the interact selector should offer "Inspect vehicle"
    When I choose "Inspect vehicle" in the interact selector
    Then the kora_lib interact selector should be closed

  @ui
  Scenario: Interact clear command closes an open selector
    When I run the command "testinteract"
    Then the interact selector should offer "Open storage"
    When I run the command "testinteract_clear"
    Then the kora_lib interact selector should be closed

  # ---------------------------------------------------------------------------
  # Dialogs that are only opened and cancelled
  # ---------------------------------------------------------------------------

  @ui
  Scenario Outline: <command> opens the "<title>" dialog and cancels cleanly
    Given resource "<resource>" is running
    When I run the command "<command>"
    Then an input dialog should open
    And the kora_lib input dialog should be titled "<title>"
    And the kora_lib input dialog should have the field "<field>"
    When I cancel the input dialog
    Then the kora_lib input dialog should be closed

    Examples:
      | command                     | resource            | title                        | field    |
      | testgiveitem                | kora_lib-playground | Give item                    | amount   |
      | testzone_create             | kora_lib-playground | In-world zone creator        | type     |
      | testvehicle                 | kora_lib-playground | Spawn vehicle                | model    |
      | testclothing_shop           | kora_lib-playground | Open clothing shop           | shop     |
      | fb                          | kora_lib-playground | Send feedback                | subject  |
      | testtemporary_access        | kora_admin          | Grant temporary test access  | minutes  |
      | testtemporary_access_revoke | kora_admin          | Revoke temporary test access | role     |
      | testambulance_911           | kora_ambulance      | EMS alert                    | message  |

  @ui
  Scenario: Feedback dialog has its four fields
    When I run the command "fb"
    Then an input dialog should open
    And the kora_lib input dialog should have the field "category"
    And the kora_lib input dialog should have the field "subject"
    And the kora_lib input dialog should have the field "description"
    And the kora_lib input dialog should have the field "steps"
    When I cancel the input dialog
    Then the kora_lib input dialog should be closed
    And I should not see a notification containing "Compiling your feedback report"

  @ui
  Scenario: Cancelling the give item dialog grants nothing
    Given I may use the playground item fixture for "water_bottle"
    And I remember how many "water_bottle" I have
    When I run the command "testgiveitem"
    Then an input dialog should open
    When I cancel the input dialog
    Then the kora_lib input dialog should be closed
    And I should not see a notification containing "Item given"
    And I should have 0 more "water_bottle" than before

  # ---------------------------------------------------------------------------
  # playground:giveItem (server.lua): ACE gate, item and amount validation
  # ---------------------------------------------------------------------------

  @ui @rejection
  Scenario: Give item dialog with a zero amount is refused by the server
    Given I may use the playground item fixture for "water_bottle"
    And I remember how many "water_bottle" I have
    When I run the command "testgiveitem"
    Then an input dialog should open
    When I submit the input dialog with:
      """
      { "item": "water_bottle", "amount": 0 }
      """
    Then I should see a notification containing "amount must be a positive integer"
    And the kora_lib notification titled "Could not give item" should have type "error"
    And I should have 0 more "water_bottle" than before

  Scenario: Give item callback adds exactly the requested amount
    Given I may use the playground item fixture for "water_bottle"
    And I remember how many "water_bottle" I have
    Then asking the playground to give 3 "water_bottle" should succeed
    And I should have 3 more "water_bottle" than before

  @rejection
  Scenario Outline: Give item callback refuses the amount "<amount>"
    Given I may use the playground item fixture for "water_bottle"
    And I remember how many "water_bottle" I have
    Then asking the playground to give "water_bottle" with the amount "<amount>" should be refused with "amount must be a positive integer"
    And I should have 0 more "water_bottle" than before

    Examples:
      | amount |
      | 0      |
      | -3     |
      | 1.5    |
      | abc    |
      |        |

  @rejection
  Scenario Outline: Give item callback refuses the numeric amount <amount>
    Given I may use the playground item fixture for "water_bottle"
    And I remember how many "water_bottle" I have
    Then asking the playground to give "water_bottle" with the number <amount> should be refused with "amount must be a positive integer"
    And I should have 0 more "water_bottle" than before

    Examples:
      | amount |
      | 0.0    |
      | 2.5    |
      | -1.0   |

  @rejection
  Scenario: Give item callback refuses an empty or non-text item name
    Given I may use the playground item fixture for "water_bottle"
    Then asking the playground to give "" with the amount "1" should be refused with "invalid item name"
    And asking the playground to give the number 42 as an item should be refused with "invalid item name"

  # Fixture commands from fixtureCommands in client.lua; every one gives 1.
  @ui
  Scenario Outline: <command> adds one <item>
    Given resource "kora_inventory" is running
    And I may use the playground item fixture for "<item>"
    And I remember how many "<item>" I have
    When I run the command "<command>"
    Then I should see a notification containing "Added <label>"
    And I should have 1 more "<item>" than before

    Examples:
      | command                 | item           | label          |
      | testmedical_bandage     | bandage        | bandage        |
      | testmedical_ifak        | ifak           | IFAK           |
      | testmedical_painkillers | painkillers    | painkillers    |
      | testpolice_cuffs        | handcuffs      | handcuffs      |
      | testpolice_armor        | armor          | body armour    |

  # The drug fixtures name qb-drugs items (client.lua fixtureCommands). qb-drugs
  # is not installed and kora_core's item catalogue has none of them, so the
  # give-item callback refuses them as unknown and nothing is added.
  @ui @rejection
  Scenario Outline: <command> reports that <item> is not a catalogue item
    Given resource "kora_inventory" is running
    And I may use the playground item fixture for "<item>"
    And I remember how many "<item>" I have
    When I run the command "<command>"
    Then I should see a notification containing "Could not add <label>: unknown item"
    And I should have 0 more "<item>" than before

    Examples:
      | command                 | item           | label          |
      | testdrugs_weed          | weed_baggie    | weed baggie    |
      | testdrugs_seed          | weed_seed      | weed seed      |
      | testdrugs_meth          | meth_bag       | meth bag       |
      | testdrugs_precursor     | meth_precursor | meth precursor |

  Scenario: SQL statistics callback answers a permitted tester
    Given resource "kora_sql" is running
    And I have the playground permission
    Then the playground SQL statistics callback should answer with live statistics

  # ---------------------------------------------------------------------------
  # Read-only diagnostic menus (openReadOnlyMenu: every entry disabled)
  # ---------------------------------------------------------------------------

  @ui
  Scenario: Resource health menu matches the live resource states
    When I run the command "testresources"
    Then a menu titled "Resource health" should open
    And the open kora_lib menu should have 36 entries
    And every entry of the open kora_lib menu should be disabled
    And the resource health menu should match the live resource states

  @ui
  Scenario: Session resources menu explains why it launches nothing
    Given resource "kora_loading" is running
    When I run the command "testsession_info"
    Then a menu titled "Session resources" should open
    And the open kora_lib menu should have 3 entries
    And every entry of the open kora_lib menu should be disabled
    And the open kora_lib menu entry "kora_loading" should be described as "started - test by reconnecting through the loading screen"
    And the open kora_lib menu entry "Why these do not launch here" should be described as "Opening either flow mid-session can unload or hide the active character"
    When I close the menu
    Then no menu should be open

  @ui
  Scenario: Core player snapshot shows my job on duty
    Given resource "kora_core" is running
    And I am on duty as "police" at grade 1
    When I run the command "testcore_player"
    Then a menu titled "Core player snapshot" should open
    And the open kora_lib menu should have 6 entries
    And every entry of the open kora_lib menu should be disabled
    And the core player snapshot should show my job and duty

  @ui
  Scenario: Core player snapshot shows my job off duty
    Given I am off duty as "police" at grade 1
    When I run the command "testcore_player"
    Then a menu titled "Core player snapshot" should open
    And the core player snapshot should show my job and duty

  @ui
  Scenario: Core registry menu matches the kora_core record counts
    Given resource "kora_core" is running
    When I run the command "testcore_registries"
    Then a menu titled "Core registries" should open
    And the open kora_lib menu should have 6 entries
    And every entry of the open kora_lib menu should be disabled
    And the core registry menu should match the kora_core record counts

  @ui
  Scenario: SQL statistics command opens the live stats menu
    Given resource "kora_sql" is running
    And I have the playground permission
    When I run the command "testsql_stats"
    Then a menu titled "kora_sql live stats" should open
    And the open kora_lib menu should have 4 entries
    And every entry of the open kora_lib menu should be disabled
    And the menu should list "sql_queries"
    And the menu should list "sql_flushes"
    And the open kora_lib menu entry "sql_fingerprints" should be described as "Distinct normalized query shapes"

  @ui
  Scenario: HUD source state shows an open gate on foot
    Given resource "kora_hud" is running
    And I am on foot
    When I run the command "testhud_state"
    Then a menu titled "HUD source state" should open
    And the open kora_lib menu should have 4 entries
    And every entry of the open kora_lib menu should be disabled
    And the menu should list "HUD gate: open"
    And the menu should list "Vehicle HUD inactive"
    And the open kora_lib menu entry "hud_vehicle" should be described as "Enter a vehicle to test speed, fuel and headlights"

  @ui
  Scenario: Police state menu shows I am not handcuffed
    Given resource "kora_police" is running
    When I run the command "testpolice_state"
    Then a menu titled "Police state" should open
    And the open kora_lib menu should have 2 entries
    And every entry of the open kora_lib menu should be disabled
    And the menu should list "Handcuffed: false"
    And the open kora_lib menu entry "police_cuffed" should be described as "Live kora_police client export"

  @ui
  Scenario: Voice status menu lists the proximity mode and radio channel
    Given resource "kora_voice" is running
    When I run the command "testvoice_status"
    Then a menu titled "Voice status" should open
    And the open kora_lib menu should have 2 entries
    And every entry of the open kora_lib menu should be disabled
    And the menu should list "voice_mode"
    And the menu should list "voice_radio"

  @ui
  Scenario: Small resources menu lists its manual checks
    Given resource "kora_utils" is running
    When I run the command "testsmallresources"
    Then a menu titled "Small resources checks" should open
    And the open kora_lib menu should have 4 entries
    And every entry of the open kora_lib menu should be disabled
    And the menu should list "Weapon recoil"
    And the menu should list "Idle camera"
    And the menu should list "Dispatch services"

  # openGuide() in client.lua: one disabled entry titled like the menu.
  @ui
  Scenario Outline: <command> opens the "<title>" guide
    Given resource "<resource>" is running
    When I run the command "<command>"
    Then a menu titled "<title>" should open
    And the open kora_lib menu should have 1 entries
    And every entry of the open kora_lib menu should be disabled
    And the menu should list "<title>"

    Examples:
      | command              | resource         | title             |
      | testweather_guide    | kora_weathersync | Weather sync test |
      | testdispatch_guide   | kora_dispatch    | Dispatch test     |
      | testdealership_guide | kora_dealership  | Dealership test   |
      | testgarage_guide     | kora_garages     | Garage test       |

  # requireResource() in client.lua: a missing resource gets an error notice.
  @ui @rejection
  Scenario: A guide for a resource that is not installed reports it
    Given the resource "kora_mechanic" is not installed
    When I run the command "testmechanic_guide"
    Then I should see a notification containing "kora_mechanic is not started"
    And no menu should be open

  @ui @rejection
  Scenario: Fuel status on foot asks for a vehicle
    Given resource "kora_fuel" is running
    And I am on foot
    When I run the command "testfuel_status"
    Then I should see a notification containing "Enter a vehicle first to inspect fuel or charge."

  # ---------------------------------------------------------------------------
  # Waypoints (coordinates from client.lua)
  # ---------------------------------------------------------------------------

  @ui
  Scenario Outline: <command> routes to <place>
    Given resource "<resource>" is running
    And my map waypoint is restored afterwards
    When I run the command "<command>"
    Then I should see a notification containing "<notice>"
    And my map waypoint should be at <x> <y>

    Examples:
      | command                | resource       | place          | notice                                       | x    | y     |
      | testbank_waypoint      | kora_banking   | Fleeca Bank    | Waypoint set to Fleeca Bank                  | 149  | -1041 |
      | testambulance_waypoint | kora_ambulance | Pillbox        | Waypoint set to Pillbox Hospital             | 299  | -585  |
      | testpolice_waypoint    | kora_police    | MRPD           | Waypoint set to MRPD                         | 442  | -980  |
      | testscrapyard_route    | kora_scrapyard | the scrapyard  | Waypoint set to the scrapyard delivery point. | 2352 | 3133  |

  # kora_drugs declares `provide 'qb-drugs'`; the command checks the qb-drugs name.
  @ui
  Scenario Outline: Drug route menu sets the <label> waypoint
    Given resource "kora_drugs" is running
    And my map waypoint is restored afterwards
    When I run the command "testdrugs_route"
    Then a menu titled "Drug route waypoint" should open
    And the open kora_lib menu should have 2 entries
    When I choose "<label>" in the menu
    Then I should see a notification containing "Waypoint set: <notice>"
    And my map waypoint should be at <x> <y>

    Examples:
      | label        | notice       | x    | y     |
      | Coca harvest | coca harvest | 1474 | -2644 |
      | Cocaine lab  | cocaine lab  | 744  | -1906 |

  @ui
  Scenario: Cancelling the drug route menu leaves my waypoint alone
    Given resource "kora_drugs" is running
    And my map waypoint is restored afterwards
    When I run the command "testdrugs_route"
    Then a menu titled "Drug route waypoint" should open
    When I close the menu
    Then no menu should be open
    And I should not see a notification containing "Waypoint set:"

  # ---------------------------------------------------------------------------
  # Full resource catalogue (/testresource_catalogue)
  # ---------------------------------------------------------------------------

  @ui
  Scenario: Catalogue offers only the started resources
    When I run the command "testresource_catalogue"
    Then a menu titled "All test-server resources" should open
    And the open kora_lib menu should have 36 entries
    And the catalogue menu should only offer started resources
    When I close the menu
    Then no menu should be open

  @ui
  Scenario: Choosing kora_theme in the catalogue shows its brief and runs its check
    Given resource "kora_theme" is running
    When I run the command "testresource_catalogue"
    Then a menu titled "All test-server resources" should open
    When I choose "kora_theme" in the menu
    Then I should see a notification containing "Open several NUI screens and check theme colours, spacing and dark-mode rendering."
    And I should see a notification containing "This is a test notification from kora_lib-playground."

  @ui
  Scenario: Choosing the playground in the catalogue opens resource health
    When I run the command "testresource_catalogue"
    Then a menu titled "All test-server resources" should open
    When I choose "kora_lib-playground" in the menu
    Then I should see a notification containing "Use this catalogue, then restart only the playground"
    And a menu titled "Resource health" should open
    And every entry of the open kora_lib menu should be disabled

  # ---------------------------------------------------------------------------
  # Launcher
  # ---------------------------------------------------------------------------

  @ui
  Scenario: Launcher is titled and lists its six sections
    When I press the playground launcher key
    Then the app "kora_lib-playground:launcher" should be open
    And the playground launcher should be titled "kora_lib Playground"
    And the playground launcher should offer the section "server_framework" with 7 entries
    And the playground launcher should offer the section "player_systems" with 6 entries
    And the playground launcher should offer the section "emergency_jobs" with 2 entries
    And the playground launcher should offer the section "world_interaction" with 6 entries
    And the playground launcher should offer the section "ui_gameplay" with 3 entries
    And the playground launcher should offer the section "developer_tools" with 5 entries

  @ui
  Scenario: Pressing the launcher key again closes it
    When I press the playground launcher key
    Then the app "kora_lib-playground:launcher" should be open
    When I press the playground launcher key again
    Then no app should be open

  @ui @rejection
  Scenario Outline: Launcher refuses to run the branch "<branch>"
    When I press the playground launcher key
    Then the app "kora_lib-playground:launcher" should be open
    And the app action "playground:run-command:<branch>" should be unavailable
    And the app action "playground:run-command:" should be unavailable

    Examples:
      | branch           |
      | core             |
      | emergency_jobs   |
      | temporary_access |

  @ui
  Scenario: Launcher runs a waypoint command after closing
    Given resource "kora_police" is running
    And my map waypoint is restored afterwards
    When I press the playground launcher key
    Then the app "kora_lib-playground:launcher" should be open
    When I trigger the app action "playground:run-command:testpolice_waypoint"
    Then the app should answer with a "primary" notice containing "Running /testpolice_waypoint"
    And no app should be open
    And I should see a notification containing "Waypoint set to MRPD"
    And my map waypoint should be at 442 -980

  @ui
  Scenario: Launcher runs a read-only menu command
    When I press the playground launcher key
    Then the app "kora_lib-playground:launcher" should be open
    When I trigger the app action "playground:run-command:testsession_info"
    Then the app should answer with a "primary" notice containing "Running /testsession_info"
    And a menu titled "Session resources" should open

  # testtarget_toggle is keepOpen: it runs inside the shell and refreshes the
  # navigation instead of closing. Running it twice restores the state.
  @ui
  Scenario: Launcher target toggle flips targeting and back without closing
    Given resource "kora_target" is running
    And I remember whether targeting is enabled
    When I press the playground launcher key
    Then the app "kora_lib-playground:launcher" should be open
    When I trigger the app action "playground:run-command:testtarget_toggle"
    Then targeting should be the opposite of what I remembered
    And the app "kora_lib-playground:launcher" should be open
    When I trigger the app action "playground:run-command:testtarget_toggle"
    Then targeting should be as I remembered
    And the app "kora_lib-playground:launcher" should be open

  @ui
  Scenario: Target toggle command flips targeting and back
    Given resource "kora_target" is running
    And I remember whether targeting is enabled
    When I run the command "testtarget_toggle"
    Then targeting should be the opposite of what I remembered
    When I run the command "testtarget_toggle"
    Then targeting should be as I remembered

  # Every launcher entry runs ExecuteCommand(<id>), so it must be a registered command.
  Scenario Outline: Launcher entry <command> is a registered playground command
    Then the playground should register the command "<command>"

    Examples:
      | command                |
      | testresources          |
      | testresource_catalogue |
      | testcore_player        |
      | testcore_registries    |
      | testsql_stats          |
      | testsql_ping           |
      | testsession_info       |
      | testhud_state          |
      | testbank_waypoint      |
      | testdrugs_route        |
      | testdrugs_weed         |
      | testmedical_ifak       |
      | testpolice_state       |
      | testtarget_toggle      |
      | testsmallresources     |
      | testradial_paged       |
      | testcache              |
