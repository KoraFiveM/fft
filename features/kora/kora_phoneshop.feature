@kora @kora_phoneshop
Feature: kora_phoneshop streamed phone shop map
  kora_phoneshop is a map resource: stream assets and one type file, with no
  scripts, exports, events or commands. These scenarios only prove that both
  realms started it, that the manifest registers its type file and that the
  game mounted its streamed models.
  Not covered: that the interior renders, is walkable, has correct collision
  and does not flicker through the windows. None of that is observable from
  Lua, and no coordinate for the unit exists in the resource's source, so those
  stay manual checks (tests/*.feature in the resource).

  Background:
    Given resource "kora_phoneshop" is running

  Scenario: Map resource is started for the player and registers its type file
    Then my game should have started the map resource "kora_phoneshop"
    And the map resource "kora_phoneshop" should declare the type file "stream/phoneshop.ytyp"

  Scenario Outline: Streamed phone shop models are mounted
    Then my game should know the phone shop model "<model>"

    Examples:
      | model               |
      | phoneshop_interior  |
      | phoneshop_phone_std |
      | phoneshop_ramp      |

  # ---------------------------------------------------------------------------
  # Round 3
  # ---------------------------------------------------------------------------

  # Archetypes declared in stream/phoneshop.ytyp (decoded) beyond the three above.
  Scenario Outline: The streamed phone shop model "<model>" is mounted
    Then my game should know the phone shop model "<model>"

    Examples:
      | model                    |
      | phoneshop_phone_flip     |
      | phoneshop_phone_fold     |
      | phoneshop_smart_switch_2 |
      | phoneshop_smart_switch_3 |
      | phoneshop_off_chair_04   |
      | phoneshop_off_chair_05   |
      | phoneshop_shutter        |

  @server
  Scenario: The manifest marks the resource as a map
    Then the map resource "kora_phoneshop" should be flagged as a map

  @server
  Scenario Outline: The map resource runs no <key> code
    Then the map resource "kora_phoneshop" should declare no "<key>" entries

    Examples:
      | key           |
      | client_script |
      | server_script |
      | shared_script |

  @server
  Scenario Outline: The map resource ships "<file>"
    Then the map resource "kora_phoneshop" should ship the stream file "<file>"

    Examples:
      | file                    |
      | phoneshop.ytyp          |
      | kora_phoneshop.ymap     |
      | kora_phoneshop.ybn      |
      | lr_sc1_occl_02.ymap     |
      | phoneshop_interior.ydr  |
      | phoneshop_txd.ytd       |
      | phoneshop_phones.ytd    |
      | sc1_11_mall2.ydr        |
      | hi@lr_sc1_11_0.ybn      |
      | lr_sc1_11_0.ybn         |

  # Positions decoded from stream/kora_phoneshop.ymap; unverified until live.
  @world
  Scenario: The phone shop interior is placed at the Strawberry strip mall
    Given I stand at 94.6 -1427.26 28.6 facing 0.0
    Then the phone shop interior should be placed where its map puts it
    And I should be standing inside the phone shop interior

  @world
  Scenario: The phone shop ramp is placed outside the unit
    Given I stand at 90.5 -1432.0 29.0 facing 220.0
    Then the phone shop ramp should be placed where its map puts it
