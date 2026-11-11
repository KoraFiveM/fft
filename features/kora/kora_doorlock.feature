@kora @kora_doorlock
Feature: kora_doorlock door state, access and prompt
  Config.Doors ships empty and a fresh database has no doors, so the suite
  brings its own fixture: every "... is available" step creates the door
  "fft-test-door" ("FFT test door (safe to delete)") through the real
  exports.kora_doorlock:createDoor export and cleanup removes it again with
  exports.kora_doorlock:removeDoor. It sits on the vanilla Mission Row PD front
  door (v_ilev_ph_door01, left leaf) and is created unlocked, so the station
  stays open while a scenario runs. A leftover fixture from an interrupted run
  is removed first; a door with that id and any other label is never touched.
  The server step publishes the door to the tester's client in a player state
  bag.
  Creating and removing the fixture is pushed to every client and written to
  kora_doorlock_doors for the length of the scenario, so every scenario that
  uses it is tagged @global: players at the station see a door prompt appear,
  and when the lock state changes the door physically moves for them.
  The successful player toggle is authorised with kora_doorlock's own public
  doorAuthorization hook (limited to the tester and the fixture door, removed in
  cleanup): the fixture has no access rule of its own, and the tester's job is
  not changed. The refusal uses a real access rule instead: the fixture is
  restricted to police, or to ambulance when the tester is police.
  The toggle itself goes through the real useClosestDoor export, the server
  distance check and the server access decision. The E key is not pressed.
  Spare doors ("fft-test-door-spare" and the id made from the fixture label,
  "fft-test-door-safe-to-delete") are server-side fixtures with the same label,
  placed on the commented example leaves of kora_doorlock/config.lua:21-22, so
  they can be locked without locking the station. They are removed the same way.
  Access scenarios restrict the fixture with a real rule (job or gang grade,
  character, key item, passcode, door policy) and toggle it from the door.
  Config.UnrestrictedDoorsOpenToAll and Config.AdminsBypassDoorAccess are off in
  the shipped config; a server that turns them on fails the refusal scenarios.
  Not covered:
  - Lockpicking success: it needs the lockpick minigame, which is never forced.
  - ACE grants (doorlock.<id>): adding an ACE to the tester is a server-wide
    permission change.
  - Linked doors and categories: they are only reachable through the admin
    management callbacks of the /doorlocks app, which need an admin tester and
    write category rows.
  - The admin tools (/doorlocks, /adddoor, /newdoor, /importoxdoors): importing
    would copy every row of a real ox_doorlock table.
  - The toggle rate limit (10 per 5 s) and the server distance refusal: both
    need a raw client event the game never sends that way.
  - Door sounds, lock sprites and the physical door swing.

  Background:
    Given resource "kora_doorlock" is running

  @server @global
  Scenario: Door list is ordered and hides passcodes
    Given a doorlock door with a passcode is available
    Then the doorlock door list should include the chosen door
    And the doorlock door list should be ordered by id without duplicates
    And no listed doorlock door should reveal a passcode

  @server @global
  Scenario: A door is described by the public exports
    Given a doorlock door with a passcode is available
    Then the chosen door should be described with its lock state and position
    And the chosen door should not reveal a passcode
    And the chosen door should be found again by its label

  @server @rejection
  Scenario: Unknown door is not found and cannot be set
    Then the doorlock should know no door with the id "fft_no_such_door"
    And setting the lock state of the unknown door "fft_no_such_door" should be refused
    And the doorlock should know no door with the id "fft_no_such_door"

  @server @rejection @global
  Scenario: Invalid lock state is refused
    Given a doorlock door is available
    Then setting the chosen door to an invalid lock state should be refused and change nothing

  @rejection
  Scenario: Door exports do nothing away from any door
    Then using or picking the closest door should do nothing while no door is in reach

  @global
  Scenario: Export changes a door for the server, other resources and the client
    Given a doorlock door is available
    When the doorlock export flips the chosen door
    Then the chosen door should report the flipped lock state
    And the flip of the chosen door should have been announced to other resources
    And my game should show the chosen door in the lock state the server set

  @world @global
  Scenario: An authorised player toggles the door they stand at
    Given a doorlock door I can be let through is available
    And I stand at the chosen door
    Then the door prompt should offer what the chosen door allows
    When I use the closest door
    Then the chosen door should have changed lock state because of me
    And the door prompt should have switched for the chosen door

  @world @rejection @global
  Scenario: A player outside the door's group is refused
    Given a doorlock door restricted to a group I am not in is available
    And I stand at the chosen door
    When I use the closest door
    Then I should see a notification containing "You do not have access to this door."
    And the chosen door should have kept its lock state
    And my game should still show the chosen door in its original lock state

  # --- Creating doors -------------------------------------------------------

  @server @rejection
  Scenario Outline: createDoor refuses a definition that breaks a rule
    Then the doorlock should refuse to create a door with "<definition>"

    Examples:
      | definition                       |
      | a blank label                    |
      | a 97 character label             |
      | no model                         |
      | model 0                          |
      | coordinates that are not numbers |
      | a 0.4 metre reach                |
      | a 21 metre reach                 |
      | a negative auto-lock             |
      | an auto-lock over a day          |
      | a door rate of 11                |
      | a 129 character passcode         |
      | a negative group grade           |
      | groups that are not a table      |
      | 33 groups                        |
      | a character id that is a table   |
      | items with a gap                 |
      | item metadata that holds a table |
      | one leaf in a double door        |
      | three leaves in a double door    |
      | an upper case category           |
      | an unknown lockpick difficulty   |
      | a lockpick pin count of 13       |

  @server @global
  Scenario Outline: createDoor keeps a valid id in lower case and names the rest from the label
    When the doorlock export creates a spare door with the requested id "<requested>"
    Then the spare door should have the id "<id>"

    Examples:
      | requested                                                         | id                           |
      | fft-test-door-spare                                               | fft-test-door-spare          |
      | FFT-Test-Door-Spare                                               | fft-test-door-spare          |
      | fft test door spare!                                              | fft-test-door-safe-to-delete |
      | fft-test-door-spare-with-an-id-longer-than-sixty-four-characters1 | fft-test-door-safe-to-delete |

  @server @rejection @global
  Scenario: A door id that is in use cannot be created again
    Given a spare doorlock door is available
    Then creating the spare door again unlocked should be refused
    And the chosen door should be "locked"

  @server @global
  Scenario: Loose access rules are normalised when a door is created
    When the doorlock export creates a spare door with loose access rules
    Then the spare door should hold the normalised access rules

  @server @global
  Scenario: A double door sits between its two leaves
    When the doorlock export creates a spare double door
    Then the spare double door should sit between its two leaves
    And the chosen door should be "locked"

  @server @global
  Scenario: A door is found by a table holding its id
    Given a spare doorlock door is available
    Then the chosen door should be found by a table holding its id

  # --- Lock state, the setState event and auto-lock --------------------------

  @server @global
  Scenario: Numeric lock states unlock and lock a door again
    Given a spare doorlock door is available
    And I watch the chosen door for state changes
    When the doorlock export sets the chosen door to 0
    Then the chosen door should be "unlocked"
    And the doorlock should have announced the chosen door as "unlocked"
    When the doorlock export sets the chosen door to 1
    Then the chosen door should be "locked"
    And the doorlock should have announced the chosen door as "locked"

  @server @global
  Scenario: Other resources set a door through the kora_doorlock:setState event
    Given a spare doorlock door is available
    And I watch the chosen door for state changes
    When the kora_doorlock:setState event sets the chosen door to 0
    Then the chosen door should be "unlocked"
    And the doorlock should have announced the chosen door as "unlocked"
    When the kora_doorlock:setState event sets the chosen door to 1
    Then the chosen door should be "locked"

  @server @rejection @global
  Scenario Outline: The kora_doorlock:setState event ignores a state it does not know
    Given a spare doorlock door is available
    And I watch the chosen door for state changes
    Then the kora_doorlock:setState event with the state "<state>" should change nothing
    And the chosen door should be "locked"

    Examples:
      | state  |
      | open   |
      | 2      |
      | -1     |

  @server @global @slow
  Scenario: An unlocked door with auto-lock locks itself again
    Given a spare doorlock door that locks itself after 3000 milliseconds is available
    And I watch the chosen door for state changes
    When the doorlock export sets the chosen door to 0
    Then the chosen door should still be unlocked a moment later
    And the chosen door should lock itself within 8000 milliseconds

  # --- editDoor ------------------------------------------------------------

  @server @global
  Scenario: editDoor renames a door and changes its reach through the legacy keys
    Given a spare doorlock door is available
    When the doorlock export edits the chosen door with:
      """
      { "name": "FFT test door (safe to delete) renamed", "maxDistance": 3.5 }
      """
    Then the edit should have been accepted
    And the chosen door should be labelled with the renamed fixture label
    And the chosen door should have a reach of 3.5 metres
    And the chosen door should be "locked"

  @server @global
  Scenario: editDoor keeps the runtime lock state when the patch does not set one
    Given a spare doorlock door is available
    And I watch the chosen door for state changes
    When the doorlock export sets the chosen door to 0
    And the doorlock export edits the chosen door with:
      """
      { "distance": 3.0 }
      """
    Then the edit should have been accepted
    And the chosen door should be "unlocked"
    And the chosen door should have a reach of 3.0 metres

  @server @global
  Scenario: editDoor sets the lock state when the patch does
    Given a spare doorlock door is available
    And I watch the chosen door for state changes
    When the doorlock export edits the chosen door with:
      """
      { "locked": false }
      """
    Then the edit should have been accepted
    And the chosen door should be "unlocked"
    And the doorlock should have announced the chosen door as "unlocked"
    When the doorlock export edits the chosen door with:
      """
      { "state": 1 }
      """
    Then the edit should have been accepted
    And the chosen door should be "locked"

  @server @global
  Scenario: editDoor sets auto-lock in seconds and clears it with an empty value
    Given a spare doorlock door is available
    When the doorlock export edits the chosen door with:
      """
      { "autolock": 5 }
      """
    Then the edit should have been accepted
    And the chosen door should auto-lock after 5000 milliseconds
    When the doorlock export edits the chosen door with:
      """
      { "autolock": "" }
      """
    Then the edit should have been accepted
    And the chosen door should not auto-lock

  @server @global
  Scenario: editDoor never changes a door's id
    Given a spare doorlock door is available
    When the doorlock export edits the chosen door with:
      """
      { "id": "fft-test-door-moved", "distance": 3.0 }
      """
    Then the edit should have been accepted
    And the chosen door should have a reach of 3.0 metres
    And the doorlock should know no door with the id "fft-test-door-moved"

  @server @rejection @global
  Scenario: editDoor refuses an invalid patch and changes nothing
    Given a spare doorlock door is available
    When the doorlock export edits the chosen door with:
      """
      { "distance": 50, "name": "FFT test door (safe to delete) renamed" }
      """
    Then the edit should have been refused
    And the chosen door should still carry the fixture label
    And the chosen door should have a reach of 2.5 metres
    And editing the chosen door with a patch that is not a table should be refused

  @server @rejection
  Scenario: editDoor refuses an unknown door
    Then editing the unknown door "fft_no_such_door" should be refused

  # --- removeDoor ------------------------------------------------------------

  @server @rejection
  Scenario: Removing an unknown door is refused
    Then removing the unknown door "fft_no_such_door" should be refused with "That door is not configured."

  @global
  Scenario: A removed door is gone for the server and the client and cannot be removed twice
    Given a spare doorlock door is available
    Then my game should know the door "fft-test-door-spare"
    When the doorlock export removes the chosen door
    Then the doorlock should know no door with the id "fft-test-door-spare"
    And removing the chosen door again should be refused with "That door is not configured."
    And my game should forget the door "fft-test-door-spare"

  # --- Hooks -----------------------------------------------------------------

  @server @rejection
  Scenario Outline: A malformed doorAuthorization hook is refused
    Then registering a doorlock hook with "<problem>" should be refused

    Examples:
      | problem                         |
      | an unsupported event            |
      | a callback that is not callable |
      | options that are not a table    |
      | an empty name filter            |
      | a broken name filter pattern    |

  @server
  Scenario: A doorAuthorization hook is removed exactly once
    Then a doorlock hook with a name filter can be removed exactly once

  # --- Door policies -----------------------------------------------------------

  @server @global
  Scenario: The first door policy locks the door and records its owner
    Given a spare doorlock door is available
    And I watch the chosen door for state changes
    When the doorlock export sets the chosen door to 0
    And the doorlock export puts a door policy on the chosen door
    Then the chosen door should be "locked"
    And the chosen door should be owned by the fft door policy

  @server @rejection @global
  Scenario: A door policy needs a known door and a callable policy
    Given a spare doorlock door is available
    Then registering a door policy on the unknown door "fft_no_such_door" should be refused with "Door and callable policy are required."
    And registering a door policy that is not callable on the chosen door should be refused with "Door and callable policy are required."
    And the chosen door should have no door policy owner

  @server @global
  Scenario: Clearing a door policy locks the door and keeps the boundary
    Given a spare doorlock door is available
    And I watch the chosen door for state changes
    And the doorlock export puts a door policy on the chosen door
    When the doorlock export sets the chosen door to 0
    And the doorlock export clears the door policy of the chosen door
    Then the chosen door should be "locked"
    And the chosen door should be owned by the fft door policy

  @server @global
  Scenario: Releasing a door policy removes the owner, and only once
    Given a spare doorlock door is available
    And the doorlock export puts a door policy on the chosen door
    When the doorlock export releases the door policy of the chosen door
    Then the chosen door should have no door policy owner
    And releasing the door policy of the chosen door should be refused with "Door policy is not owned by this resource."
    And clearing the door policy of the chosen door should be refused with "Door policy is not owned by this resource."

  # --- Access at the door ------------------------------------------------------

  @world @global
  Scenario: A player with the door's job at the required grade toggles it
    Given my job is "police" at grade 2
    And a doorlock door for my job at my grade is available
    And I stand at the chosen door
    When I use the closest door
    Then the chosen door should have changed lock state because of me
    And the door prompt should have switched for the chosen door

  @world @rejection @global
  Scenario: A player one grade below the door's job grade is refused
    Given my job is "police" at grade 2
    And a doorlock door for my job one grade above mine is available
    And I stand at the chosen door
    When I use the closest door
    Then I should see a notification containing "You do not have access to this door."
    And the chosen door should have kept its lock state
    And my game should still show the chosen door in its original lock state

  @world @global
  Scenario: A player in the door's gang at the required grade toggles it
    Given my gang is "ballas" at grade 2
    And a doorlock door for my gang at my grade is available
    And I stand at the chosen door
    When I use the closest door
    Then the chosen door should have changed lock state because of me

  @world @global
  Scenario: A door listing my character opens for me
    Given a doorlock door for my character is available
    And I stand at the chosen door
    When I use the closest door
    Then the chosen door should have changed lock state because of me

  @world @rejection @global
  Scenario: A door listing another character is refused
    Given a doorlock door for another character is available
    And I stand at the chosen door
    When I use the closest door
    Then I should see a notification containing "You do not have access to this door."
    And the chosen door should have kept its lock state

  @world @global
  Scenario: A key item opens a door and is kept
    Given I hold 1 "lockpick"
    And a doorlock door opened by a "lockpick" key is available
    And I stand at the chosen door
    When I use the closest door
    Then the chosen door should have changed lock state because of me
    And the toggle of the chosen door should name the "lockpick" key
    And I should have at least 1 "lockpick"

  @world @global
  Scenario: A key item marked for removal is used up
    Given I hold 1 "lockpick"
    And I remember how many "lockpick" I have
    And a doorlock door that takes a "lockpick" key is available
    And I stand at the chosen door
    When I use the closest door
    Then the chosen door should have changed lock state because of me
    And I should have 1 fewer "lockpick" than before

  @world @rejection @global
  Scenario: A key door is refused without the key
    Given I should have no "lockpick"
    And a doorlock door opened by a "lockpick" key is available
    And I stand at the chosen door
    When I use the closest door
    Then I should see a notification containing "You do not have access to this door."
    And the chosen door should have kept its lock state

  @world @global
  Scenario: The right PIN opens a passcode door
    Given a doorlock door with the passcode "fft-pin-4711" is available
    And I stand at the chosen door
    When I use the closest door
    Then an input dialog should open
    When I submit the input dialog with:
      """
      { "passcode": "fft-pin-4711" }
      """
    Then the chosen door should have changed lock state because of me

  @world @rejection @global
  Scenario: A wrong PIN is refused with its own message
    Given a doorlock door with the passcode "fft-pin-4711" is available
    And I stand at the chosen door
    When I use the closest door
    Then an input dialog should open
    When I submit the input dialog with:
      """
      { "passcode": "fft-pin-0000" }
      """
    Then I should see a notification containing "Incorrect PIN. Please try again."
    And the chosen door should have kept its lock state

  @world @rejection @global
  Scenario: Cancelling the PIN dialog is an ordinary refusal
    Given a doorlock door with the passcode "fft-pin-4711" is available
    And I stand at the chosen door
    When I use the closest door
    Then an input dialog should open
    When I cancel the input dialog
    Then I should see a notification containing "You do not have access to this door."
    And I should not see a notification containing "Incorrect PIN"
    And the chosen door should have kept its lock state

  @world @rejection @global
  Scenario: A door without any access rule opens for nobody
    Given a doorlock door with no access rule is available
    And I stand at the chosen door
    When I use the closest door
    Then I should see a notification containing "You do not have access to this door."
    And the chosen door should have kept its lock state

  @world @global
  Scenario: A hook answering no does not take away access the rules give
    Given my job is "police" at grade 2
    And a doorlock door for my job at my grade is available
    And a doorlock hook answers no for me at the chosen door
    And I stand at the chosen door
    When I use the closest door
    Then the chosen door should have changed lock state because of me

  @world @rejection @global
  Scenario: A hook filtered to another door's name is not asked
    Given a doorlock door with no access rule is available
    And a doorlock hook for another door would let me through
    And I stand at the chosen door
    When I use the closest door
    Then I should see a notification containing "You do not have access to this door."
    And the chosen door should have kept its lock state

  @world @global
  Scenario: A door policy lets a player through a door with no other rule
    Given a doorlock door with no access rule is available
    And the chosen door is guarded by a door policy that lets me through
    And I stand at the chosen door
    When I use the closest door
    Then the chosen door should have changed lock state because of me
    And the door prompt should have switched for the chosen door

  @world @rejection @global
  Scenario: A door policy overrides a hook that would let the player through
    Given a doorlock door I can be let through is available
    And the chosen door is guarded by a door policy that refuses me
    And I stand at the chosen door
    When I use the closest door
    Then I should see a notification containing "You do not have access to this door."
    And the chosen door should have kept its lock state
    And my game should still show the chosen door in its original lock state

  # --- Lockpick, prompt and client exports -------------------------------------

  @world @rejection @global
  Scenario: Picking a locked door without a lockpick is refused by the server
    Given I should have no "lockpick"
    And a doorlock door that can be picked is available locked
    And I stand at the chosen door
    When I try to pick the closest door
    Then I should see a notification containing "You need a lockpick."
    And the chosen door should have kept its lock state

  @world @rejection @global
  Scenario: An unlocked pickable door cannot be picked
    Given a doorlock door that can be picked is available unlocked
    And I stand at the chosen door
    Then picking the closest door should be refused at once

  @world @rejection @global
  Scenario: A door without lockpicking cannot be picked
    Given a doorlock door with no access rule is available
    And I stand at the chosen door
    Then picking the closest door should be refused at once

  @world @global
  Scenario: A door with its prompt hidden shows no prompt
    Given a doorlock door without a prompt is available
    And I stand at the chosen door
    Then no text prompt should be shown

  @world @global
  Scenario: The qb-doorlock compatibility exports describe the door I stand at
    Given a doorlock door I can be let through is available
    And I stand at the chosen door
    Then the qb-doorlock compatibility exports should describe the chosen door

  @world @global
  Scenario: The client never holds a door's passcode
    Given a doorlock door with the passcode "fft-pin-4711" is available
    And I stand at the chosen door
    Then my game should not know the passcode of the chosen door
