@kora @kora_multichar
Feature: kora_multichar character select guards
  The tester is the character under test, so nothing here opens character
  select, selects, creates or deletes a character, logs out or opens the scene
  studio: each of those would replace or drop the FFT character. These
  scenarios assert what the server answers to a player who is already in game,
  through kora_multichar/fft_hooks.lua (the same Kora.callback requests
  client.lua sends) and the public scene exports. Every driven path is a
  refusal or read-only. The server rate-limits mode and nationality requests
  to 8 per 10 seconds each; the feature stays below that in one run.

  Background:
    Given resource "kora_multichar" is running

  # Refusal strings are the returns of kora_multichar:server:enterMode and
  # enterMode() in kora_multichar/server.lua.
  @rejection
  Scenario Outline: A logged-in player cannot enter the <mode> mode
    Given the character select hooks should be version 1
    And I remember my routing bucket before asking for a cinematic mode
    When I ask the server for the cinematic mode "<mode>"
    Then the cinematic mode should be refused with "<reason>"
    And I should not be in a cinematic mode
    And my routing bucket should be the one I remembered

    Examples:
      | mode      | reason                                               |
      | selection | already logged in                                    |
      | spawn     | spawn transition is not active                       |
      | creator   | creator mode must be opened by the protected command |
      | cutscene  | invalid cinematic mode                               |

  Scenario: Leaving a cinematic mode that is not active changes nothing
    Given I remember my routing bucket before asking for a cinematic mode
    When I ask the server to leave the cinematic mode without being in one
    Then leaving the cinematic mode should be acknowledged
    And the server should record that I am logged in and in no cinematic mode
    And my routing bucket should be the one I remembered

  # Config.nationalities and Config.allowFreeTextNationality = false in config.lua.
  Scenario: A listed nationality is accepted
    When the server checks the nationality "American"
    Then the nationality should be accepted as "American"

  Scenario: Surrounding spaces are trimmed from a listed nationality
    When the server checks the nationality "  British  "
    Then the nationality should be accepted as "British"

  @rejection
  Scenario: A nationality outside the list is refused
    When the server checks the nationality "Atlantean"
    Then the nationality should be refused with "Choose a nationality from the list."

  @rejection
  Scenario: A nationality that is not text is refused
    When the server checks a nationality that is not text
    Then the nationality should be refused with "Choose a valid nationality."

  # Scene ids are the bundledScenes keys in kora_multichar/scenes.lua.
  Scenario: The bundled scenes are served to the client
    When I fetch the character select scenes
    Then the scenes should include "civilian"
    And the scenes should include "police"
    And the scenes should include "ambulance"
    And the scenes should include "mechanic"
    And the scenes should include "ballas"
    And the scenes should include "vagos"

  @server @rejection
  Scenario: Another resource cannot replace a bundled scene
    When another resource registers a scene over the bundled scene "civilian"
    Then the scene request should be refused with "scene civilian is owned by kora_multichar"

  @server @rejection
  Scenario: Another resource cannot remove a bundled scene
    When another resource unregisters the scene "police"
    Then the scene request should be refused with "scene is owned by another resource"

  @server @rejection
  Scenario: Removing a scene that does not exist is refused
    When another resource unregisters the scene "fft_missing_scene"
    Then the scene request should be refused with "unknown scene"

  @server @rejection
  Scenario: A scene id with unsupported characters is refused
    When another resource registers a scene with the id "fft bad id!" and no label
    Then the scene request should be refused with "scene id must use 1-48 letters, numbers, _ or -"

  @server @rejection
  Scenario: A scene that is not a table is refused
    When another resource registers a scene with the id "fft_rejected_scene" that is not a table
    Then the scene request should be refused with "scene must be a table"

  @server @rejection
  Scenario: A scene without a label is refused
    When another resource registers a scene with the id "fft_rejected_scene" and no label
    Then the scene request should be refused with "scene label is required and capped at 64 bytes"

  Scenario: Rejected scene requests leave the registry unchanged
    When I fetch the character select scenes
    Then the scenes should include "civilian"
    And the scenes should include "police"
    And the scenes should not include "fft_rejected_scene"

  @server
  Scenario: The manifest claims the legacy resource names
    Then the character select resource should provide the legacy name "qb-multicharacter"
    And the character select resource should provide the legacy name "qb-spawn"

  Scenario: The legacy server log request still answers
    Then the legacy character select server log request should answer with an empty list

  # ---------------------------------------------------------------------------
  # Round 3. Mode and nationality steps wait out the callback rate limit
  # (8 per 10 s) when an earlier scenario used it up.
  # ---------------------------------------------------------------------------

  # enterMode() only knows 'selection', 'spawn' and 'creator', compared exactly.
  @rejection
  Scenario Outline: A malformed cinematic mode name "<mode>" is refused
    Given I remember my routing bucket before asking for a cinematic mode
    When I ask the server for the cinematic mode "<mode>"
    Then the cinematic mode should be refused with "invalid cinematic mode"
    And I should not be in a cinematic mode
    And my routing bucket should be the one I remembered

    Examples:
      | mode      |
      |           |
      | Selection |
      | SPAWN     |
      | Creator   |
      | lobby     |

  Scenario: Leaving a cinematic mode repeatedly is idempotent
    Given I remember my routing bucket before asking for a cinematic mode
    When I ask the server to leave the cinematic mode 3 times
    Then every leave request should be acknowledged
    And the server should record that I am logged in and in no cinematic mode
    And my routing bucket should be the one I remembered

  # Config.nationalities rows from kora_multichar/config.lua.
  Scenario Outline: The listed nationality "<nationality>" is accepted
    When the server checks the nationality "<nationality>"
    Then the nationality should be accepted as "<nationality>"

    Examples:
      | nationality   |
      | Argentine     |
      | New Zealander |
      | South African |
      | Vietnamese    |
      | Icelandic     |

  Scenario: Tabs and newlines around a listed nationality are trimmed
    When the server checks the nationality "Japanese" wrapped in tabs and newlines
    Then the nationality should be accepted as "Japanese"

  # Matching is exact (entry == value) once the value is trimmed, and
  # Config.allowFreeTextNationality is false.
  @rejection
  Scenario Outline: The unlisted nationality "<nationality>" is refused
    When the server checks the nationality "<nationality>"
    Then the nationality should be refused with "Choose a nationality from the list."

    Examples:
      | nationality      |
      | american         |
      | AMERICAN         |
      | Americ           |
      | American!        |
      | British American |
      | New  Zealander   |
      |                  |
      | Earthling        |

  @rejection
  Scenario: A nationality of only spaces is refused
    When the server checks the nationality "     "
    Then the nationality should be refused with "Choose a nationality from the list."

  @rejection
  Scenario: An over-long nationality is refused
    When the server checks a nationality of 40 repeated letters
    Then the nationality should be refused with "Choose a nationality from the list."

  @rejection
  Scenario: A missing nationality is refused
    When the server checks a missing nationality
    Then the nationality should be refused with "Choose a valid nationality."

  @rejection
  Scenario: A boolean nationality is refused
    When the server checks a nationality given as a boolean
    Then the nationality should be refused with "Choose a valid nationality."

  # kora_lib/local/callback/server.lua:247-251: the ninth request inside the
  # 10 s window is answered with "Callback rate limit exceeded".
  @rejection @slow
  Scenario: The nationality check is rate limited per player
    Given the character select rate limit window has passed
    When the server checks the nationality "British" as often as the rate limit allows
    Then every one of those nationality checks should be accepted as "British"
    And one more nationality check should be refused by the callback rate limit

  # bundledScenes in kora_multichar/scenes.lua.
  Scenario Outline: The bundled scene "<id>" keeps its authored label and priority
    When I fetch the character select scenes
    Then the scene "<id>" should be labelled "<label>" with priority <priority>
    And the scene "<id>" should have 3 cameras

    Examples:
      | id        | label                                 | priority |
      | civilian  | Vespucci Beach · Sunset               | 0        |
      | police    | Strawberry 24/7 · Robbery in Progress | 200      |
      | ambulance | Pillbox · Active Medical Response     | 200      |
      | mechanic  | Benny's Workshop                      | 200      |
      | ballas    | Davis                                 | 100      |
      | vagos     | Rancho                                | 100      |

  @server @rejection
  Scenario Outline: Another resource cannot replace the bundled scene "<id>"
    When another resource registers a scene over the bundled scene "<id>"
    Then the scene request should be refused with "scene <id> is owned by kora_multichar"

    Examples:
      | id        |
      | police    |
      | ambulance |
      | mechanic  |
      | ballas    |
      | vagos     |

  @server @rejection
  Scenario Outline: Another resource cannot remove the bundled scene "<id>"
    When another resource unregisters the scene "<id>"
    Then the scene request should be refused with "scene is owned by another resource"

    Examples:
      | id        |
      | civilian  |
      | ambulance |
      | mechanic  |
      | ballas    |
      | vagos     |

  @server @rejection
  Scenario Outline: Removing the scene "<id>" that is not registered is refused
    When another resource unregisters the scene "<id>"
    Then the scene request should be refused with "unknown scene"

    Examples:
      | id       |
      | Civilian |
      | POLICE   |
      |          |

  @server @rejection
  Scenario: Removing a scene by a numeric id is refused
    When another resource unregisters a scene by a numeric id
    Then the scene request should be refused with "unknown scene"

  # SceneSchema.validate in kora_multichar/shared/scene.lua: one broken rule
  # per row, with the message of the first rule that fails.
  @server @rejection
  Scenario Outline: A scene with <defect> is refused
    When another resource registers a scene with the defect "<defect>"
    Then the scene request should be refused with "<reason>"

    Examples:
      | defect                              | reason                                                                    |
      | a 65 byte label                     | scene label is required and capped at 64 bytes                            |
      | a control character in the label    | scene definitions must contain only finite data and cannot contain cycles |
      | a 49 character id                   | scene id must use 1-48 letters, numbers, _ or -                           |
      | an empty id                         | scene id must use 1-48 letters, numbers, _ or -                           |
      | a numeric id                        | scene id must use 1-48 letters, numbers, _ or -                           |
      | a fractional priority               | scene priority must be an integer                                         |
      | no anchor                           | scene anchor must contain finite x/y/z/w values                           |
      | an anchor without a heading         | scene anchor must contain finite x/y/z/w values                           |
      | no character offset                 | scene character.offset is required                                        |
      | selectors that are not a list       | scene selectors must be an array                                          |
      | a selector without job or gang      | selector requires job or gang                                             |
      | a selector duty that is not boolean | selector duty must be boolean                                             |
      | an inverted grade range             | selector grade range is inverted                                          |
      | an environment hour of 24           | environment hour must be 0-23                                             |
      | an environment minute of 60         | environment minute must be 0-59                                           |
      | an environment strength of 2        | environment strength must be 0-1                                          |
      | an entity of an unknown type        | entity type must be ped, vehicle, or prop                                 |
      | nine peds                           | scene exceeds ped limit                                                   |
      | two entities with the same id       | entity ids must be 1-48 visible bytes and unique                          |
      | a ped seated in an unknown vehicle  | entity p1 seat references an unknown vehicle                              |
      | a prop that snaps to water          | entity e1 can only snap vehicles to water                                 |
      | no cameras                          | scene requires at least one camera                                        |
      | nine cameras                        | scene exceeds camera limit                                                |
      | two cameras with the same id        | camera ids must be 1-48 visible bytes and unique                          |
      | a camera without a look-at point    | camera c1 requires offset and lookAt                                      |
      | a camera field of view of 5         | camera c1 has invalid fov                                                 |
      | a timeline longer than the limit    | timeline duration exceeds limit                                           |
      | a timeline cue of an unknown type   | timeline contains an unsupported cue type                                 |
      | a camera cue for an unknown camera  | camera cue references an unknown camera                                   |
      | a cue after the end of the timeline | timeline cue time is invalid                                              |

  Scenario: Refused schema probes leave no scene behind
    When I fetch the character select scenes
    Then the scenes should not include "fft_probe_scene"
    And the scenes should include "civilian"
    And the scenes should include "vagos"

  @server
  Scenario Outline: The manifest depends on "<resource>"
    Then the character select resource should depend on "<resource>"

    Examples:
      | resource  |
      | kora_core |
      | kora_lib  |
      | kora_theme |
