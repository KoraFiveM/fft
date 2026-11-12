@kora @kora_sound
Feature: kora_sound playback requests
  kora_sound turns a play request into a net event for the listening client:
  PlayOnOne for a one-shot, PlayLoop and StopSound for a named loop. These
  scenarios observe the events the server sends to the tester, so they prove
  the file name, the resolved volume and the server's validation. They do not
  prove that the NUI page produced audio; the client's own logged-in gate and
  its NUI message are file-local and out of reach without a functional edit.

  Sounds are addressed to the tester. PlaySoundInArea and the
  PlayWithinDistance event are only used with a zero radius centred on the
  tester, or (tagged @global) with a 2 metre sphere just above the tester to
  prove the distance falloff. PlaySoundAll and the PlayOnAll event reach every
  player and are left uncovered; so is the client's own logged-in gate.

  Background:
    Given resource "kora_sound" is running

  Scenario: Server export delivers a sound to one player
    Given I listen for sounds addressed to me
    When the sound service plays "Cuff" to me at volume 0.05
    Then the sound "Cuff" should be played to me at volume 0.05

  # Presets are Config.categories and Config.soundCategory in kora_sound/config.lua:
  # interaction 0.3, alarm 0.6, and Config.defaultVolume 0.3 for an unlisted name.
  Scenario Outline: A sound without a volume uses its category preset
    Given I listen for sounds addressed to me
    When the sound service plays "<sound>" to me at its preset volume
    Then the sound "<sound>" should be played to me at volume <volume>

    Examples:
      | sound               | volume |
      | DoorOpen            | 0.3    |
      | Alert               | 0.6    |
      | fft_unlisted_sound  | 0.3    |

  Scenario: Client request plays a sound on the requesting player
    Given I listen for sounds addressed to me
    When I request the sound "Cuff" for myself at volume 0.05
    Then the sound "Cuff" should be played to me at volume 0.05

  Scenario: Client request without a volume uses the preset
    Given I listen for sounds addressed to me
    When I request the sound "Cuff" for myself without a volume
    Then the sound "Cuff" should be played to me at volume 0.3

  @rejection
  Scenario Outline: Client request with an unsafe file name is dropped
    Given I listen for sounds addressed to me
    When I request the sound "<name>" for myself at volume 0.05
    Then no sound should be played to me

    Examples:
      | name         |
      | ../Cuff      |
      | Cuff.ogg     |
      | sounds/Cuff  |

  @rejection
  Scenario: Client request with an out-of-range volume falls back to the preset
    Given I listen for sounds addressed to me
    When I request the sound "Cuff" for myself at volume 5.0
    Then the sound "Cuff" should be played to me at volume 0.3

  # Config.cooldownMs = 150 per player on the net-event entry points.
  @rejection
  Scenario: A second request inside the cooldown is dropped
    Given I listen for sounds addressed to me
    When I request the sound "Cuff" for myself twice without pausing
    Then the sound "Cuff" should be played to me exactly once

  Scenario: A named loop starts and is stopped for its listener
    Given I listen for sounds addressed to me
    When the sound service loops "Cuff" to me as "fft_loop_one" at volume 0.05
    Then the looping sound "Cuff" should start for me as "fft_loop_one" at volume 0.05
    When the sound service stops the loop "fft_loop_one"
    Then the looping sound "fft_loop_one" should be stopped for me

  # ---------------------------------------------------------------------------
  # Round 3: presets for every configured sound, export edge cases, the other
  # legacy entry points, validation boundaries, cooldown and loop bookkeeping.
  # ---------------------------------------------------------------------------

  # Every remaining entry of Config.soundCategory (kora_sound/config.lua:19-30)
  # with the Config.categories preset it maps to (config.lua:10-15).
  Scenario Outline: Every configured sound resolves to its category preset
    Given I listen for sounds addressed to me
    When the sound service plays "<sound>" to me at its preset volume
    Then the sound "<sound>" should be played to me at volume <volume>

    Examples: interaction
      | sound     | volume |
      | Cuff      | 0.3    |
      | Uncuff    | 0.3    |
      | handcuff  | 0.3    |
      | ziptie    | 0.3    |
      | DoorClose | 0.3    |
      | lockpick  | 0.3    |
      | unlock    | 0.3    |
      | lock      | 0.3    |
      | keys      | 0.3    |
      | keydoors  | 0.3    |

    Examples: alarm
      | sound           | volume |
      | security-alarm  | 0.6    |
      | warehousealert  | 0.6    |
      | warehousealert2 | 0.6    |
      | panic           | 0.6    |
      | beltalarm       | 0.6    |
      | RumbleStart     | 0.6    |

    Examples: ambient
      | sound           | volume |
      | radiostatic1    | 0.4    |
      | radiostatic2    | 0.4    |
      | radiostatic3    | 0.4    |
      | ventilator      | 0.4    |
      | coffee_machine  | 0.4    |
      | vending_machine | 0.4    |

  # The lookup is an exact table key (config.lua:36), so a differently cased
  # name is an unlisted sound and gets Config.defaultVolume.
  Scenario: A preset lookup is case sensitive
    Given I listen for sounds addressed to me
    When the sound service plays "ALERT" to me at its preset volume
    Then the sound "ALERT" should be played to me at volume 0.3

  # Config.resolveVolume tests `if explicitVolume` (config.lua:34); 0 is truthy
  # in Lua, so an explicit zero is kept instead of falling back to the preset.
  Scenario: An explicit volume of zero is kept by the export
    Given I listen for sounds addressed to me
    When the sound service plays "Alert" to me silently
    Then the sound "Alert" should be played to me at volume 0.0

  Scenario: An explicit volume overrides the category preset
    Given I listen for sounds addressed to me
    When the sound service plays "Alert" to me at volume 0.05
    Then the sound "Alert" should be played to me at volume 0.05

  # README: the exports are not gated by Config.cooldownMs.
  Scenario: Server exports are not rate limited
    Given I listen for sounds addressed to me
    When the sound service plays "Cuff" to me 3 times in a row at volume 0.05
    Then the sound "Cuff" should be played to me exactly 3 times

  # Kora.compat.provideExport('interact-sound', ...) in server/main.lua:108-111.
  Scenario: Legacy interact-sound export delivers a sound to one player
    Given I listen for sounds addressed to me
    When the legacy interact-sound service plays "Cuff" to me at volume 0.05
    Then the sound "Cuff" should be played to me at volume 0.05

  Scenario: Legacy interact-sound export starts and stops a named loop
    Given I listen for sounds addressed to me
    When the legacy interact-sound service loops "Cuff" to me as "fft_loop_legacy" at volume 0.05
    Then the looping sound "Cuff" should start for me as "fft_loop_legacy" at volume 0.05
    When the legacy interact-sound service stops the loop "fft_loop_legacy"
    Then the looping sound "fft_loop_legacy" should be stopped for me

  # playOnSource loops only with both options.loop and options.id (server/main.lua:36).
  Scenario: A loop request without an id plays once instead
    Given I listen for sounds addressed to me
    When the sound service loops "Cuff" to me without an id at volume 0.05
    Then the sound "Cuff" should be played to me at volume 0.05
    And no looping sound should start for me

  Scenario: An id without the loop flag plays once instead
    Given I listen for sounds addressed to me
    When the sound service plays "Cuff" to me with the id "fft_loop_noflag" but no loop flag at volume 0.05
    Then the sound "Cuff" should be played to me at volume 0.05
    And no looping sound should start for me

  Scenario: A loop without a volume uses the category preset
    Given I listen for sounds addressed to me
    When the sound service loops "ventilator" to me as "fft_loop_preset" at its preset volume
    Then the looping sound "ventilator" should start for me as "fft_loop_preset" at volume 0.4
    When the sound service stops the loop "fft_loop_preset"
    Then the looping sound "fft_loop_preset" should be stopped for me

  # activeLoops[id].recipients is a set (server/main.lua:37-38), so a loop
  # started twice for the same listener is stopped with one event.
  Scenario: A loop started twice is stopped once for its listener
    Given I listen for sounds addressed to me
    When the sound service loops "Cuff" to me as "fft_loop_twice" at volume 0.05
    And the sound service loops "Cuff" to me as "fft_loop_twice" at volume 0.05
    Then the looping sound "fft_loop_twice" should have started for me exactly 2 times
    When the sound service stops the loop "fft_loop_twice"
    Then the looping sound "fft_loop_twice" should be stopped for me exactly once

  Scenario: A loop can be stopped for one listener by naming the target
    Given I listen for sounds addressed to me
    When the sound service loops "Cuff" to me as "fft_loop_target" at volume 0.05
    Then the looping sound "Cuff" should start for me as "fft_loop_target" at volume 0.05
    When the sound service stops the loop "fft_loop_target" for me only
    Then the looping sound "fft_loop_target" should be stopped for me exactly once

  # stopSound sends to an explicit target without consulting activeLoops (server/main.lua:87-88).
  Scenario: A targeted stop is delivered even for a loop that never started
    Given I listen for sounds addressed to me
    When the sound service stops the loop "fft_loop_never" for me only
    Then the looping sound "fft_loop_never" should be stopped for me exactly once

  Scenario: Two loops are tracked and stopped independently
    Given I listen for sounds addressed to me
    When the sound service loops "Cuff" to me as "fft_loop_a" at volume 0.05
    And the sound service loops "Uncuff" to me as "fft_loop_b" at volume 0.05
    And the sound service stops the loop "fft_loop_a"
    Then the looping sound "fft_loop_a" should be stopped for me
    And the looping sound "fft_loop_b" should not be stopped for me
    When the sound service stops the loop "fft_loop_b"
    Then the looping sound "fft_loop_b" should be stopped for me

  Scenario: A stopped loop can be started again under the same id
    Given I listen for sounds addressed to me
    When the sound service loops "Cuff" to me as "fft_loop_again" at volume 0.05
    And the sound service stops the loop "fft_loop_again"
    And the sound service loops "Cuff" to me as "fft_loop_again" at volume 0.05
    Then the looping sound "fft_loop_again" should have started for me exactly 2 times
    When the sound service stops the loop "fft_loop_again"
    Then the looping sound "fft_loop_again" should be stopped for me exactly 2 times

  # stopSound returns before sending anything when the id is nil (server/main.lua:85).
  @rejection
  Scenario: A stop request without an id sends nothing
    Given I listen for sounds addressed to me
    When the sound service stops a loop without naming it
    Then no loop stop should reach me

  # An id with no tracked loop is stopped by broadcast (server/main.lua:91-92):
  # every client receives a StopSound for an id none of them is playing.
  @global
  Scenario: Stopping an untracked loop id is broadcast
    Given I listen for sounds addressed to me
    When the sound service stops the loop "fft_loop_untracked"
    Then the looping sound "fft_loop_untracked" should be stopped for me

  # validVolume accepts numbers from 0 to 2 inclusive (server/main.lua:26-30);
  # anything else is dropped and the preset is used.
  Scenario Outline: Client request volume boundaries
    Given I listen for sounds addressed to me
    When I request the sound "Cuff" for myself at volume <requested>
    Then the sound "Cuff" should be played to me at volume <delivered>

    Examples: accepted as sent
      | requested | delivered |
      | 0.0       | 0.0       |
      | 0.01      | 0.01      |
      | 1.0       | 1.0       |
      | 2.0       | 2.0       |

    Examples: replaced by the interaction preset
      | requested | delivered |
      | 2.01      | 0.3       |
      | -0.01     | 0.3       |
      | -1.0      | 0.3       |
      | 1000.0    | 0.3       |

  @rejection
  Scenario Outline: Client request with a non-numeric volume falls back to the preset
    Given I listen for sounds addressed to me
    When I request the sound "Alert" for myself with the text volume "<volume>"
    Then the sound "Alert" should be played to me at volume 0.6

    Examples:
      | volume |
      | 0.05   |
      | loud   |
      |        |

  # validSoundFile: ^[%w_%-]+$ and at most 128 characters (server/main.lua:22-24).
  Scenario Outline: Client request accepts a plain file name
    Given I listen for sounds addressed to me
    When I request the sound "<name>" for myself at volume 0.05
    Then the sound "<name>" should be played to me at volume 0.05

    Examples:
      | name             |
      | security-alarm   |
      | coffee_machine   |
      | radiostatic2     |
      | fft_Unlisted-123 |

  @rejection
  Scenario Outline: Client request with a malformed file name is dropped
    Given I listen for sounds addressed to me
    When I request the sound "<name>" for myself at volume 0.05
    Then no sound should be played to me

    Examples:
      | name           |
      |                |
      | Cuff Uncuff    |
      | ..             |
      | Cuff?x=1       |
      | Cuff#          |
      | Cuff%2e        |
      | Cüff           |
      | https://x/Cuff |

  Scenario: A file name of exactly 128 characters is accepted
    Given I listen for sounds addressed to me
    When I request a sound with a 128 character name for myself
    Then a sound with a 128 character name should be played to me

  @rejection
  Scenario: A file name of 129 characters is dropped
    Given I listen for sounds addressed to me
    When I request a sound with a 129 character name for myself
    Then no sound should be played to me

  @rejection
  Scenario Outline: A file name that is not text is dropped
    Given I listen for sounds addressed to me
    When I request a sound named by a <kind> for myself
    Then no sound should be played to me

    Examples:
      | kind    |
      | number  |
      | table   |
      | boolean |
      | nothing |

  # passesCooldown runs before validation (server/main.lua:114-115), so a
  # dropped request still starts the cooldown.
  @rejection
  Scenario: An invalid request still starts the cooldown
    Given I listen for sounds addressed to me
    When I request the invalid sound "../Cuff" and then "Cuff" for myself without pausing
    Then no sound should be played to me

  Scenario: A request after the cooldown has lapsed is delivered
    Given I listen for sounds addressed to me
    When I request the sound "Cuff" for myself twice with a pause of 600 milliseconds
    Then the sound "Cuff" should be played to me exactly 2 times

  # InteractSound_SV:PlayOnOne(target, file, volume), server/main.lua:113-119.
  Scenario: Targeted client request addressed to myself is delivered
    Given I listen for sounds addressed to me
    When I request the sound "Cuff" for my own server id at volume 0.05
    Then the sound "Cuff" should be played to me at volume 0.05

  Scenario: Targeted client request accepts my server id as text
    Given I listen for sounds addressed to me
    When I request the sound "Cuff" for my own server id written as text at volume 0.05
    Then the sound "Cuff" should be played to me at volume 0.05

  Scenario: Targeted client request without a volume uses the preset
    Given I listen for sounds addressed to me
    When I request the sound "Alert" for my own server id without a volume
    Then the sound "Alert" should be played to me at volume 0.6

  @rejection
  Scenario Outline: Targeted client request with an invalid target is dropped
    Given I listen for sounds addressed to me
    When I request the sound "Cuff" for the target "<target>" at volume 0.05
    Then no sound should be played to me

    Examples:
      | target       |
      | fft_nobody   |
      |              |
      | 0            |
      | 64999        |

  @rejection
  Scenario: Targeted client request with an unsafe file name is dropped
    Given I listen for sounds addressed to me
    When I request the sound "../Cuff" for my own server id at volume 0.05
    Then no sound should be played to me

  # One cooldown table for every InteractSound_SV entry point (server/main.lua:6-14).
  @rejection
  Scenario: The cooldown is shared between the legacy entry points
    Given I listen for sounds addressed to me
    When I request "Cuff" for my own server id and then "Uncuff" for myself without pausing
    Then the sound "Cuff" should be played to me exactly once
    And the sound "Uncuff" should not be played to me

  # Area playback with a radius of 0 reaches only a player standing exactly on
  # the point, which is the tester (server/main.lua:66-71; Config.falloffVolume
  # returns the base volume when the radius is not positive).
  Scenario: Area playback centred on me with no radius reaches me at full volume
    Given I listen for sounds addressed to me
    When the sound service plays "Cuff" in a 0.0 metre area centred on me at volume 0.05
    Then the sound "Cuff" should be played to me at volume 0.05

  Scenario: Area playback without a volume uses the category preset
    Given I listen for sounds addressed to me
    When the sound service plays "Alert" in a 0.0 metre area centred on me at its preset volume
    Then the sound "Alert" should be played to me at volume 0.6

  Scenario: Area loop is tracked and stopped for its listener
    Given I listen for sounds addressed to me
    When the sound service loops "Cuff" as "fft_loop_area" in a 0.0 metre area centred on me at volume 0.05
    Then the looping sound "Cuff" should start for me as "fft_loop_area" at volume 0.05
    When the sound service stops the loop "fft_loop_area"
    Then the looping sound "fft_loop_area" should be stopped for me exactly once

  Scenario: Legacy distance request with no range reaches only me
    Given I listen for sounds addressed to me
    When I request the sound "Cuff" within 0 metres of myself at volume 0.05
    Then the sound "Cuff" should be played to me at volume 0.05

  @rejection
  Scenario: Legacy distance request with an unsafe file name is dropped
    Given I listen for sounds addressed to me
    When I request the sound "sounds/Cuff" within 0 metres of myself at volume 0.05
    Then no sound should be played to me

  # The remaining area scenarios use a 2 metre sphere whose centre is directly
  # above the tester. Another player standing within 2 metres of that point
  # would hear the same short sound, hence @global.
  # Config.falloffVolume (config.lua:46-50): volume * (1 - distance / radius),
  # floored at Config.minFalloffVolume = 0.05.
  @global @world
  Scenario Outline: Area playback fades with distance from the centre
    Given I listen for sounds addressed to me
    When the sound service plays "Cuff" in a 2.0 metre area centred <above> metres above me at volume <volume>
    Then the sound "Cuff" should be played to me at roughly volume <delivered>

    Examples:
      | above | volume | delivered |
      | 1.0   | 1.0    | 0.5       |
      | 0.5   | 0.4    | 0.3       |
      | 1.9   | 0.5    | 0.05      |
      | 1.0   | 0.05   | 0.05      |

  @global @world @rejection
  Scenario: Area playback does not reach a player outside the radius
    Given I listen for sounds addressed to me
    When the sound service plays "Cuff" in a 2.0 metre area centred 3.0 metres above me at volume 0.5
    Then no sound should be played to me
