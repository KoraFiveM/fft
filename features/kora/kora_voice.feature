@kora @kora_voice
Feature: kora_voice radio, call and proximity authority
  Membership is asserted on the server only: the store exports, the state bag
  keys kora_voice:radio and kora_voice:call, and the local server events. Client
  steps only request and read the server's answer. Every join is preceded by a
  check that the channel has no members, so a scenario fails rather than put
  the tester on a channel with another player. Frequency 947 and call id
  987654321 are arbitrary unused test channels.

  Client radio requests are limited to 10 per 10 seconds (one limiter shared by
  the callbacks and the pma-voice events). The suite's request steps pace
  themselves at 8 per 10.5 seconds across scenarios; the original radio item
  scenario still waits out the window first because its generic dialog steps
  are not paced. The limit itself is not tested because exhausting it would
  fail the scenarios that follow. Channel 948 is a second unused test
  frequency and calls 987654322 and 123456 are further unused test calls.

  Not covered: audio (Mumble targets, submixes, muffling, push-to-talk), the
  roster push to other members, and routing-bucket filtering. They need a
  second player or cannot be observed without a hook.

  Background:
    Given resource "kora_voice" is running
    And I start with no voice radio channel and no voice call

  @server
  Scenario: A trusted assignment publishes radio membership
    When voice puts me on radio channel 947
    Then I should be on voice radio channel 947
    And a voice radio change to channel 947 should have been published for me

  @server @rejection
  Scenario: Removal is guarded by the channel the player is on
    Given voice puts me on radio channel 947
    Then removing me from voice radio channel 946 should return false
    And I should be on voice radio channel 947
    And removing me from voice radio channel 947 should return true
    And I should be on no voice radio channel
    And a voice radio change to no channel should have been published for me

  @server @rejection
  Scenario Outline: An invalid radio channel is refused and membership is kept
    Given voice puts me on radio channel 947
    Then voice should refuse to put me on the radio channel "<channel>"
    And I should be on voice radio channel 947

    Examples:
      | channel |
      | 1001    |
      | abc     |

  @server
  Scenario: Restricted channels are reported to server code
    Then the voice radio channel 1 should be restricted
    And the voice radio channel 2 should be restricted
    And the voice radio channel 10 should be restricted
    And the voice radio channel 20 should be restricted
    And the voice radio channel 947 should be open

  Scenario: A client request for an open channel is granted and can be left
    Given the voice radio channel 947 has no members
    When I request the voice radio channel 947
    Then my voice radio request should be granted
    And I should be on voice radio channel 947
    When I leave my voice radio channel
    Then I should be on no voice radio channel

  @rejection
  Scenario: A restricted channel is refused without the job
    Given my job is "unemployed" at grade 1
    And the voice radio channel 1 has no members
    When I request the voice radio channel 1
    Then my voice radio request should be refused with "That frequency is restricted."
    And I should be on no voice radio channel

  @rejection
  Scenario: A restricted channel is refused while off duty
    Given I am off duty as "police" at grade 1
    And the voice radio channel 2 has no members
    When I request the voice radio channel 2
    Then my voice radio request should be refused with "That frequency is restricted."
    And I should be on no voice radio channel

  Scenario: A granted channel overrides the restriction
    Given my job is "unemployed" at grade 1
    And the voice radio channel 2 has no members
    And I am granted the voice radio channel 2
    When I request the voice radio channel 2
    Then my voice radio request should be granted
    And I should be on voice radio channel 2

  Scenario: A recovery job joins its channel off duty
    Given I am off duty as "tow" at grade 1
    And the voice radio channel 20 has no members
    When I request the voice radio channel 20
    Then my voice radio request should be granted
    And I should be on voice radio channel 20

  @rejection
  Scenario: The legacy join event is held to the same policy
    Given my job is "unemployed" at grade 1
    And the voice radio channel 1 has no members
    When I send the legacy voice radio join event for channel 1
    And I wait 1000 milliseconds
    Then I should be on no voice radio channel

  @server
  Scenario: Call membership is separate from radio membership
    Given voice puts me on radio channel 947
    When voice puts me in call 987654321
    Then I should be in voice call 987654321
    And a voice call change to channel 987654321 should have been published for me
    And I should be on voice radio channel 947
    And removing me from voice call 123 should return false
    And removing me from voice call 987654321 should return true
    And I should be in no voice call
    And I should be on voice radio channel 947

  @server @rejection
  Scenario: An invalid call channel is refused
    Then voice should refuse to put me in the call "1000000000"
    And I should be in no voice call

  Scenario: Proximity modes clamp, wrap and yield to the megaphone
    Given I remember my voice settings
    When I set my voice mode to "whisper"
    Then my voice mode should be "whisper" at index 1
    And my voice range should be 3.0
    When I set my voice mode to index 47
    Then my voice mode should be "shout" at index 3
    And my voice range should be 35.0
    When I cycle my voice mode
    Then my voice mode should be "whisper" at index 1
    And I should see a notification containing "Whisper"
    When I switch my voice megaphone on
    Then my voice range should be 50.0
    When I switch my voice megaphone off
    Then my voice range should be 3.0

  @rejection
  Scenario: Local audio properties are bounded
    Given I remember my voice settings
    When I set my voice radio volume to 50
    Then my voice radio volume should be 0.5
    And setting the unknown voice property "fft_no_such_property" should fail

  @ui @slow
  Scenario: The radio item opens the frequency dialog
    Given I hold 1 "radio"
    And the voice radio channel 947 has no members
    And I wait 11000 milliseconds
    When I use my voice radio item
    Then an input dialog should open
    When I submit the input dialog with:
      """
      { "channel": 947 }
      """
    Then I should see a notification containing "Connected to frequency 947"
    And I should be on voice radio channel 947
    When I use my voice radio item
    Then an input dialog should open
    When I submit the input dialog with:
      """
      { "channel": 0 }
      """
    Then I should see a notification containing "You left the frequency."
    And I should be on no voice radio channel

  # ---------------------------------------------------------------------------
  # Trusted radio assignment (server/api.lua A.assign, shared/channels.lua)
  # ---------------------------------------------------------------------------

  @server
  Scenario Outline: A fractional or textual radio channel is normalised to a whole channel
    When voice puts me on the radio channel "<value>"
    Then I should be on voice radio channel 947

    Examples:
      | value |
      | 947.9 |
      | 947   |

  # A.assign is trusted and skips policy, so restricted channel 1 is accepted.
  @server
  Scenario Outline: The radio channel bounds are accepted by trusted assignment
    Given my job is "unemployed" at grade 1
    When voice puts me on radio channel <channel>
    Then I should be on voice radio channel <channel>

    Examples:
      | channel |
      | 1       |
      | 1000    |

  @server @rejection
  Scenario Outline: An unusable radio channel is refused and does not count as leaving
    Given voice puts me on radio channel 947
    Then voice should refuse to put me on the radio channel "<channel>"
    And I should be on voice radio channel 947
    And 1 voice radio changes should have been published for me

    Examples:
      | channel |
      | 0       |
      | -1      |
      |         |
      | nan     |
      | 947abc  |

  @server
  Scenario: An explicit false takes the player off the radio
    Given voice puts me on radio channel 947
    When voice takes me off the radio
    Then I should be on no voice radio channel
    And the voice radio state bag should read no channel
    And a voice radio change to no channel should have been published for me
    And I should not be listed on voice radio channel 947

  @server
  Scenario: Assigning the same radio channel twice publishes once
    When voice puts me on radio channel 947
    And voice puts me on radio channel 947
    Then I should be on voice radio channel 947
    And 1 voice radio changes should have been published for me

  @server
  Scenario: Moving between radio channels publishes the previous channel
    Given voice puts me on radio channel 947
    When voice puts me on radio channel 948
    Then I should be on voice radio channel 948
    And a voice radio change from channel 947 to channel 948 should have been published for me
    And I should not be listed on voice radio channel 947
    And 2 voice radio changes should have been published for me

  @server
  Scenario: Unguarded removal takes the player off any channel and is then a no-op
    Given voice puts me on radio channel 947
    Then removing me from my voice radio channel without a guard should return true
    And I should be on no voice radio channel
    And removing me from my voice radio channel without a guard should return false
    And removing me from voice radio channel 947 should return false
    And 2 voice radio changes should have been published for me

  @server
  Scenario: The pma-voice member map lists the player
    Given voice puts me on radio channel 947
    Then the voice radio member map for channel 947 should include me

  @server
  Scenario: The pma-voice export identity reaches the same membership
    When the pma-voice export puts me on radio channel 947
    Then I should be on voice radio channel 947
    And the pma-voice export should report voice radio channel 947 for me

  # ---------------------------------------------------------------------------
  # Calls (server/api.lua A.assignCall; Config.calls 1-999999999)
  # ---------------------------------------------------------------------------

  @server
  Scenario Outline: The call channel bounds are accepted
    When voice puts me in the call "<value>"
    Then I should be in voice call <call>
    And the voice call member map for call <call> should include me

    Examples:
      | value     | call      |
      | 1         | 1         |
      | 999999999 | 999999999 |
      | 123456.9  | 123456    |

  @server @rejection
  Scenario Outline: An unusable call channel is refused
    Given voice puts me in call 987654321
    Then voice should refuse to put me in the call "<call>"
    And I should be in voice call 987654321

    Examples:
      | call |
      | 0    |
      | -1   |
      |      |
      | abc  |

  @server
  Scenario: Moving between calls publishes once per change and records the previous call
    Given voice puts me in call 987654321
    When voice puts me in call 987654321
    And voice puts me in call 987654322
    Then I should be in voice call 987654322
    And a voice call change from channel 987654321 to channel 987654322 should have been published for me
    And 2 voice call changes should have been published for me
    And 0 voice radio changes should have been published for me

  @server
  Scenario: Unguarded call removal clears the call state bag with false
    Given voice puts me in call 987654321
    Then removing me from my voice call without a guard should return true
    And I should be in no voice call
    And the voice call state bag should read no channel
    And a voice call change to no channel should have been published for me
    And removing me from my voice call without a guard should return false

  # ---------------------------------------------------------------------------
  # Restriction lookup and grants (config.lua radio.restricted, server/policy.lua)
  # ---------------------------------------------------------------------------

  @server
  Scenario Outline: Channels next to the restricted ones are open
    Then the voice radio channel <channel> should be open

    Examples:
      | channel |
      | 3       |
      | 9       |
      | 11      |
      | 19      |
      | 21      |
      | 1000    |

  @server
  Scenario Outline: Channel ids that do not normalise are reported unrestricted
    Then the voice radio channel "<channel>" should be reported unrestricted

    Examples:
      | channel |
      | 0       |
      | 1001    |
      | abc     |
      |         |

  @server
  Scenario Outline: Grants count only distinct valid channels
    Then granting me the voice radio channels "<channels>" should count <count>
    And revoking my voice radio grants should count 0

    Examples:
      | channels     | count |
      | 947, 947, 2  | 2     |
      | 0, 1001      | 0     |
      | abc          | 0     |
      | 2            | 1     |
      | 1, 2, 10, 20 | 4     |
      |              | 0     |

  @rejection
  Scenario: A revoked grant no longer opens a restricted channel
    Given my job is "unemployed" at grade 1
    And the voice radio channel 2 has no members
    And granting me the voice radio channels "2" should count 1
    And revoking my voice radio grants should count 0
    When I request the voice radio channel 2
    Then my voice radio request should be refused with "That frequency is restricted."
    And I should be on no voice radio channel

  Scenario: A grant of several channels opens each of them
    Given my job is "unemployed" at grade 1
    And the voice radio channel 1 has no members
    And the voice radio channel 2 has no members
    And granting me the voice radio channels "1, 2" should count 2
    When I request the voice radio channel 1
    Then my voice radio request should be granted
    And I should be on voice radio channel 1
    When I request the voice radio channel 2
    Then my voice radio request should be granted
    And I should be on voice radio channel 2
    And a voice radio change from channel 1 to channel 2 should have been published for me

  # ---------------------------------------------------------------------------
  # Job policy for client requests (config.lua radio.restricted; kora_core jobs:
  # police type leo, ambulance type ems, tow type recovery)
  # ---------------------------------------------------------------------------

  Scenario Outline: A qualifying job is granted its restricted channel
    Given I am <duty> duty as "<job>" at grade 1
    And the voice radio channel <channel> has no members
    When I request the voice radio channel <channel>
    Then my voice radio request should be granted
    And I should be on voice radio channel <channel>

    Examples:
      | duty | job       | channel |
      | on   | police    | 1       |
      | on   | police    | 2       |
      | on   | ambulance | 10      |
      | on   | tow       | 20      |

  @rejection
  Scenario Outline: A job of the wrong type or off duty is refused a restricted channel
    Given I am <duty> duty as "<job>" at grade 1
    And the voice radio channel <channel> has no members
    When I request the voice radio channel <channel>
    Then my voice radio request should be refused with "That frequency is restricted."
    And I should be on no voice radio channel
    And 0 voice radio changes should have been published for me

    Examples:
      | duty | job       | channel |
      | off  | ambulance | 10      |
      | on   | police    | 10      |
      | on   | ambulance | 1       |
      | on   | tow       | 2       |

  # ---------------------------------------------------------------------------
  # Client requests, leaving and the client's published mirror
  # ---------------------------------------------------------------------------

  Scenario: Requesting frequency 0 leaves the current channel
    Given voice puts me on radio channel 947
    When I request the voice radio channel 0
    Then my voice radio request should be granted
    And I should be on no voice radio channel

  Scenario: Leaving without a channel is allowed and changes nothing
    Then leaving my voice radio channel should return true
    And I should be on no voice radio channel
    And 0 voice radio changes should have been published for me

  Scenario: The client mirrors the radio channel the server published
    Given voice puts me on radio channel 947
    Then my voice client should mirror radio channel 947
    When voice takes me off the radio
    Then my voice client should mirror no radio channel

  Scenario: Hanging up a call from the client leaves it once
    Given voice puts me in call 987654321
    Then my voice client should mirror call 987654321
    And I hang up my voice call and it should return true
    And I should be in no voice call
    And a voice call change to no channel should have been published for me
    And my voice client should mirror no call
    And I hang up my voice call and it should return false

  # server/compat.lua: every pma-voice event is a request for `source`.
  Scenario: The pma-voice radio events join, switch and guard removal
    Given the voice radio channel 947 has no members
    And the voice radio channel 948 has no members
    When I send the legacy voice set radio event for channel 947
    Then I should be on voice radio channel 947
    When I send the legacy voice add radio event for channel 948
    Then I should be on voice radio channel 948
    When I send the legacy voice remove radio event for channel 947
    And I wait 1000 milliseconds
    Then I should be on voice radio channel 948
    When I send the legacy voice remove radio event for channel 948
    Then I should be on no voice radio channel

  @rejection
  Scenario: The pma-voice add event is held to the restriction policy
    Given my job is "unemployed" at grade 1
    And the voice radio channel 2 has no members
    When I send the legacy voice add radio event for channel 2
    And I wait 1000 milliseconds
    Then I should be on no voice radio channel

  Scenario: The pma-voice call removal event hangs up the sender
    Given voice puts me in call 987654321
    When I send the legacy voice call removal event
    Then I should be in no voice call

  @server
  Scenario: Voice targets can be refreshed for a player id only
    Then refreshing my voice targets should succeed
    And refreshing voice targets for "abc" should fail with "kora_voice: src must be a number"

  # ---------------------------------------------------------------------------
  # Proximity (shared/modes.lua clamp/next, client/proximity.lua)
  # ---------------------------------------------------------------------------

  Scenario Outline: Any requested voice mode resolves to a configured mode
    Given I remember my voice settings
    And I set my voice mode to "whisper"
    When I set my voice mode to "<value>"
    Then my voice mode should be "<mode>" at index <index>
    And my voice range should be <range>

    Examples:
      | value | mode    | index | range |
      | shout | shout   | 3     | 35.0  |
      | 3     | shout   | 3     | 35.0  |
      | 2.7   | normal  | 2     | 12.0  |
      | 0     | normal  | 2     | 12.0  |
      | -3    | normal  | 2     | 12.0  |
      | yell  | normal  | 2     | 12.0  |
      |       | normal  | 2     | 12.0  |
      | 1     | whisper | 1     | 3.0   |

  Scenario Outline: Cycling the voice mode wraps in both directions
    Given I remember my voice settings
    And I set my voice mode to "<from>"
    When I cycle my voice mode by <step>
    Then my voice mode should be "<to>" at index <index>
    And I should see a notification containing "<label> (<metres>m)"

    Examples:
      | from    | step | to      | index | label   | metres |
      | whisper | 1    | normal  | 2     | Normal  | 12     |
      | normal  | 1    | shout   | 3     | Shout   | 35     |
      | shout   | 1    | whisper | 1     | Whisper | 3      |
      | whisper | -1   | shout   | 3     | Shout   | 35     |
      | shout   | -1   | normal  | 2     | Normal  | 12     |
      | normal  | 2    | whisper | 1     | Whisper | 3      |
      | whisper | 0    | whisper | 1     | Whisper | 3      |

  Scenario: The megaphone overrides shout range and repeated switches are no-ops
    Given I remember my voice settings
    And I set my voice mode to "shout"
    When I switch my voice megaphone on
    Then my voice range should be 50.0
    And my voice mode should be "shout" at index 3
    And switching my voice megaphone on again should report no change
    When I switch my voice megaphone off
    Then my voice range should be 35.0
    And switching my voice megaphone off again should report no change

  # ---------------------------------------------------------------------------
  # Local audio properties (client/state.lua setVolume, client/exports.lua)
  # ---------------------------------------------------------------------------

  Scenario Outline: Radio volume accepts fractions and percentages and is clamped
    Given I remember my voice settings
    When I set my voice radio volume to "<value>"
    Then my voice radio volume property should be <volume>

    Examples:
      | value | volume |
      | 50    | 0.5    |
      | 0.25  | 0.25   |
      | 1     | 1.0    |
      | 150   | 1.0    |
      | -3    | 0.0    |
      | 1.5   | 0.015  |
      | abc   | 1.0    |

  Scenario Outline: Call volume follows the same rules
    Given I remember my voice settings
    When I set my voice call volume to "<value>"
    Then my voice call volume property should be <volume>

    Examples:
      | value | volume |
      | 30    | 0.3    |
      | 150   | 1.0    |
      | -1    | 0.0    |

  Scenario: The pma-voice property setters reach volume and talking mode
    Given I remember my voice settings
    When I set the voice property "radioVolume" to the value "30"
    Then my voice radio volume property should be 0.3
    When I set the voice property "talkingMode" to the value "whisper"
    Then the voice property "talkingMode" should be the number 1
    And my voice mode should be "whisper" at index 1

  Scenario Outline: Local voice toggles can be switched and are restored
    When I set the voice property "<property>" to <value>
    Then the voice property "<property>" should be <value>

    Examples:
      | property  | value |
      | micClicks | false |
      | submix    | false |
      | muffling  | false |
      | micClicks | true  |

  @rejection
  Scenario: An unknown voice property reads as nothing
    Then the voice property "fft_no_such_property" should be nothing

  # ---------------------------------------------------------------------------
  # Radio item dialog (client/radio_item.lua)
  # ---------------------------------------------------------------------------

  @ui @rejection
  Scenario Outline: The radio dialog refuses an unusable frequency without a request
    Given I hold 1 "radio"
    When I use my voice radio item
    Then an input dialog should open
    When I enter the voice radio frequency "<entry>"
    Then I should see a notification containing "<message>"
    And I should be on no voice radio channel

    Examples:
      | entry | message                               |
      | 1001  | Frequency must be between 1 and 1000. |
      | -5    | Frequency must be between 1 and 1000. |
      | 2.5   | Enter a whole frequency number.       |
      | abc   | Enter a whole frequency number.       |

  @ui @rejection
  Scenario: The radio dialog relays the server's refusal of a restricted frequency
    Given I hold 1 "radio"
    And my job is "unemployed" at grade 1
    And the voice radio channel 1 has no members
    When I use my voice radio item
    Then an input dialog should open
    When I enter the voice radio frequency "1"
    Then I should see a notification containing "That frequency is restricted."
    And I should be on no voice radio channel

  @ui
  Scenario: Cancelling the radio dialog keeps the current frequency
    Given I hold 1 "radio"
    And voice puts me on radio channel 947
    When I use my voice radio item
    Then an input dialog should open
    When I cancel the input dialog
    And I wait 1000 milliseconds
    Then I should be on voice radio channel 947
    And 1 voice radio changes should have been published for me

  @ui
  Scenario: An empty radio dialog entry leaves the frequency
    Given I hold 1 "radio"
    And voice puts me on radio channel 947
    When I use my voice radio item
    Then an input dialog should open
    When I enter the voice radio frequency ""
    Then I should see a notification containing "You left the frequency."
    And I should be on no voice radio channel

  # Channel checks and policy hooks (kora_voice/server/policy.lua). Only client
  # requests are evaluated against them; the trusted setPlayerRadio path is not.

  @server @rejection
  Scenario: A channel check refuses a request that a grant would allow
    Given the voice radio channel 948 has no members
    And I register a voice channel check on 948 that refuses
    And I am granted the voice radio channel 948
    When I request the voice radio channel 948
    Then my voice radio request should be refused with "That frequency is restricted."
    And I should be on no voice radio channel
    And I remove the voice channel check on 948

  @server
  Scenario: A channel check that allows opens a restricted channel to the request
    Given the voice radio channel 20 has no members
    And I register a voice channel check on 20 that allows
    When I request the voice radio channel 20
    Then my voice radio request should be granted
    And I should be on voice radio channel 20
    And I remove the voice channel check on 20

  @server @rejection
  Scenario: A channel check takes precedence over a policy hook for the same channel
    Given the voice radio channel 948 has no members
    And I register a voice radio policy "allow" that allows channel 948
    And I register a voice channel check on 948 that refuses
    When I request the voice radio channel 948
    Then my voice radio request should be refused with "That frequency is restricted."
    And I remove the voice channel check on 948

  @server @rejection
  Scenario: The first policy hook with a definite answer decides the request
    Given the voice radio channel 948 has no members
    And I register a voice radio policy "first" that refuses channel 948 with "First hook refused"
    And I register a voice radio policy "second" that allows channel 948
    When I request the voice radio channel 948
    Then my voice radio request should be refused with "First hook refused"
    And I remove the voice radio policy "first" should return true
    When I request the voice radio channel 948
    Then my voice radio request should be granted

  @server
  Scenario: A policy hook that allows opens a restricted channel only while it is registered
    Given the voice radio channel 20 has no members
    And I register a voice radio policy "open" that allows channel 20
    When I request the voice radio channel 20
    Then my voice radio request should be granted
    When I leave my voice radio channel
    Then I should be on no voice radio channel
    And I remove the voice radio policy "open" should return true
    When I request the voice radio channel 20
    Then my voice radio request should be refused with "That frequency is restricted."

  @server
  Scenario: A policy hook that abstains leaves a restricted channel to the restriction
    Given the voice radio channel 20 has no members
    And I register a voice radio policy "quiet" that abstains
    When I request the voice radio channel 20
    Then my voice radio request should be refused with "That frequency is restricted."

  @server
  Scenario: A policy hook that abstains leaves an open channel open
    Given the voice radio channel 948 has no members
    And I register a voice radio policy "quiet" that abstains
    When I request the voice radio channel 948
    Then my voice radio request should be granted

  @server
  Scenario: A policy hook that errors abstains and does not lock the radio
    Given the voice radio channel 948 has no members
    And I register a voice radio policy "broken" that errors
    When I request the voice radio channel 948
    Then my voice radio request should be granted

  @server @rejection
  Scenario: A channel check and a policy hook must be well formed
    Given registering a voice channel check on 948 with a non-callable should fail
    And registering a voice channel check on "1001" should fail
    And registering a voice radio policy with a non-callable should fail
    When I request the voice radio channel 948
    Then my voice radio request should be granted

  @server
  Scenario: Removing a policy hook twice, or a handle never issued, is harmless
    Given I register a voice radio policy "once" that refuses channel 948 with "Once"
    Then I remove the voice radio policy "once" should return true
    And I remove the voice radio policy "once" should return false
    And removing voice radio policy handle 0 should return false
    And removing voice radio policy handle 999 should return false
    When I request the voice radio channel 948
    Then my voice radio request should be granted

  @server
  Scenario: Holding a radio channel without transmitting is not radio activity
    Given the voice radio channel 948 has no members
    When I request the voice radio channel 948
    Then my voice radio request should be granted
    And the voice export isRadioActive should be false
