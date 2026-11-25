@kora @kora_phone
Feature: kora_phone folder apps without a handset
  What the reworked phone (KoraFiveM/kora_phone PR #54) does for a character who holds no handset: the exports, the
  SDK exports, the route gateway, every app callback gate, and the client handlers that need no handset (Maps, Clock,
  Camera). Routes and app callbacks are called at the NUI-callback level through the phone's own callbacks, so the
  server checks and rate limits apply; nothing clicks the rendered phone page.

  Why no handset: the first bootstrap with a handset inserts phone_devices and phone_handsets rows the resource cannot
  delete, so a run would leave rows behind. Without one, nothing here can message, call, mail, pay or post; every such
  callback is asserted refused, with an invalid payload as a second guard. What this proves: the gate refuses before any
  app code runs. It does not prove that an app registered, or what its callbacks do for a player who holds a handset.

  Not covered: anything that needs a handset (setup, PIN, contacts, notes, messages, calls, mail, wallet, social, market,
  gallery, SIM and cloud), the rendered pages, and the Camera game view (the render texture inside the app frame).
  A folder app's page, its iframe open time and the lb-phone page shim need a client that renders the phone.

  Rate buckets: app callbacks and apps:* routes share the sdk bucket (40, refilling 10 a second). Each scenario stays
  well inside it.

  Background:
    Given resource "kora_phone" is running
    And I hold no kora_phone handset

  @server
  Scenario: Without a handset the character has no number
    Then the kora_phone number export should report no number for me
    And the kora_phone number lookup for "5550000000" should find nobody
    And the kora_phone number lookup for "not a number" should find nobody
    And kora_phone should not resell inventory slot 1
    And kora_phone should list no installed apps for me

  @server
  Scenario: The reset command is registered
    Then the kora_phone command "phonereset" should be registered

  @server @rejection
  Scenario Outline: A malformed app manifest is refused
    Then kora_phone should refuse the app manifest:
      """
      <manifest>
      """

    Examples:
      | manifest                                                                  |
      | { "id": "Bad Id", "name": "x", "icon": "star", "entry": "ui/index.html" } |
      | { "id": "fft_no_entry", "name": "x", "icon": "star" }                     |
      | { "id": "fft_bad_perm", "name": "x", "icon": "star", "entry": "ui/index.html", "permissions": ["root"] } |
      | { "id": "fft_bad_field", "name": "x", "icon": "star", "entry": "ui/index.html", "shell": true } |
      | { "id": "fft_bad_embed", "name": "x", "icon": "star", "entry": "ui/index.html", "embeds": ["https://evil.example"] } |

  @server @rejection
  Scenario: Unknown apps cannot be removed or messaged
    Then kora_phone should not remove the unknown app "fft_never_registered"
    And kora_phone should refuse an app event to the unknown app "fft_never_registered"

  Scenario: Notifications reach a closed phone
    Given my kora_phone is put away
    When kora_phone sends me the notification "FFT server probe" with body "fft kora_phone server notification"
    Then I should see a notification containing "fft kora_phone server notification"
    When I push the local kora_phone notification "FFT client probe" with message "fft kora_phone client notification"
    Then I should see a notification containing "fft kora_phone client notification"

  @rejection
  Scenario: Malformed notifications are refused
    Then kora_phone should refuse to send me a malformed notification
    And kora_phone should reject a local notification without a title

  @rejection
  Scenario: The phone puts itself away without a handset
    Given my kora_phone is put away
    When I open the kora_phone through its export
    Then I should see a notification containing "No handset available"
    And my kora_phone should be put away

  @ui @rejection
  Scenario: The bootstrap is refused without a handset
    When I call the kora_phone route "bootstrap"
    Then the kora_phone route should be refused with code "FORBIDDEN" and message "No handset available"

  @ui @rejection
  Scenario Outline: Every phone data route is refused without a handset
    When I call the kora_phone route "<route>"
    Then the kora_phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"

    Examples:
      | route          |
      | contacts:list  |
      | blocks:list    |
      | gallery:list   |
      | settings:save  |
      | apps:list      |

  @ui @rejection
  Scenario: Saving and sending are refused without a handset
    When I call the kora_phone route "contacts:create" with:
      """
      { "displayName": "", "phoneNumber": "invalid" }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN"
    When I call the kora_phone route "blocks:set" with:
      """
      { "number": "invalid", "blocked": true }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN"
    When I call the kora_phone route "calls:start" with:
      """
      { "number": "invalid" }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN"
    When I call the kora_phone route "media:request" with:
      """
      { "mimeType": "fft/invalid", "byteSize": -1 }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN"
    When I call the kora_phone route "security:setPin" with:
      """
      { "pin": "x" }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN"

  @ui @rejection
  Scenario Outline: Folder app callbacks are refused before any app code runs
    When I call the kora_phone app "<app>" callback "<callback>"
    Then the kora_phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"

    Examples:
      | app         | callback      |
      | notes       | list          |
      | banking     | overview      |
      | banking     | idCard        |
      | mail        | inbox         |
      | classifieds | list          |
      | contacts    | list          |
      | phone       | recent        |
      | messages    | conversations |
      | gallery     | list          |
      | clock       | list          |
      | music       | list          |
      | settings    | photos        |
      | social      | conversations |
      | flash       | feed          |
      | camera      | config        |
      | services    | get           |
      | vehicles    | list          |
      | property    | list          |
      | moderation  | queue         |

  @ui @rejection
  Scenario: Money, posts and messages through an app are refused without a handset
    Given I remember my "bank" balance
    When I call the kora_phone app "banking" callback "transfer" with:
      """
      { "to": "invalid", "amount": -1 }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"
    And my "bank" balance should be unchanged
    When I call the kora_phone app "messages" callback "send" with:
      """
      { "conversationId": 1, "body": "" }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN"
    When I call the kora_phone app "flash" callback "post" with:
      """
      { "body": "" }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN"
    When I call the kora_phone app "classifieds" callback "create" with:
      """
      { "title": "" }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN"
    When I call the kora_phone app "social" callback "createGroup" with:
      """
      { "name": "", "numbers": [] }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN"

  @ui @rejection
  Scenario: Going on duty through the Work app is refused without a handset
    Given my job is "unemployed" at grade 1
    When I call the kora_phone app "services" callback "setDuty" with:
      """
      { "onDuty": false }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN"
    And my job should be "unemployed"

  @ui @rejection
  Scenario: App routes need a handset and a callback name that is allowed
    When I call the kora_phone route "apps:install" with:
      """
      { "app": "notes" }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN"
    When I call the kora_phone route "apps:storage:get" with:
      """
      { "app": "notes", "key": "x" }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN"
    When I call the kora_phone route "apps:contacts:list" with:
      """
      { "app": "notes" }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN"
    When I call the kora_phone route "apps:notify" with:
      """
      { "app": "notes", "title": "x" }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN"
    When I call the kora_phone route "apps:call" with:
      """
      { "app": "notes", "name": "../etc/passwd", "payload": {} }
      """
    Then the kora_phone route should be refused with code "INVALID_INPUT" and message "Invalid callback name"

  @ui @rejection
  Scenario: Handset operations need a held handset
    When I call the kora_phone route "handset:action" with:
      """
      { "op": "backup" }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"
    When I call the kora_phone route "handset:action" with:
      """
      { "op": "fft_unknown" }
      """
    Then the kora_phone route should be refused with code "FORBIDDEN"

  @ui @rejection
  Scenario: Unknown share requests and upload tokens are refused
    When I call the kora_phone route "share:answer" with:
      """
      { "id": "fft-unknown-share", "accept": true }
      """
    Then the kora_phone route should be refused with code "NOT_FOUND"
    When I call the kora_phone route "media:complete" with:
      """
      { "token": "fft-not-a-token" }
      """
    Then the kora_phone route should be refused with code "UNAUTHORIZED"

  @ui
  Scenario: Unlocking needs a phone but locking always answers
    When I call the kora_phone route "security:unlock" with:
      """
      { "pin": "0000" }
      """
    Then the kora_phone route should be refused with code "PHONE_REQUIRED"
    When I call the kora_phone route "security:lock"
    Then the kora_phone route should succeed

  @ui @rejection
  Scenario Outline: Routes that became app callbacks no longer exist
    Then the removed kora_phone route "<route>" should stay unanswered

    Examples:
      | route                     |
      | messages:getConversations |
      | messages:send             |
      | mail:list                 |
      | bank:getData              |
      | bank:transfer             |
      | wallet:get                |
      | items:save                |
      | moderation:getQueue       |
      | social:getFeed            |
      | market:getListings        |
      | property:list             |
      | garage:list               |
      | gallery:delete            |
      | calls:history             |
      | jobs:getData              |
      | map:blips                 |
      | alarm                     |

  @ui @rejection
  Scenario: An invalid waypoint is refused
    When I call the kora_phone route "waypoint" with:
      """
      { "x": "north", "y": 5 }
      """
    Then the kora_phone route should be refused with code "INVALID_INPUT" and message "That location is invalid"
    When I call the kora_phone route "waypoint" with:
      """
      { "x": 25000, "y": 0 }
      """
    Then the kora_phone route should be refused with code "INVALID_INPUT" and message "That location is invalid"

  @ui
  Scenario: Client routes report the phone state, position and weather
    Given my kora_phone is put away
    When I call the kora_phone route "phone:ready"
    Then the kora_phone route should succeed
    And the kora_phone route should report a loaded character and a closed phone
    When I call the kora_phone route "location:mine"
    Then the kora_phone route should succeed
    And the kora_phone route should report my current position
    When I call the kora_phone route "weather:get"
    Then the kora_phone route should succeed
    And the kora_phone route should report the game clock and weather

  @ui
  Scenario: The Maps app reports where the player is
    When I ask the kora_phone app "gps" on the client for "here"
    Then the kora_phone route should succeed
    And the kora_phone route should report my current position

  @ui
  Scenario: Pulse and Maps ignore an invalid waypoint
    When I ask the kora_phone app "gps" on the client for "waypoint" with:
      """
      { "x": "north", "y": 5 }
      """
    Then the kora_phone route should answer without success
    When I ask the kora_phone app "social" on the client for "waypoint" with:
      """
      { "x": 25000, "y": 0 }
      """
    Then the kora_phone route should answer without success

  @ui
  Scenario: A waypoint set from Maps is reported back
    Given my kora_phone map waypoint is restored afterwards
    When I ask the kora_phone app "gps" on the client for "waypoint" with:
      """
      { "x": 1500, "y": 3600 }
      """
    Then the kora_phone route should succeed
    And my map waypoint should be at 1500 3600 on the kora_phone map

  @ui @rejection
  Scenario: An unknown client handler does not answer
    When I ask the kora_phone app "gps" on the client for "fft_no_such_handler"
    Then the kora_phone route should answer without success

  @ui @rejection
  Scenario: Camera controls do nothing while the camera is closed
    Given my kora_phone is put away
    When I call the kora_phone route "camera:close"
    Then the kora_phone route should succeed
    When I ask the kora_phone app "camera" on the client for "zoom" with:
      """
      { "dir": 1 }
      """
    Then the kora_phone route should answer without success
    When I ask the kora_phone app "camera" on the client for "facing" with:
      """
      { "front": true }
      """
    Then the kora_phone route should answer without success
    When I ask the kora_phone app "camera" on the client for "recording" with:
      """
      { "active": true }
      """
    Then the kora_phone route should answer without success

  @ui
  Scenario: A registered blip shows in Maps until removed
    Given I add a kora_phone probe blip at 1500 3600 titled "FFT kora_phone map probe"
    Then the kora_phone map should list the probe blip titled "FFT kora_phone map probe"
    When I remove the probe blip from the kora_phone map
    Then the kora_phone map should not list the probe blip

  @rejection
  Scenario: Invalid map blips are refused
    Given I add a kora_phone probe blip at 1500 3600 titled "FFT kora_phone map probe"
    Then the kora_phone map should refuse the probe blip with a blank title
    And the kora_phone map should refuse the probe blip with a 161 character title
    And the kora_phone map should refuse a blip that does not exist

  @ui
  Scenario: The page notifies a closed phone only when it gives a title
    Given my kora_phone is put away
    When I call the kora_phone route "notify" with:
      """
      { "title": "FFT notify probe", "body": "fft kora_phone page notify body" }
      """
    Then the kora_phone route should succeed
    And I should see a notification containing "fft kora_phone page notify body"
    When I call the kora_phone route "notify" with:
      """
      { "body": "fft untitled notify body" }
      """
    Then the kora_phone route should succeed
    And I should not see a notification containing "fft untitled notify body"

  @ui
  Scenario: Alarms ring from the Clock app on a closed phone
    Given my kora_phone is put away
    And the kora_phone clock has an alarm for this minute labelled "fft wake up probe"
    Then I should see a notification containing "fft wake up probe"

  @ui @rejection
  Scenario: The Clock app drops a malformed alarm list
    Then the kora_phone clock should drop a malformed alarm list

  Scenario: A custom app is listed and removed
    Given I register the kora_phone custom app "fft_phone_probe" with ui "@fft/fft_probe/index.html"
    Then the kora_phone custom app list should include "fft_phone_probe"
    When I remove the kora_phone custom app "fft_phone_probe"
    Then the kora_phone custom app list should not include "fft_phone_probe"

  @rejection
  Scenario: Invalid custom apps are refused
    Then kora_phone should refuse a custom app without an identifier

  Scenario: Apps written for lb-phone register through its exports
    Given I register the kora_phone custom app "fft_phone_alias" through the lb-phone exports
    Then the kora_phone custom app list should include "fft_phone_alias"
