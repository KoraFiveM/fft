@kora @kora_target
Feature: kora_target option visibility, gating and selection
  Each scenario registers a temporary box zone on the ground 1.5 m in front of
  the test character through kora_target's public exports, drives the real
  targeting state machine through kora_target's FFT hook, and removes the zone
  again in cleanup. The character is not teleported: stand on open, level
  ground, on foot, away from other target zones.

  A gated option is only reported hidden while an always-allowed control option
  in the same zone is the single visible one, so a missed aim fails the
  scenario instead of passing it.

  Job, gang and item filters are a qb-target feature, so those scenarios
  register through the `qb-target` compatibility exports that kora_target
  provides. The native API only knows `canInteract`.

  ox_target scenarios register through the `ox_target` compatibility exports.
  In-vehicle scenarios register the zone on foot and then sit the character in
  a temporary car; the zone point then lies under the car's bonnet, which the
  targeting ray ignores.

  Not covered: entity, model, bone and global registrations against real world
  entities (global registrations would add options to every entity of a type),
  the progress-bar and cuffed busy gates, the downed gate, and
  registerServerAction (its registry is shared by every resource on the server
  and has no unregister call).

  Background:
    Given resource "kora_target" is running

  @world
  Scenario: A single zone option is visible and runs once when selected
    Given a temporary kora_target box zone ahead of me offers:
      """
      [{ "label": "FFT probe inspect" }]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe inspect"
    When I target "FFT probe inspect"
    Then the kora_target option "FFT probe inspect" should have run 1 times

  @world @rejection
  Scenario: An option whose canInteract refuses is hidden and cannot be selected
    Given a temporary kora_target box zone ahead of me offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe gated", "gate": "armed" }
      ]
      """
    And the kora_target gate "armed" is closed
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"
    And the kora_target option "FFT probe gated" should have run 0 times

  @world
  Scenario: An option appears once its canInteract allows it and hides again afterwards
    Given a temporary kora_target box zone ahead of me offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe gated", "gate": "armed" }
      ]
      """
    And the kora_target gate "armed" is closed
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"
    When the kora_target gate "armed" is open
    Then my temporary target zone should offer exactly 2 options
    When the kora_target gate "armed" is closed
    Then my temporary target zone should show only "FFT probe control"

  @world @ui
  Scenario: Several visible options open the interact selector and only the chosen one runs
    Given a temporary kora_target box zone ahead of me offers:
      """
      [
        { "label": "FFT probe first" },
        { "label": "FFT probe second" },
        { "label": "FFT probe locked", "gate": "armed" }
      ]
      """
    And the kora_target gate "armed" is closed
    When I look at my temporary target zone
    Then my temporary target zone should offer exactly 2 options
    When I open the target selector on my temporary zone
    Then the interact selector should offer "FFT probe first"
    And the interact selector should offer "FFT probe second"
    And the target selector should not list "FFT probe locked"
    When I choose "FFT probe second" in the interact selector
    Then the kora_target option "FFT probe second" should have run 1 times
    And the kora_target option "FFT probe first" should have run 0 times
    And the kora_target option "FFT probe locked" should have run 0 times

  @world @rejection
  Scenario: An option is hidden beyond its own distance
    Given a temporary kora_target box zone ahead of me offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe close up", "distance": 0.3 }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"
    And the kora_target option "FFT probe close up" should have run 0 times

  @world
  Scenario: A removed zone is no longer targetable and cannot be removed twice
    Given a temporary kora_target box zone ahead of me offers:
      """
      [{ "label": "FFT probe inspect" }]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe inspect"
    When I remove my temporary target zone
    Then my temporary target zone should not be targetable
    And removing my temporary target zone again should be refused

  @world @rejection
  Scenario: Targeting cannot start while kora_target is switched off
    Given a temporary kora_target box zone ahead of me offers:
      """
      [{ "label": "FFT probe inspect" }]
      """
    And I look at my temporary target zone
    And my temporary target zone should show only "FFT probe inspect"
    When kora_target is switched off for this scenario
    Then kora_target should report enabled "false"
    And kora_target should report it is not targeting
    And starting to target should be blocked
    And the kora_target option "FFT probe inspect" should have run 0 times
    When kora_target is switched back on
    Then kora_target should report enabled "true"
    And starting to target should work
    And my temporary target zone should show only "FFT probe inspect"

  @world @rejection
  Scenario: A job-restricted legacy option is hidden from other jobs
    Given my job is "unemployed" at grade 0
    And a temporary legacy qb-target box zone ahead of me offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe mechanic", "job": "mechanic" }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"

  @world
  Scenario: A job-restricted legacy option is visible to that job and runs
    Given my job is "mechanic" at grade 0
    And a temporary legacy qb-target box zone ahead of me offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe mechanic", "job": "mechanic" }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should offer exactly 2 options
    When I target "FFT probe mechanic"
    Then the kora_target option "FFT probe mechanic" should have run 1 times
    And the kora_target option "FFT probe control" should have run 0 times

  @world @rejection
  Scenario: A minimum job grade hides a legacy option from lower grades
    Given my job is "mechanic" at grade 0
    And a temporary legacy qb-target box zone ahead of me offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe boss", "job": { "mechanic": 2 } }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"
    # Legacy grade levels are zero-based: kora grade 3 (Boss) is legacy level 2.
    When my job is "mechanic" at grade 3
    Then my temporary target zone should offer exactly 2 options

  @world
  Scenario: A gang-restricted legacy option follows gang membership
    Given a temporary legacy qb-target box zone ahead of me offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe ballas", "gang": "ballas" }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"
    When my gang is "ballas" at grade 0
    Then my temporary target zone should offer exactly 2 options

  @world
  Scenario: An item-restricted legacy option follows the inventory
    Given a temporary legacy qb-target box zone ahead of me offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe pick lock", "item": "lockpick" }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"
    When I hold 1 "lockpick"
    Then my temporary target zone should offer exactly 2 options
    When I target "FFT probe pick lock"
    Then the kora_target option "FFT probe pick lock" should have run 1 times

  @world
  Scenario: A removed legacy zone is no longer targetable
    Given a temporary legacy qb-target box zone ahead of me offers:
      """
      [{ "label": "FFT probe control" }]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"
    When I remove my temporary legacy qb-target zone
    Then my temporary target zone should not be targetable

  @rejection
  Scenario: An unregistered server action is refused by name
    Then the kora_target server action "fft_no_such_action" should be refused with "Unknown kora_target server action: fft_no_such_action"

  # ---------------------------------------------------------------------------
  # Zone shapes and option distances
  # ---------------------------------------------------------------------------

  @world
  Scenario: A sphere zone option is visible, runs once and the zone can be removed
    Given a temporary kora_target sphere zone ahead of me offers:
      """
      [{ "label": "FFT probe sphere" }]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe sphere"
    When I target "FFT probe sphere"
    Then the kora_target option "FFT probe sphere" should have run 1 times
    When I remove my temporary target zone
    Then my temporary target zone should not be targetable
    And removing my temporary target zone again should be refused

  @world
  Scenario: A poly zone option is visible and runs once
    Given a temporary kora_target poly zone ahead of me offers:
      """
      [{ "label": "FFT probe poly" }]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe poly"
    When I target "FFT probe poly"
    Then the kora_target option "FFT probe poly" should have run 1 times

  @world @rejection
  Scenario: A zone-level distance applies to options without their own distance
    Given a temporary kora_target box zone ahead of me with zone distance 0.3 offers:
      """
      [
        { "label": "FFT probe control", "distance": 2.5 },
        { "label": "FFT probe zone reach" }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"
    And the kora_target option "FFT probe zone reach" should have run 0 times

  @world
  Scenario: An option's own distance overrides a shorter zone distance
    Given a temporary kora_target box zone ahead of me with zone distance 0.3 offers:
      """
      [
        { "label": "FFT probe own reach", "distance": 2.5 }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe own reach"
    When I target "FFT probe own reach"
    Then the kora_target option "FFT probe own reach" should have run 1 times

  # ---------------------------------------------------------------------------
  # Validation and removal of registrations
  # ---------------------------------------------------------------------------

  @rejection
  Scenario Outline: kora_target refuses an invalid registration or call
    Then the kora_target call "<case>" should be refused with "<reason>"

    Examples:
      | case                              | reason                                                                |
      | box zone without options          | options must be a non-empty array of target options.                  |
      | option without a label            | options[1].label must be a non-empty string.                          |
      | option with an empty label        | options[1].label must be a non-empty string.                          |
      | option without onSelect           | options[1].onSelect must be a function.                               |
      | option with a text canInteract    | options[1].canInteract must be a function.                            |
      | option with a text distance       | options[1].distance must be a number.                                 |
      | option with a text allowInVehicle | options[1].allowInVehicle must be a boolean.                          |
      | zone with a text allowInVehicle   | zoneOptions.allowInVehicle must be a boolean.                         |
      | box zone without coords           | addBoxZone requires zoneOptions.coords to be a table with numeric x/y/z. |
      | box zone without size             | addBoxZone requires zoneOptions.size to be a table with numeric x/y/z. |
      | sphere zone with zero radius      | addSphereZone requires zoneOptions.radius to be a positive number.    |
      | sphere zone with negative radius  | addSphereZone requires zoneOptions.radius to be a positive number.    |
      | poly zone with two points         | addPolyZone requires at least 3 points.                               |
      | global type train                 | entityType must be 'ped', 'vehicle', 'object', or 'player'.           |
      | model given as a boolean          | Models must be strings or numbers.                                    |
      | global bone given as a number     | Bone names must be strings.                                           |
      | setEnabled with text              | enabled must be a boolean.                                            |
      | server action without a name      | runServerAction requires a name.                                      |

  @rejection
  Scenario: An entity registration with a non-number handle is skipped
    Then registering kora_target options on a non-number entity handle should register nothing

  @rejection
  Scenario: Removing zones that were never registered is refused
    Then removing kora_target zones that do not exist should be refused

  @rejection
  Scenario: A registration of another kind cannot be removed as a zone
    Given a temporary kora_target model registration exists
    Then removing my model registration as a zone should be refused
    And removing my model registration by model should succeed once

  # ---------------------------------------------------------------------------
  # canInteract and onSelect contracts
  # ---------------------------------------------------------------------------

  @world @rejection
  Scenario: An option whose canInteract raises is hidden
    Given a temporary kora_target box zone ahead of me with recorded callbacks offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe broken check", "canInteract": "error" }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"
    And the kora_target option "FFT probe broken check" should have run 0 times

  @world
  Scenario: A native canInteract that returns nothing leaves the option visible
    Given a temporary kora_target box zone ahead of me with recorded callbacks offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe silent check", "canInteract": "nil" }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should offer exactly 2 options

  @world
  Scenario: canInteract and onSelect receive the option's distance and data
    Given a temporary kora_target box zone ahead of me with recorded callbacks offers:
      """
      [{ "label": "FFT probe with data", "canInteract": "record", "data": { "tag": "fft-probe-data" } }]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe with data"
    And the kora_target option "FFT probe with data" should have been checked with its distance and data
    When I target "FFT probe with data"
    Then the kora_target option "FFT probe with data" should have been selected with its data

  @world
  Scenario: An option whose onSelect raises can still be selected again
    Given a temporary kora_target box zone ahead of me with recorded callbacks offers:
      """
      [{ "label": "FFT probe faulty action", "onSelect": "error" }]
      """
    When I look at my temporary target zone
    And I target "FFT probe faulty action"
    Then the kora_target option "FFT probe faulty action" should have run 1 times
    When I target "FFT probe faulty action"
    Then the kora_target option "FFT probe faulty action" should have run 2 times

  # ---------------------------------------------------------------------------
  # Vehicle and busy gates (Config.target.disableInVehicle, uiBlockBag)
  # ---------------------------------------------------------------------------

  @world @rejection
  Scenario: Seated in a vehicle only options that allow vehicles are offered
    Given a temporary kora_target box zone ahead of me with recorded callbacks offers:
      """
      [
        { "label": "FFT probe from the car", "allowInVehicle": true },
        { "label": "FFT probe on foot only" }
      ]
      """
    And I am driving a temporary "sultan"
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe from the car"
    When I target "FFT probe from the car"
    Then the kora_target option "FFT probe from the car" should have run 1 times
    And the kora_target option "FFT probe on foot only" should have run 0 times

  @world @rejection
  Scenario: An option refusing vehicles overrides a zone that allows them
    Given a temporary kora_target box zone ahead of me that allows vehicles offers:
      """
      [
        { "label": "FFT probe zone default" },
        { "label": "FFT probe never seated", "allowInVehicle": false }
      ]
      """
    And I am driving a temporary "sultan"
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe zone default"
    And the kora_target option "FFT probe never seated" should have run 0 times

  @world @rejection
  Scenario: Targeting cannot start while another resource holds the UI block
    Given a temporary kora_target box zone ahead of me offers:
      """
      [{ "label": "FFT probe inspect" }]
      """
    And I look at my temporary target zone
    And my temporary target zone should show only "FFT probe inspect"
    When the koraUiBlocked state is set for this scenario
    Then starting to target should be blocked
    And the kora_target option "FFT probe inspect" should have run 0 times
    When the koraUiBlocked state is cleared
    Then starting to target should work

  # ---------------------------------------------------------------------------
  # Session state and control
  # ---------------------------------------------------------------------------

  @world
  Scenario: Every targeting surface reports the hovered zone while the eye is held
    Given a temporary kora_target box zone ahead of me offers:
      """
      [{ "label": "FFT probe inspect" }]
      """
    And I look at my temporary target zone
    When I hold targeting on my temporary target zone
    Then kora_target getState should report my temporary zone under the aim
    And the compatibility exports should report targeting "on"
    When I run the command "target-reset"
    Then kora_target should stop targeting
    And the compatibility exports should report targeting "off"
    And the kora_target option "FFT probe inspect" should have run 0 times

  @world @rejection
  Scenario: Switching kora_target off ends a targeting session without running anything
    Given a temporary kora_target box zone ahead of me offers:
      """
      [{ "label": "FFT probe inspect" }]
      """
    And I look at my temporary target zone
    And I hold targeting on my temporary target zone
    When kora_target is switched off for this scenario
    Then kora_target should stop targeting
    And kora_target should report enabled "false"
    And the kora_target option "FFT probe inspect" should have run 0 times

  # ---------------------------------------------------------------------------
  # qb-target compatibility
  # ---------------------------------------------------------------------------

  @world @rejection
  Scenario: An excludejob legacy option is hidden from that job only
    Given my job is "mechanic" at grade 0
    And a temporary legacy qb-target box zone ahead of me with filters offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe not for mechanics", "excludejob": "mechanic" }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"
    When my job is "unemployed" at grade 0
    Then my temporary target zone should offer exactly 2 options

  @world
  Scenario: A jobType legacy option follows the job's type
    Given my job is "unemployed" at grade 0
    And a temporary legacy qb-target box zone ahead of me with filters offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe garage trade", "jobType": "mechanic" }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"
    When my job is "mechanic" at grade 0
    Then my temporary target zone should offer exactly 2 options

  @world
  Scenario: A legacy option for job "all" is visible to any job
    Given my job is "unemployed" at grade 0
    And a temporary legacy qb-target box zone ahead of me with filters offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe anyone", "job": "all" }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should offer exactly 2 options

  @world @rejection
  Scenario: An excludegang legacy option is hidden from that gang
    Given a temporary legacy qb-target box zone ahead of me with filters offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe not for ballas", "excludegang": "ballas" }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should offer exactly 2 options
    When my gang is "ballas" at grade 0
    Then my temporary target zone should show only "FFT probe control"

  @world @ui @rejection
  Scenario: A citizenid legacy option is only offered to that character
    Given a temporary legacy qb-target box zone ahead of me with filters offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe mine", "citizenid": "@me" },
        { "label": "FFT probe someone else", "citizenid": "FFT00000" }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should offer exactly 2 options
    When I open the target selector on my temporary zone
    Then the interact selector should offer "FFT probe mine"
    And the target selector should not list "FFT probe someone else"

  @world
  Scenario: A required_item legacy option follows the inventory
    Given a temporary legacy qb-target box zone ahead of me with filters offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe needs a lockpick", "required_item": "lockpick" }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"
    When I hold 1 "lockpick"
    Then my temporary target zone should offer exactly 2 options

  @world @ui
  Scenario: Legacy options are offered in their num order
    Given a temporary legacy qb-target box zone ahead of me with filters offers:
      """
      [
        { "label": "FFT probe listed second", "num": 2 },
        { "label": "FFT probe listed first", "num": 1 }
      ]
      """
    When I look at my temporary target zone
    And I open the target selector on my temporary zone
    Then the interact selector should list "FFT probe listed first" first

  @world
  Scenario: A legacy option with a client event fires that event once
    Given a temporary legacy qb-target box zone ahead of me with filters offers:
      """
      [{ "label": "FFT probe event", "event": "fft:kora_target:legacyProbe", "type": "client" }]
      """
    When I look at my temporary target zone
    And I target "FFT probe event"
    Then the legacy qb-target event for "FFT probe event" should have fired 1 times

  @world
  Scenario: Registering a legacy zone name again replaces the earlier zone
    Given a temporary legacy qb-target box zone ahead of me with filters offers:
      """
      [{ "label": "FFT probe old zone" }]
      """
    When my temporary legacy qb-target zone is registered again offering only "FFT probe new zone"
    And I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe new zone"
    When I target "FFT probe new zone"
    Then the kora_target option "FFT probe new zone" should have run 1 times
    And the kora_target option "FFT probe old zone" should have run 0 times

  @world
  Scenario: Legacy zone data can be read and its options replaced
    Given a temporary legacy qb-target box zone ahead of me with filters offers:
      """
      [{ "label": "FFT probe before update" }]
      """
    Then the legacy qb-target zone data should describe my temporary zone
    When I replace my temporary legacy qb-target zone options with "FFT probe after update"
    And I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe after update"
    When I remove my temporary legacy qb-target zone
    Then my temporary target zone should not be targetable
    And removing my temporary legacy qb-target zone again should be refused

  @rejection
  Scenario: Unknown legacy zone names are refused
    Then unknown legacy qb-target zone names should be refused

  @world @rejection
  Scenario: AllowTargeting false stops targeting until it is allowed again
    Given a temporary legacy qb-target box zone ahead of me with filters offers:
      """
      [{ "label": "FFT probe control" }]
      """
    When legacy qb-target targeting is disallowed for this scenario
    Then kora_target should report enabled "false"
    And starting to target should be blocked
    When legacy qb-target targeting is allowed again
    Then kora_target should report enabled "true"
    And starting to target should work

  # ---------------------------------------------------------------------------
  # ox_target compatibility
  # ---------------------------------------------------------------------------

  @world
  Scenario: A named ox_target zone runs its option and is removed by name once
    Given a temporary ox_target box zone ahead of me offers:
      """
      [{ "label": "FFT probe ox inspect", "name": "fft_ox_inspect", "record": true }]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe ox inspect"
    And the ox_target canInteract for "FFT probe ox inspect" should have received the option name "fft_ox_inspect"
    When I target "FFT probe ox inspect"
    Then the kora_target option "FFT probe ox inspect" should have run 1 times
    And the ox_target response for "FFT probe ox inspect" should describe my temporary zone
    When I remove my temporary ox_target zone by name
    Then my temporary target zone should not be targetable
    And removing my temporary ox_target zone by name again should be refused

  @world @rejection
  Scenario: An ox_target group option follows job membership
    Given my job is "unemployed" at grade 0
    And a temporary ox_target box zone ahead of me offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe ox mechanic", "groups": "mechanic" }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"
    When my job is "mechanic" at grade 0
    Then my temporary target zone should offer exactly 2 options

  @world @rejection
  Scenario: An ox_target group grade hides the option from lower grades
    Given my job is "mechanic" at grade 0
    And a temporary ox_target box zone ahead of me offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe ox boss", "groups": { "mechanic": 2 } }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"
    # Legacy grade levels are zero-based: kora grade 3 (Boss) is legacy level 2.
    When my job is "mechanic" at grade 3
    Then my temporary target zone should offer exactly 2 options

  @world @rejection
  Scenario: An ox_target option needing every listed item stays hidden with only one
    Given a temporary ox_target box zone ahead of me offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe ox both items", "items": ["lockpick", "harness"] }
      ]
      """
    And I hold 1 "lockpick"
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"
    When I hold 1 "harness"
    Then my temporary target zone should offer exactly 2 options

  @world
  Scenario: An ox_target anyItem option appears with any one listed item
    Given a temporary ox_target box zone ahead of me offers:
      """
      [
        { "label": "FFT probe control" },
        { "label": "FFT probe ox either item", "items": ["lockpick", "harness"], "anyItem": true }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe control"
    When I hold 1 "lockpick"
    Then my temporary target zone should offer exactly 2 options

  @world @ui
  Scenario: An ox_target sub-menu opens and Go back returns to the first menu
    Given a temporary ox_target box zone ahead of me offers:
      """
      [
        { "label": "FFT probe ox open menu", "openMenu": "fft_probe_menu" },
        { "label": "FFT probe ox in menu", "menuName": "fft_probe_menu" }
      ]
      """
    When I look at my temporary target zone
    Then my temporary target zone should show only "FFT probe ox open menu"
    When I target "FFT probe ox open menu"
    Then my temporary target zone should offer exactly 2 options
    When I target "Go back"
    Then my temporary target zone should show only "FFT probe ox open menu"
    And the kora_target option "FFT probe ox in menu" should have run 0 times

  @world @rejection
  Scenario: ox_target disableTargeting true switches targeting off
    Given a temporary ox_target box zone ahead of me offers:
      """
      [{ "label": "FFT probe control" }]
      """
    When ox_target targeting is disabled for this scenario
    Then kora_target should report enabled "false"
    And starting to target should be blocked
    When ox_target targeting is enabled again
    Then kora_target should report enabled "true"
    And starting to target should work
