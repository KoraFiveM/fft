@kora @kora_interior
Feature: kora_interior shell geometry
  kora_interior is client only. These scenarios use the createGeometry and
  removeGeometry exports that housing scenes rely on: a frozen, local shell
  object is created without teleporting anyone, and only its creator may remove
  it. The shell is spawned 250 m above the tester and removed in cleanup; only
  the tester's client ever sees it.
  Not covered: the legacy factories (createShell and the qb-interior Create*
  exports) and DespawnInterior. They fade the screen and teleport the player
  into the shell, which has no assertion a test could make that the geometry
  scenarios do not already make, and they would strand the tester mid-air on a
  failure. Whether a shell looks right or has collision is not observable from
  Lua. kora_interior has no server realm. The legacy factories are only
  checked to be exported (read, never called).

  Background:
    Given resource "kora_interior" is running

  @world
  Scenario Outline: Bundled shell is created as frozen local geometry
    When a centered "<model>" interior shell is created high above me
    Then the interior shell should exist as a frozen "<model>" object
    And the interior shell should sit at the origin I asked for
    And the interior shell should hand back the exit offset I supplied
    And creating the interior shell should not have moved me or faded my screen

    Examples:
      | model               |
      | shell_v16low        |
      | standardmotel_shell |
      | shell_garagem       |

  @world
  Scenario: Legacy placement also creates the shell
    When a legacy-placed "shell_v16low" interior shell is created high above me
    Then the interior shell should exist as a frozen "shell_v16low" object
    And creating the interior shell should not have moved me or faded my screen

  @world
  Scenario: The creator can remove its shell
    Given a centered "shell_v16low" interior shell is created high above me
    When I remove the interior shell
    Then the interior shell should be gone

  @rejection
  Scenario: Shell without a usable origin is refused
    Then creating an interior shell without an origin should be refused with "Invalid shell origin."
    And creating an interior shell at an origin without a height should be refused with "Invalid shell origin."

  @rejection
  Scenario: Unknown placement mode is refused
    Then creating an interior shell with the placement "guess" should be refused with "Invalid shell placement mode."

  @rejection
  Scenario: Removing geometry needs an object list
    Then removing interior shell geometry without an object list should be refused with "Shell objects are required."

  @rejection
  Scenario: Geometry the caller does not own is not removed
    Then removing an entity the interior resource did not create for me should be refused with "Shell geometry belongs to another resource."

  # ---------------------------------------------------------------------------
  # Round 3: every bundled model, placement modes, ownership and refusals.
  # Model names come from the SHELLS table in client/main.lua and
  # docs/bundled-shell-bounds.json; only bundled (streamed) shells are spawned.
  # ---------------------------------------------------------------------------

  @world
  Scenario Outline: Every other bundled shell is created as frozen local geometry
    When a centered "<model>" interior shell is created high above me
    Then the interior shell should exist as a frozen "<model>" object
    And the interior shell should sit at the origin I asked for
    And the interior shell should hand back the exit offset I supplied
    And creating the interior shell should not have moved me or faded my screen
    When I remove the interior shell
    Then the interior shell should be gone

    Examples:
      | model               |
      | furnitured_midapart |
      | shell_v16mid        |
      | shell_trevor        |
      | shell_trailer       |
      | shell_lester        |
      | shell_ranch         |
      | container_shell     |
      | modernhotel_shell   |
      | shell_frankaunt     |
      | shell_michael       |
      | shell_office1       |
      | shell_store1        |
      | shell_warehouse1    |

  @world
  Scenario Outline: Legacy placement works for bundled shells and removes cleanly
    When a legacy-placed "<model>" interior shell is created high above me
    Then the interior shell should exist as a frozen "<model>" object
    And the interior shell should hand back the exit offset I supplied
    And creating the interior shell should not have moved me or faded my screen
    When I remove the interior shell
    Then the interior shell should be gone

    Examples:
      | model               |
      | standardmotel_shell |
      | shell_garagem       |
      | shell_michael       |
      | container_shell     |

  @world
  Scenario: Without a placement the shell follows the configured legacy default
    When a "shell_v16low" interior shell with the default placement is created high above me
    Then the interior shell should exist as a frozen "shell_v16low" object
    When a second "shell_v16low" interior shell with the legacy placement is created high above me
    Then the default placement should put the shell where the legacy placement does

  @world
  Scenario: A shell can be created from a model hash
    When a centered interior shell is created high above me from the model hash of "shell_v16low"
    Then the interior shell should exist as a frozen "shell_v16low" object
    And the interior shell should sit at the origin I asked for

  @world
  Scenario: A shell created without an exit hands back no exit point
    When a centered "shell_v16low" interior shell without an exit is created high above me
    Then the interior shell should exist as a frozen "shell_v16low" object
    And the interior shell should hand back no exit point

  @world
  Scenario: Several shells are removed in one call
    Given a centered "shell_v16low" interior shell is created high above me
    And a second "standardmotel_shell" interior shell with the centered placement is created high above me
    When I remove every interior shell in one call
    Then every interior shell should be gone

  @world @rejection
  Scenario: Removing the same shell twice is refused the second time
    Given a centered "shell_v16low" interior shell is created high above me
    When I remove the interior shell
    Then the interior shell should be gone
    And removing the interior shell again should be refused with "Shell geometry belongs to another resource."

  @world @rejection
  Scenario: A list with one foreign entity removes nothing
    Given a centered "shell_v16low" interior shell is created high above me
    Then removing my interior shell together with my own ped should be refused with "Shell geometry belongs to another resource."
    And the interior shell should still exist
    When I remove the interior shell
    Then the interior shell should be gone

  Scenario: Removing an empty list is a no-op
    Then removing an empty interior shell list should succeed

  @rejection
  Scenario Outline: A shell origin that is not three finite numbers is refused
    Then creating an interior shell at the bad origin "<case>" should be refused with "Invalid shell origin."

    Examples:
      | case                |
      | nan_z               |
      | infinite_x          |
      | negative_infinite_y |
      | text_coordinates    |
      | empty_table         |
      | text_origin         |

  @rejection
  Scenario Outline: Placement names are exact
    Then creating an interior shell with the placement "<placement>" should be refused with "Invalid shell placement mode."

    Examples:
      | placement |
      | CENTERED  |
      | Legacy    |
      | centred   |
      | offset    |

  @rejection
  Scenario: A numeric placement is refused
    Then creating an interior shell with a numeric placement should be refused with "Invalid shell placement mode."

  @rejection
  Scenario: An unknown shell model is refused with a reason
    Then creating an interior shell from the unknown model "fft_no_such_shell" should be refused

  @rejection
  Scenario: A shell without a model is refused with a reason
    Then creating an interior shell without a model should be refused

  Scenario Outline: Every bundled shell factory is exported under both names
    Then the interior factory "<factory>" should be exported under "kora_interior"
    And the interior factory "<factory>" should be exported under "qb-interior"

    Examples:
      | factory                  |
      | CreateApartmentFurnished |
      | CreateHouseRobbery       |
      | CreateApartmentShell     |
      | CreateTier1House         |
      | CreateTrevorsShell       |
      | CreateCaravanShell       |
      | CreateLesterShell        |
      | CreateRanchShell         |
      | CreateContainer          |
      | CreateFurniMid           |
      | CreateFurniMotelModern   |
      | CreateFranklinAunt       |
      | CreateGarageMed          |
      | CreateMichael            |
      | CreateOffice1            |
      | CreateStore1             |
      | CreateFurniMotelStandard |
      | CreateWarehouse1         |
      | DespawnInterior          |

  Scenario: The geometry exports are kora_interior's own
    Then the interior factory "createGeometry" should be exported under "kora_interior"
    And the interior factory "removeGeometry" should be exported under "kora_interior"
    And the interior factory "createShell" should be exported under "kora_interior"
