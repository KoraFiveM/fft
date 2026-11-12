@kora @kora_phone-stevie
Feature: kora_phone-stevie without a handset
  What the phone does for a character who holds no handset item: exports,
  notifications, the open and close path, and the refusal of every data route.
  Routes are called at the NUI-callback level through the phone's own
  callbacks, so the server checks and rate limits apply; nothing clicks the
  rendered phone page. The two "puts itself away" scenarios do depend on the
  real page: it requests the bootstrap, is refused and asks the client to close.

  Not covered: everything that needs a handset (setup, PIN, contacts, notes,
  messages, calls, mail, banking, social, marketplace, camera, SIM and cloud).
  The first bootstrap with a handset inserts phone_devices and phone_handsets
  rows that the resource cannot delete, so those flows are left out rather
  than leave rows behind on every run. Nothing here messages, calls, mails,
  pays or posts to anyone: every such route is asserted refused, with an
  invalid payload as a second guard.

  Each time the phone opens it spends one request from the bootstrap rate
  bucket (4, refilling one every 2 seconds). The rate limit scenario is last.
  Slow buckets (bank transfer, media upload, call start, PIN, community post
  and listing) are spent at most twice per run. Mutation requests share a
  bucket of 12 refilling 2 per second, as does every phone close.

  Also covered: the handset shop counters (standing at one, with requests the
  shop refuses before it charges or hands anything over), the client-only
  routes (waypoint, notifications, alarm, Do Not Disturb, camera and call
  controls, map blips), the custom app and map blip exports, and the local
  notification handlers for legacy bank and shown-ID events.

  Background:
    Given resource "kora_phone-stevie" is running
    And I carry no phone handset

  @server
  Scenario: Without a handset the character has no number
    Then my phone number export should report no number
    And the phone number lookup for "5550000000" should find nobody
    And the phone number lookup for "not a number" should find nobody
    And inventory slot 1 should not hold a resellable phone handset

  Scenario: The phone commands are registered
    Then the phone command "phonereset" should be registered on the server
    And the phone command "phone" should be registered on my client

  @ui @rejection
  Scenario Outline: Reading phone data is refused without a handset
    When I call the phone route "<route>"
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"

    Examples:
      | route                     |
      | contacts:list             |
      | messages:getConversations |
      | mail:list                 |
      | bank:getData              |
      | wallet:get                |

  @ui @rejection
  Scenario: The bootstrap is refused but the handset status answers without a handset
    When I call the phone route "bootstrap"
    Then the phone route should be refused with code "FORBIDDEN" and message "No handset available"
    When I call the phone route "handset:action" with:
      """
      { "op": "status" }
      """
    Then the handset status should describe a character without a handset
    When I call the phone route "handset:action" with:
      """
      { "op": "select", "slot": 9999 }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Handset not found"

  @ui @rejection
  Scenario: Saving and sending are refused without a handset
    When I call the phone route "contacts:create" with:
      """
      { "displayName": "", "phoneNumber": "invalid" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"
    When I call the phone route "items:save" with:
      """
      { "kind": "fft_invalid_kind" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"
    When I call the phone route "settings:save"
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"
    When I call the phone route "messages:send" with:
      """
      { "to": "invalid", "body": "" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"
    When I call the phone route "mail:send" with:
      """
      { "to": "invalid" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"

  @ui @rejection
  Scenario: A bank transfer is refused without a handset
    Given I remember my "bank" balance
    When I call the phone route "bank:transfer" with:
      """
      { "to": "invalid", "amount": -1 }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"
    And my "bank" balance should be unchanged

  @ui @rejection
  Scenario: A disabled app refuses its routes
    When I call the phone route "moderation:getQueue"
    Then the phone route should be refused with code "FORBIDDEN" and message "This app is not part of this release"

  @ui @rejection
  Scenario: An invalid waypoint is refused
    When I call the phone route "waypoint" with:
      """
      { "x": "north", "y": 5 }
      """
    Then the phone route should be refused with code "INVALID_INPUT" and message "That location is invalid"
    When I call the phone route "waypoint" with:
      """
      { "x": 25000, "y": 0 }
      """
    Then the phone route should be refused with code "INVALID_INPUT" and message "That location is invalid"
    When I call the phone route "waypoint" with:
      """
      { "x": 10 }
      """
    Then the phone route should be refused with code "INVALID_INPUT" and message "That location is invalid"

  @ui
  Scenario: Client routes report the phone state, position and weather
    Given my phone is put away
    When I call the phone route "phone:ready"
    Then the phone route should succeed
    And the phone route should report a loaded character and a closed phone
    When I call the phone route "location:mine"
    Then the phone route should succeed
    And the phone route should report my current position
    When I call the phone route "weather:get"
    Then the phone route should succeed
    And the phone route should report the game clock and weather

  Scenario: Notifications reach a closed phone
    Given my phone is put away
    When the phone sends me the notification "FFT server probe" with body "fft phone server notification"
    Then I should see a notification containing "fft phone server notification"
    When I push the local phone notification "FFT client probe" with message "fft phone client notification"
    Then I should see a notification containing "fft phone client notification"

  @rejection
  Scenario: Malformed notifications are refused
    Then the phone should refuse to send me a malformed notification
    And the phone should reject a local notification without a title

  @rejection
  Scenario: The phone command puts the phone away again without a handset
    Given my phone is put away
    When I run the command "phone"
    Then I should see a notification containing "No handset available"
    And my phone should be put away

  @rejection
  Scenario: The open export is accepted but the phone puts itself away
    Given my phone is put away
    When I open the phone through its export
    Then I should see a notification containing "No handset available"
    And my phone should be put away

  @rejection
  Scenario: A blocking interface keeps the phone shut
    Given my phone is put away
    And another interface is blocking the phone
    Then opening the phone through its export should be refused

  @ui @rejection
  Scenario Outline: More phone data is refused without a handset
    When I call the phone route "<route>"
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"

    Examples:
      | route                |
      | blocks:list          |
      | property:list        |
      | garage:list          |
      | gallery:list         |
      | calls:history        |
      | bank:getTransactions |
      | jobs:getData         |
      | messages:getPage     |
      | legacy:mailList      |
      | legacy:activity      |

  @ui @rejection
  Scenario Outline: Social and marketplace reads are refused without a handset
    When I call the phone route "<route>"
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"

    Examples:
      | route              |
      | social:getFeed     |
      | social:getComments |
      | market:getListings |
      | market:getListing  |

  @ui @rejection
  Scenario Outline: Changing phone data is refused without a handset
    When I call the phone route "<route>"
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"

    Examples:
      | route                  |
      | contacts:update        |
      | contacts:delete        |
      | messages:startDirect   |
      | messages:markRead      |
      | messages:deleteForSelf |
      | blocks:set             |
      | mail:read              |
      | mail:delete            |
      | mail:accept            |
      | items:remove           |
      | wallet:show            |
      | gallery:delete         |

  @ui @rejection
  Scenario: Calling, posting, listing and uploads are refused without a handset
    When I call the phone route "calls:start" with:
      """
      { "number": "invalid" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"
    When I call the phone route "calls:hangup" with:
      """
      { "id": "fft-unknown-call" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"
    When I call the phone route "calls:signal" with:
      """
      { "id": "fft-unknown-call" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"
    When I call the phone route "calls:videoControl" with:
      """
      { "id": "fft-unknown-call" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"
    When I call the phone route "social:createPost" with:
      """
      { "body": "" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"
    When I call the phone route "market:createListing" with:
      """
      { "title": "" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"
    When I call the phone route "media:request" with:
      """
      { "mimeType": "fft/invalid", "byteSize": -1 }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"
    When I call the phone route "security:setPin" with:
      """
      { "pin": "x" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"

  @ui @rejection
  Scenario: Going on duty through the phone is refused without a handset
    Given my job is "unemployed" at grade 1
    When I call the phone route "jobs:setDuty" with:
      """
      { "onDuty": false }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"
    And my job should be "unemployed"

  @ui @rejection
  Scenario Outline: Group chats are not part of this release
    When I call the phone route "<route>"
    Then the phone route should be refused with code "INVALID_INPUT" and message "New group chats are not available in this release"

    Examples:
      | route                |
      | messages:createGroup |
      | messages:addMember   |
      | messages:leaveGroup  |

  @ui
  Scenario: Unlocking needs a phone but locking always answers
    When I call the phone route "security:unlock" with:
      """
      { "pin": "0000" }
      """
    Then the phone route should be refused with code "PHONE_REQUIRED" and message "A phone is required"
    When I call the phone route "security:lock"
    Then the phone route should report the phone locked

  @ui @rejection
  Scenario: Unknown share requests and upload tokens are refused
    When I call the phone route "share:answer" with:
      """
      { "id": "fft-unknown-share", "accept": true }
      """
    Then the phone route should be refused with code "NOT_FOUND" and message "That request expired"
    When I call the phone route "media:complete" with:
      """
      { "token": "fft-not-a-token" }
      """
    Then the phone route should be refused with code "UNAUTHORIZED" and message "INVALID_UPLOAD_TOKEN"
    When I call the phone route "media:complete" with:
      """
      { "token": "ffffffffffffffffffffffffffffffffffffffff" }
      """
    Then the phone route should be refused with code "UNAUTHORIZED" and message "INVALID_UPLOAD_TOKEN"

  @ui @rejection
  Scenario: Resolving moderation reports is part of the disabled app
    When I call the phone route "moderation:resolve" with:
      """
      { "id": 1, "action": "dismiss" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "This app is not part of this release"

  @ui @rejection
  Scenario Outline: Handset operations need a held handset
    When I call the phone route "handset:action" with:
      """
      { "op": "<op>" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Select a valid handset in your inventory"

    Examples:
      | op            |
      | wifi          |
      | faceUnlock    |
      | insertSim     |
      | registerCloud |
      | backup        |
      | reset         |
      | fft_unknown   |

  @ui @rejection
  Scenario: Shop services and consent are refused away from a counter
    When I call the phone route "handset:action" with:
      """
      { "op": "buy", "shop": "fft_no_such_shop", "item": "phone_standard" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Visit an authorised shop counter"
    When I call the phone route "handset:action" with:
      """
      { "op": "resell", "shop": "fft_no_such_shop", "slot": 1 }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Visit an authorised shop counter"
    When I call the phone route "handset:action" with:
      """
      { "op": "consent", "id": "fft-unknown-request", "accept": true }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Service request expired"

  @ui @world @rejection
  Scenario: The Legion counter lists itself and refuses requests it cannot serve
    Given I remember my "bank" balance
    And I stand at 127.4 -1029.2 29.4 facing 0.0
    And the server should see me within reach of the "legion" phone shop
    When I call the phone route "handset:action" with:
      """
      { "op": "status" }
      """
    Then the handset status should list the "legion" phone shop
    When I call the phone route "handset:action" with:
      """
      { "op": "buy", "shop": "legion", "item": "fft_not_sold_here" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Item is unavailable"
    When I call the phone route "handset:action" with:
      """
      { "op": "resell", "shop": "legion", "slot": 9999 }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Factory reset and remove the SIM before resale"
    When I call the phone route "handset:action" with:
      """
      { "op": "replaceSim", "shop": "legion", "number": "123" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Enter your existing phone number"
    When I call the phone route "handset:action" with:
      """
      { "op": "recoverCloud", "shop": "legion", "accountId": "fft-not-an-account" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Account does not belong to this character"
    And my "bank" balance should be unchanged

  @ui @world @rejection
  Scenario: The technician workshop serves mechanics only
    Given my job is "unemployed" at grade 1
    And I stand at -40.1 -1090.7 26.4 facing 0.0
    And the server should see me within reach of the "technician" phone shop
    When I call the phone route "handset:action" with:
      """
      { "op": "status" }
      """
    Then the handset status should list the "technician" phone shop
    When I call the phone route "handset:action" with:
      """
      { "op": "buy", "shop": "technician", "item": "fft_not_sold_here" }
      """
    Then the phone route should be refused with code "FORBIDDEN" and message "Visit an authorised shop counter"

  @ui
  Scenario: Client routes for navigation and calls answer locally
    Given the phone call speaker is switched off afterwards
    When I call the phone route "route:changed" with:
      """
      { "route": "/fft-probe" }
      """
    Then the phone route should succeed
    When I call the phone route "calls:setMuted" with:
      """
      { "muted": true }
      """
    Then the phone route should answer without success
    When I call the phone route "calls:setSpeaker" with:
      """
      { "speaker": true }
      """
    Then the phone route should succeed
    When I call the phone route "calls:setSpeaker" with:
      """
      { "speaker": false }
      """
    Then the phone route should succeed
    When I call the phone route "map:blips"
    Then the phone route should succeed

  @ui @rejection
  Scenario: Camera controls do nothing while the camera is closed
    Given my phone is put away
    When I call the phone route "camera:close"
    Then the phone route should succeed
    When I call the phone route "camera:zoom" with:
      """
      { "dir": 1 }
      """
    Then the phone route should answer without success
    When I call the phone route "camera:facing" with:
      """
      { "front": true }
      """
    Then the phone route should answer without success
    When I call the phone route "camera:recording" with:
      """
      { "active": true }
      """
    Then the phone route should answer without success

  @ui @rejection
  Scenario: A blocking interface keeps the phone camera shut
    Given my phone is put away
    And another interface is blocking the phone
    When I try to open the phone camera
    Then the phone route should be refused with the bare error "UI_BLOCKED"

  @ui
  Scenario: A waypoint set through the phone is reported back
    Given my map waypoint is restored afterwards
    When I call the phone route "waypoint" with:
      """
      { "x": 1500, "y": 3600 }
      """
    Then the phone route should succeed
    And my map waypoint should be at 1500 3600
    When I call the phone route "location:mine"
    Then the phone route should report a waypoint at 1500 3600
    When I call the phone route "waypoint" with:
      """
      { "x": "1200", "y": "3400" }
      """
    Then the phone route should succeed
    And my map waypoint should be at 1200 3400

  @ui
  Scenario: The phone page notifies a closed phone only when it gives a title
    Given my phone is put away
    When I call the phone route "notify" with:
      """
      { "title": "FFT notify probe", "body": "fft phone page notify body" }
      """
    Then the phone route should succeed
    And I should see a notification containing "fft phone page notify body"
    When I call the phone route "notify" with:
      """
      { "body": "fft untitled notify body" }
      """
    Then the phone route should succeed
    And I should not see a notification containing "fft untitled notify body"

  @ui
  Scenario: Do Not Disturb silences ordinary alerts but not urgent ones
    Given my phone is put away
    And my phone is set to Do Not Disturb
    When I call the phone route "notify" with:
      """
      { "title": "FFT quiet probe", "body": "fft quiet ordinary body" }
      """
    Then the phone route should succeed
    When I push the local phone notification "FFT quiet probe" with message "fft quiet ordinary push"
    And I call the phone route "notify" with:
      """
      { "title": "FFT quiet probe", "body": "fft quiet urgent body", "urgent": true }
      """
    Then the phone route should succeed
    And I should see a notification containing "fft quiet urgent body"
    When I push the urgent local phone notification "FFT quiet probe" with message "fft quiet urgent push"
    Then I should see a notification containing "fft quiet urgent push"
    And I should not see a notification containing "fft quiet ordinary body"
    And I should not see a notification containing "fft quiet ordinary push"

  @ui
  Scenario: Alarms ring on a closed phone
    Given my phone is put away
    When I call the phone route "alarm" with:
      """
      { "label": "fft wake up probe" }
      """
    Then the phone route should succeed
    And I should see a notification containing "fft wake up probe"
    When I call the phone route "alarm" with:
      """
      { "label": "" }
      """
    Then the phone route should succeed
    And I should see a notification containing "Untitled"

  @ui
  Scenario: The phone page explains why it closed
    Given my phone is put away
    When I call the phone route "phone:close" with:
      """
      { "error": "fft phone page could not start" }
      """
    Then the phone route should succeed
    And I should see a notification containing "fft phone page could not start"
    When the phone page closes with a 140 character error ending in "fftclosetail"
    Then the phone route should succeed
    And I should see a notification containing "fft close probe"
    And I should not see a notification containing "fftclosetail"
    And my phone should be put away

  @rejection
  Scenario: Local notifications respect their length limits
    Then the phone should accept a local notification with a 80 character title
    And the phone should reject a local notification with a 81 character title
    And the phone should reject a local notification with a 501 character message
    And the phone should reject a local notification whose message is a number

  Scenario: A silent local notification raises no alert
    Given my phone is put away
    When I push the silent local phone notification "FFT silent probe" with message "fft silent phone notification"
    Then I should not see a notification containing "fft silent phone notification"

  Scenario: Server notifications only go to a numeric player and are shortened
    Given my phone is put away
    Then the phone should refuse a notification addressed to "1"
    When the phone sends me the notification "FFT long body probe" with a 260 character body ending in "fftbodytail"
    Then I should see a notification containing "FFT long body probe"
    And I should not see a notification containing "fftbodytail"

  # client/notifications.lua registers /testphonenotify (renamed from
  # /testnotify, which kora_lib-playground also registers).
  Scenario Outline: The sample notification command shows each app's sample
    Given my phone is put away
    When I run the command "testphonenotify <app>"
    Then I should see a notification containing "<text>"

    Examples:
      | app     | text                                |
      | system  | Phone connected.                    |
      | banking | You received $2,500 from Maya.      |
      | mail    | Your vehicle registration is ready. |
      | gps     | Waypoint set to Pillbox Medical.    |
      | weather | Clear skies over Los Santos.        |

  Scenario: A legacy bank notice only notifies and moves no money
    Given my phone is put away
    And I remember my "bank" balance
    When the legacy phone bank event reports 0 removed
    Then I should not see a notification containing "has been removed from your balance"
    When the legacy phone bank event reports 75 removed
    Then I should see a notification containing "$75 has been removed from your balance!"
    And my "bank" balance should be unchanged

  Scenario: An ID shown nearby gets through Do Not Disturb
    Given my phone is put away
    And my phone is set to Do Not Disturb
    When the phone hears an ID card from "FFT Broken Card" without licences
    Then I should not see a notification containing "FFT Broken Card"
    When the phone hears that "FFT Probe Person" showed me their ID
    Then I should see a notification containing "FFT Probe Person showed you their ID"

  Scenario: A custom app is listed, messaged and removed
    Given I register the custom phone app "fft_phone_probe" with ui "@fft/fft_probe/index.html"
    Then the custom phone app list should include "fft_phone_probe" with ui "fft_probe/index.html"
    When I send the custom phone app "fft_phone_probe" a message
    And I remove the custom phone app "fft_phone_probe"
    Then the custom phone app list should not include "fft_phone_probe"
    And a message to the unknown custom phone app "fft_phone_probe" should be refused

  @rejection
  Scenario: Invalid custom apps are refused
    Then the phone should refuse a custom app without an identifier
    And the phone should refuse the custom app "fft_phone_no_ui" without a ui
    And the custom phone app list should not include "fft_phone_no_ui"
    And removing the unknown custom phone app "fft_phone_never_added" should be refused

  Scenario: A job-only custom app stays hidden from other jobs
    Given my job is "unemployed" at grade 1
    And I register the custom phone app "fft_phone_job_probe" for the job "fft_no_such_job"
    Then the custom phone app list should not include "fft_phone_job_probe"

  Scenario: A custom app hears that it was opened
    Given I register the custom phone app "fft_phone_lifecycle" that records being opened
    When I call the phone route "customLifecycle" with:
      """
      { "app": "fft_phone_lifecycle", "event": "onOpen" }
      """
    Then the phone route should succeed
    And the custom phone app "fft_phone_lifecycle" should have recorded being opened

  Scenario: Apps written for lb-phone register through its exports
    Given I register the custom phone app "fft_phone_alias" through the lb-phone exports
    Then the custom phone app list should include "fft_phone_alias" with ui "fft_probe/index.html"
    When I remove the custom phone app "fft_phone_alias" through the lb-phone exports
    Then the custom phone app list should not include "fft_phone_alias"

  @ui
  Scenario: A registered blip shows on the phone map until removed
    Given I add a probe blip at 1500 3600 to the phone map titled "FFT phone map probe"
    Then the phone map should list the probe blip titled "FFT phone map probe"
    When I remove the probe blip from the phone map
    Then the phone map should not list the probe blip

  @rejection
  Scenario: Invalid map blips are refused
    Given I add a probe blip at 1500 3600 to the phone map titled "FFT phone map probe"
    Then the phone map should refuse the probe blip with a blank title
    And the phone map should refuse the probe blip with a 161 character title
    And the phone map should refuse a blip that does not exist
    And removing an unknown blip from the phone map should be refused

  @rejection
  Scenario: Resetting a phone without one changes nothing
    Given my phone is put away
    When I run the command "phonereset"
    Then the phone reset should answer "No permission" or "No phone found for player"

  @ui @rejection
  Scenario: Bootstrap requests are rate limited
    Then repeated phone bootstrap requests should end in a rate limit
