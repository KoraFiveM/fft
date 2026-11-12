@kora @kora_dispatch
Feature: kora_dispatch calls, unit responses and tablet
  Job resources raise calls through server exports; on-duty units of the
  targeted service see them on a feed, respond en route, on scene and clear,
  and can open a tablet. Calls are raised here through the real createCall
  export, which only accepts trusted resources: scenarios tagged @seam need the
  approved seam (fft trusted while fft_kora_hooks is true). Every call targets
  the "tow" job (service "recovery"), is routine priority, expires after one
  minute and is closed in cleanup; it is still pushed to any other on-duty tow
  unit, hence @global. The tablet is a kora_lib app driven at the NUI-callback
  level, not through rendered controls.

  Player alerts use only two fixed keys ("fft:recovery-alert" and
  "fft:recovery-units-only"), registered by fft with a one-second cooldown;
  re-registering a key replaces it and kora_dispatch drops fft's keys when fft
  stops, so the registry stays bounded.

  Not covered: /dispatchtest, /dispatchclear and /dispatchstatus (admin only),
  the refusal of an untrusted caller and of a player alert owned by another
  resource (fft is trusted once the seam is active), police and EMS calls
  (they would alert real responders), "this call was not sent to your
  department" (no service has two seeded jobs), the hydrate, getCalls and
  setViewing callbacks called directly, the unit heartbeat map and the
  rendered feed, map and blips.

  Background:
    Given resource "kora_dispatch" is running

  @server @seam @global
  Scenario: A raised call reaches the on-duty units of its job
    Given I am on duty as "tow" at grade 1
    Then the dispatch roster for the service "recovery" should include me
    When a dispatch call titled "FFT recovery call" is raised for the job "tow"
    Then the dispatch call "FFT recovery call" should have reached at least 1 unit
    And the dispatch call "FFT recovery call" should be live for the service "recovery"
    And the dispatch call "FFT recovery call" should have priority 3

  @server @seam @global
  Scenario: A call can be revised and closed
    Given a dispatch call titled "FFT revised call" is raised for the job "tow"
    When the dispatch call "FFT revised call" is revised to priority 2
    Then the dispatch call "FFT revised call" should have priority 2
    And revising the dispatch call "FFT revised call" to priority 9 should be refused with "unknown priority"
    And the dispatch call "FFT revised call" should have priority 2
    When the dispatch call "FFT revised call" is closed with the reason "resolved by fft"
    Then the dispatch call "FFT revised call" should be closed with the reason "resolved by fft"

  @server @seam @rejection
  Scenario: Malformed call payloads are refused
    Then raising a dispatch call should be refused with "at least one job or job type":
      """
      { "title": "FFT refused call" }
      """
    And raising a dispatch call should be refused with "needs a title or a message":
      """
      { "jobs": ["tow"] }
      """
    And raising a dispatch call should be refused with "unknown job":
      """
      { "jobs": ["fft_no_such_job"], "title": "FFT refused call" }
      """
    And raising a dispatch call should be refused with "exactly one service":
      """
      { "jobs": ["tow", "ambulance"], "title": "FFT refused call" }
      """

  @server @seam @global
  Scenario: A unit walks a call from en route to clear
    Given I am on duty as "tow" at grade 1
    And a dispatch call titled "FFT response call" is raised for the job "tow"
    When I respond to the dispatch call "FFT response call" as "en_route"
    Then my response to the dispatch call "FFT response call" should be "en_route"
    When I advance my response to the dispatch call "FFT response call"
    Then my response to the dispatch call "FFT response call" should be "on_scene"
    When I advance my response to the dispatch call "FFT response call"
    Then my response to the dispatch call "FFT response call" should be "clear"

  # Config.dispatch.maxActiveCalls = 1 (kora_dispatch/config.lua).
  @server @seam @global @rejection
  Scenario: A unit cannot accept a second call while committed to one
    Given I am on duty as "tow" at grade 1
    And a dispatch call titled "FFT first call" is raised for the job "tow"
    And a dispatch call titled "FFT second call" is raised for the job "tow"
    When I respond to the dispatch call "FFT first call" as "en_route"
    Then responding to the dispatch call "FFT second call" should be refused with "you are already en route to a call"
    And I should not be attached to the dispatch call "FFT second call"
    When I drop my response to the dispatch call "FFT first call"
    Then I should not be attached to the dispatch call "FFT first call"
    When I respond to the dispatch call "FFT second call" as "en_route"
    Then my response to the dispatch call "FFT second call" should be "en_route"

  @server @seam @global @rejection
  Scenario: An off-duty unit cannot respond
    Given I am off duty as "tow" at grade 1
    And a dispatch call titled "FFT off duty call" is raised for the job "tow"
    Then responding to the dispatch call "FFT off duty call" should be refused with "not on duty"
    And I should not be attached to the dispatch call "FFT off duty call"

  @server @seam @global @rejection
  Scenario Outline: A unit outside the call's service cannot respond
    Given I am on duty as "<job>" at grade 1
    And a dispatch call titled "FFT other service call" is raised for the job "tow"
    Then responding to the dispatch call "FFT other service call" should be refused with "<reason>"
    And I should not be attached to the dispatch call "FFT other service call"

    Examples:
      | job       | reason                                |
      | mechanic  | dispatch is not available to your job |
      | ambulance | wrong service for this call           |

  @server @seam @global @rejection
  Scenario: Closed and unknown calls cannot be accepted
    Given I am on duty as "tow" at grade 1
    And a dispatch call titled "FFT closed call" is raised for the job "tow"
    When the dispatch call "FFT closed call" is closed with the reason "resolved by fft"
    Then responding to the dispatch call "FFT closed call" should be refused with "call is no longer active"
    And responding to an unknown dispatch call should be refused with "no such call"

  @server @seam @global
  Scenario: Going off duty detaches the unit from its call
    Given I am on duty as "tow" at grade 1
    And a dispatch call titled "FFT shift end call" is raised for the job "tow"
    And I respond to the dispatch call "FFT shift end call" as "en_route"
    When I end my dispatch shift
    Then I should not be attached to the dispatch call "FFT shift end call"
    And the dispatch roster for the service "recovery" should not include me

  @ui
  Scenario: The tablet key opens the tablet for an on-duty unit
    Given I am on duty as "tow" at grade 1
    And my dispatch service should be "recovery"
    When I press the dispatch tablet key
    Then the app "kora_dispatch:tablet" should be open
    # No call is selected, so no response is offered.
    And the app action "dispatch:respond:en_route" should be unavailable
    When I close the app
    Then no app should be open

  @ui @rejection
  Scenario: The tablet stays closed for an off-duty unit
    Given I am off duty as "tow" at grade 1
    And I should have no dispatch service
    When I press the dispatch tablet key
    Then I should see a notification containing "You are off duty"
    And no app should be open

  @ui @seam @global
  Scenario: A new call is announced, shown on the feed and accepted on the tablet
    Given I am on duty as "tow" at grade 1
    And my dispatch service should be "recovery"
    When a dispatch call titled "FFT tablet call" is raised for the job "tow"
    Then I should see a notification containing "FFT tablet call"
    And the dispatch feed should show the call "FFT tablet call"
    When I press the dispatch tablet key
    Then the app "kora_dispatch:tablet" should be open
    When I select the dispatch call "FFT tablet call" on the tablet
    And I respond "en_route" to the selected dispatch call on the tablet
    Then my response to the dispatch call "FFT tablet call" should be "en_route"
    When I respond "on_scene" to the selected dispatch call on the tablet
    Then my response to the dispatch call "FFT tablet call" should be "on_scene"

  @ui @seam @global
  Scenario: A closed call is pushed to the feed as closed
    Given I am on duty as "tow" at grade 1
    And my dispatch service should be "recovery"
    And a dispatch call titled "FFT feed call" is raised for the job "tow"
    And the dispatch feed should show the call "FFT feed call"
    When the dispatch call "FFT feed call" is closed with the reason "resolved by fft"
    Then the dispatch feed should show the call "FFT feed call" as closed

  # --- Payload normalisation (kora_dispatch/shared/calls.lua normalise) -----

  @server @seam @global
  Scenario: Field aliases from older dispatch scripts are understood
    Given a dispatch call known as "FFT alias call" is raised with:
      """
      { "job": "tow", "description": "FFT alias call", "dispatchCode": "10-50", "priority": 3 }
      """
    Then the dispatch call "FFT alias call" should belong to the service "recovery"
    And the dispatch call "FFT alias call" should have the field "title" set to "FFT alias call"
    And the dispatch call "FFT alias call" should have the field "message" set to "FFT alias call"
    And the dispatch call "FFT alias call" should have the field "code" set to "10-50"
    And the dispatch call "FFT alias call" should have the field "origin" set to "fft"
    And the dispatch calls for the job "tow" should include "FFT alias call"

  @server @seam @global
  Scenario: A call can target a whole service by job type
    Given a dispatch call known as "FFT job type call" is raised with:
      """
      { "jobTypes": ["recovery"], "title": "FFT job type call", "priority": 3 }
      """
    And a dispatch call known as "FFT job type alias call" is raised with:
      """
      { "jobType": "recovery", "title": "FFT job type alias call", "priority": 3 }
      """
    Then the dispatch call "FFT job type call" should belong to the service "recovery"
    And the dispatch calls for the job "tow" should include "FFT job type call"
    And the dispatch call "FFT job type alias call" should belong to the service "recovery"
    And the dispatch calls for the job "tow" should include "FFT job type alias call"

  # Config.priorities has 1-3; Config.defaultPriority = 2.
  @server @seam @global
  Scenario Outline: An unknown or malformed priority falls back to the default
    Given a dispatch call known as "FFT priority call" is raised for the job "tow" with the priority "<raw>" given as "<kind>"
    Then the dispatch call "FFT priority call" should have priority <expected>

    Examples:
      | raw | kind   | expected |
      | fft | text   | 2        |
      | 0   | number | 2        |
      | -1  | number | 2        |
      | 9   | number | 2        |
      | 3.7 | number | 3        |
      | 3   | text   | 3        |

  # Config.priorities[3].ttl = 120000.
  @server @seam @global
  Scenario: Without a duration a call lives as long as its priority allows
    Given a dispatch call known as "FFT ttl call" is raised without a duration with:
      """
      { "jobs": ["tow"], "title": "FFT ttl call", "priority": 3 }
      """
    And a dispatch call titled "FFT duration call" is raised for the job "tow"
    Then the dispatch call "FFT ttl call" should last 120000 milliseconds
    And the dispatch call "FFT duration call" should last 60000 milliseconds

  @server @seam @global
  Scenario: The wire form carries coordinates, icon and data but no server-only fields
    Given a dispatch call known as "FFT wire call" is raised with:
      """
      {
        "jobs": ["tow"], "title": "FFT wire call", "priority": 3,
        "coords": { "x": 100.5, "y": -200.25 }, "icon": "truck",
        "data": { "street": "FFT Street" }, "onAccept": "fft:dispatch:never-listened"
      }
      """
    Then the dispatch call "FFT wire call" should be located at 100.5 -200.25 0.0
    And the dispatch call "FFT wire call" should have the field "icon" set to "truck"
    And the dispatch call "FFT wire call" should carry the data "street" set to "FFT Street"
    And the dispatch call "FFT wire call" should have no field "onAccept"
    And the dispatch call "FFT wire call" should have no field "jobs"
    And the dispatch call "FFT wire call" should have no field "closeReason"

  @server @seam @global
  Scenario: Malformed presentation fields are dropped instead of stored
    Given a dispatch call known as "FFT dropped fields call" is raised with:
      """
      {
        "jobs": ["tow"], "title": "FFT dropped fields call", "priority": 3,
        "coords": { "x": "north", "y": 1 }, "icon": 42, "data": "not a table"
      }
      """
    Then the dispatch call "FFT dropped fields call" should have no field "coords"
    And the dispatch call "FFT dropped fields call" should have no field "icon"
    And the dispatch call "FFT dropped fields call" should have no field "data"

  @server @seam @rejection
  Scenario: More malformed call payloads are refused
    Then raising a dispatch call should be refused with "jobs must be a string or an array of strings":
      """
      { "jobs": 5, "title": "FFT refused call" }
      """
    And raising a dispatch call should be refused with "jobs must be a string or an array of strings":
      """
      { "jobs": [""], "title": "FFT refused call" }
      """
    And raising a dispatch call should be refused with "jobTypes must be a string or an array of strings":
      """
      { "jobTypes": 7, "title": "FFT refused call" }
      """
    And raising a dispatch call should be refused with "title must be a string":
      """
      { "jobs": ["tow"], "title": 5 }
      """
    And raising a dispatch call should be refused with "message must be a string":
      """
      { "jobs": ["tow"], "message": true }
      """
    And raising a dispatch call should be refused with "code must be a string":
      """
      { "jobs": ["tow"], "title": "FFT refused call", "code": 10 }
      """
    And raising a dispatch call should be refused with "no registered job carries the type 'fft_no_such_type'":
      """
      { "jobTypes": ["fft_no_such_type"], "title": "FFT refused call" }
      """
    And raising a dispatch call should be refused with "a call targets exactly one service":
      """
      { "jobs": ["tow"], "jobTypes": ["ems"], "title": "FFT refused call" }
      """
    And raising a dispatch call with a duration of 0 should be refused with "duration must be positive"
    And raising a dispatch call with a duration of -5 should be refused with "duration must be positive"
    And raising a dispatch call from a non-table payload should be refused with "payload must be a table"

  # --- Revising, expiring and closing (kora_dispatch/server/store.lua) -----

  @server @seam @global
  Scenario: A patch revises presentation fields but never a call's identity
    Given a dispatch call titled "FFT patched call" is raised for the job "tow"
    When the dispatch call "FFT patched call" is patched with:
      """
      {
        "title": "FFT patched title", "message": "FFT patched message", "code": "10-99",
        "icon": "wrench", "coords": { "x": 1.5, "y": 2.5, "z": 3.5 }, "data": { "street": "FFT Avenue" },
        "service": "ems", "origin": "fft-forged", "createdAt": 1, "id": 999999
      }
      """
    Then the dispatch call "FFT patched call" should have the field "title" set to "FFT patched title"
    And the dispatch call "FFT patched call" should have the field "message" set to "FFT patched message"
    And the dispatch call "FFT patched call" should have the field "code" set to "10-99"
    And the dispatch call "FFT patched call" should have the field "icon" set to "wrench"
    And the dispatch call "FFT patched call" should be located at 1.5 2.5 3.5
    And the dispatch call "FFT patched call" should carry the data "street" set to "FFT Avenue"
    And the dispatch call "FFT patched call" should belong to the service "recovery"
    And the dispatch call "FFT patched call" should have the field "origin" set to "fft"
    And the dispatch call "FFT patched call" should last 60000 milliseconds
    And the dispatch call "FFT patched call" should be listed as active

  # A priority change re-bases expiresAt on createdAt + the new ttl unless a
  # duration comes with it.
  @server @seam @global
  Scenario: Changing a call's priority re-bases its lifetime
    Given a dispatch call known as "FFT rebased call" is raised with:
      """
      { "jobs": ["tow"], "title": "FFT rebased call", "priority": 2 }
      """
    And the dispatch call "FFT rebased call" should last 60000 milliseconds
    When the dispatch call "FFT rebased call" is patched with:
      """
      { "priority": 3 }
      """
    Then the dispatch call "FFT rebased call" should have priority 3
    And the dispatch call "FFT rebased call" should last 120000 milliseconds
    When the dispatch call "FFT rebased call" is patched with:
      """
      { "priority": 2, "duration": 45000 }
      """
    Then the dispatch call "FFT rebased call" should have priority 2
    And the dispatch call "FFT rebased call" should last 45000 milliseconds
    When the dispatch call "FFT rebased call" is patched with:
      """
      { "duration": 30000 }
      """
    Then the dispatch call "FFT rebased call" should have priority 2
    And the dispatch call "FFT rebased call" should last 30000 milliseconds

  @server @seam @global @rejection
  Scenario: Invalid patches are refused and change nothing
    Given a dispatch call titled "FFT guarded call" is raised for the job "tow"
    Then patching the dispatch call "FFT guarded call" should be refused with "unknown priority":
      """
      { "title": "FFT should not apply", "priority": 0 }
      """
    And patching the dispatch call "FFT guarded call" should be refused with "duration must be a positive number":
      """
      { "title": "FFT should not apply", "duration": 0 }
      """
    And patching the dispatch call "FFT guarded call" should be refused with "duration must be a positive number":
      """
      { "title": "FFT should not apply", "duration": "soon" }
      """
    And patching the dispatch call "FFT guarded call" with a non-table patch should be refused with "patch must be a table"
    And patching an unknown dispatch call should be refused with "no such call"
    And the dispatch call "FFT guarded call" should have the field "title" set to "FFT guarded call"
    And the dispatch call "FFT guarded call" should have priority 3
    And the dispatch call "FFT guarded call" should last 60000 milliseconds
    When the dispatch call "FFT guarded call" is closed with the reason "resolved by fft"
    Then patching the dispatch call "FFT guarded call" should be refused with "call is closed":
      """
      { "title": "FFT should not apply" }
      """

  @server @seam @global @rejection
  Scenario: An expired call stays readable but can no longer be accepted
    Given I am on duty as "tow" at grade 1
    And a dispatch call titled "FFT expiring call" is raised for the job "tow"
    When the dispatch call "FFT expiring call" is made to expire
    Then the dispatch call "FFT expiring call" should have expired without being closed
    And responding to the dispatch call "FFT expiring call" should be refused with "call is no longer active"
    And I should not be attached to the dispatch call "FFT expiring call"
    When the dispatch call "FFT expiring call" is revived
    Then the dispatch call "FFT expiring call" should be listed as active
    When I respond to the dispatch call "FFT expiring call" as "en_route"
    Then my response to the dispatch call "FFT expiring call" should be "en_route"

  @server @seam @global
  Scenario: A unit whose call expires is free to take another and can still detach
    Given I am on duty as "tow" at grade 1
    And a dispatch call titled "FFT expired commitment" is raised for the job "tow"
    And a dispatch call titled "FFT next commitment" is raised for the job "tow"
    And I respond to the dispatch call "FFT expired commitment" as "en_route"
    When the dispatch call "FFT expired commitment" is made to expire
    And I respond to the dispatch call "FFT next commitment" as "en_route"
    Then my response to the dispatch call "FFT next commitment" should be "en_route"
    When I drop my response to the dispatch call "FFT expired commitment"
    Then I should not be attached to the dispatch call "FFT expired commitment"

  @server @seam @global
  Scenario: Closing is final and keeps the first reason
    Given a dispatch call titled "FFT twice closed call" is raised for the job "tow"
    When the dispatch call "FFT twice closed call" is closed with the reason "resolved by fft"
    Then closing the dispatch call "FFT twice closed call" again with the reason "fft second reason" should change nothing
    And the dispatch call "FFT twice closed call" should be closed with the reason "resolved by fft"
    And closing an unknown dispatch call should be refused with "no such call"

  @server @seam @global
  Scenario: A close without a text reason records no reason
    Given I am on duty as "tow" at grade 1
    And a dispatch call titled "FFT reasonless call" is raised for the job "tow"
    When the dispatch call "FFT reasonless call" is closed with a non-text reason
    Then the dispatch call "FFT reasonless call" should have no field "closeReason"
    And responding to the dispatch call "FFT reasonless call" should be refused with "call is no longer active"

  @server @seam @global
  Scenario: A unit can still detach from a call that was closed under it
    Given I am on duty as "tow" at grade 1
    And a dispatch call titled "FFT closed under me" is raised for the job "tow"
    And I respond to the dispatch call "FFT closed under me" as "en_route"
    When the dispatch call "FFT closed under me" is closed with the reason "resolved by fft"
    Then my response to the dispatch call "FFT closed under me" should be "en_route"
    When I drop my response to the dispatch call "FFT closed under me"
    Then I should not be attached to the dispatch call "FFT closed under me"

  # --- Listing and roster ---------------------------------------------------

  @server @seam @global
  Scenario: Calls are listed newest first and filtered by job
    Given a dispatch call titled "FFT older listed call" is raised for the job "tow"
    And a dispatch call titled "FFT newer listed call" is raised for the job "tow"
    Then the dispatch call "FFT newer listed call" should be listed before "FFT older listed call"
    And the dispatch calls for the job "tow" should include "FFT older listed call"
    And the dispatch calls for the job "tow" should include "FFT newer listed call"
    And the dispatch calls for the job "mechanic" should not include "FFT newer listed call"

  @server
  Scenario: The roster by job follows the unit's job and duty
    Given I am on duty as "tow" at grade 1
    Then the dispatch roster for the job "tow" should include me
    And the dispatch roster for the job "mechanic" should not include me
    When I end my dispatch shift
    Then the dispatch roster for the job "tow" should not include me
    And the dispatch roster for the service "recovery" should not include me

  @server
  Scenario: A mechanic is on duty but not on the recovery roster
    Given I am on duty as "mechanic" at grade 1
    Then the dispatch roster for the job "mechanic" should include me
    And the dispatch roster for the service "recovery" should not include me

  # --- The unit state machine (kora_dispatch/server/api.lua setUnitState) ---

  @server @seam @global
  Scenario: A unit may accept directly on scene and step back to en route
    Given I am on duty as "tow" at grade 1
    And a dispatch call titled "FFT direct call" is raised for the job "tow"
    When I respond to the dispatch call "FFT direct call" as "on_scene"
    Then my response to the dispatch call "FFT direct call" should be "on_scene"
    When I respond to the dispatch call "FFT direct call" as "en_route"
    Then my response to the dispatch call "FFT direct call" should be "en_route"
    And responding "fft_bogus" to the dispatch call "FFT direct call" should be refused with "invalid unit state"
    And my response to the dispatch call "FFT direct call" should be "en_route"

  @server @seam @global
  Scenario: Advancing past clear detaches the unit, and clear frees it for the next call
    Given I am on duty as "tow" at grade 1
    And a dispatch call titled "FFT cleared call" is raised for the job "tow"
    And a dispatch call titled "FFT following call" is raised for the job "tow"
    And I respond to the dispatch call "FFT cleared call" as "en_route"
    When I advance my response to the dispatch call "FFT cleared call"
    And I advance my response to the dispatch call "FFT cleared call"
    Then my response to the dispatch call "FFT cleared call" should be "clear"
    When I respond to the dispatch call "FFT following call" as "en_route"
    Then my response to the dispatch call "FFT following call" should be "en_route"
    And advancing my response to the dispatch call "FFT cleared call" should detach me
    And I should not be attached to the dispatch call "FFT cleared call"

  @server @seam @global
  Scenario: Closing a call releases the unit's commitment
    Given I am on duty as "tow" at grade 1
    And a dispatch call titled "FFT released call" is raised for the job "tow"
    And a dispatch call titled "FFT after release call" is raised for the job "tow"
    And I respond to the dispatch call "FFT released call" as "en_route"
    When the dispatch call "FFT released call" is closed with the reason "resolved by fft"
    And I respond to the dispatch call "FFT after release call" as "en_route"
    Then my response to the dispatch call "FFT after release call" should be "en_route"

  @server @seam @global @rejection
  Scenario: The commitment cap also applies to a unit accepting directly on scene
    Given I am on duty as "tow" at grade 1
    And a dispatch call titled "FFT capped first call" is raised for the job "tow"
    And a dispatch call titled "FFT capped second call" is raised for the job "tow"
    And I respond to the dispatch call "FFT capped first call" as "en_route"
    Then responding "on_scene" to the dispatch call "FFT capped second call" should be refused with "you are already en route to a call"
    And I should not be attached to the dispatch call "FFT capped second call"
    But my response to the dispatch call "FFT capped first call" should be "en_route"

  @server @seam @global @rejection
  Scenario: A call can be named by its id as text, and a non-numeric id names no call
    Given I am on duty as "tow" at grade 1
    And a dispatch call titled "FFT text id call" is raised for the job "tow"
    When I respond to the dispatch call "FFT text id call" as "en_route" by its text id
    Then my response to the dispatch call "FFT text id call" should be "en_route"
    And responding to a dispatch call with the id "fft" should be refused with "no such call"

  # --- onAccept (docs/index.md "The onAccept hook") --------------------------

  @server @seam @global
  Scenario: The onAccept event fires once when a unit accepts, not on later progress
    Given I am on duty as "tow" at grade 1
    And I listen for the dispatch acceptance event "fft:dispatch:accepted"
    And a dispatch call titled "FFT accept hook call" is raised for the job "tow" announcing acceptance on "fft:dispatch:accepted"
    When I respond to the dispatch call "FFT accept hook call" as "en_route"
    Then the acceptance event "fft:dispatch:accepted" should have fired once for the dispatch call "FFT accept hook call"
    When I advance my response to the dispatch call "FFT accept hook call"
    And I advance my response to the dispatch call "FFT accept hook call"
    Then my response to the dispatch call "FFT accept hook call" should be "clear"
    And the acceptance event "fft:dispatch:accepted" should have fired once for the dispatch call "FFT accept hook call"

  # Documented: "fires when a unit first attaches". server/api.lua only fires it
  # when the first state is en_route (suspected bug, see the round 3 report).
  @server @seam @global
  Scenario: The onAccept event fires when a unit first attaches directly on scene
    Given I am on duty as "tow" at grade 1
    And I listen for the dispatch acceptance event "fft:dispatch:accepted-on-scene"
    And a dispatch call titled "FFT on scene hook call" is raised for the job "tow" announcing acceptance on "fft:dispatch:accepted-on-scene"
    When I respond to the dispatch call "FFT on scene hook call" as "on_scene"
    Then the acceptance event "fft:dispatch:accepted-on-scene" should have fired once for the dispatch call "FFT on scene hook call"

  # A unit that changes job is no longer a responder for the old service. Only
  # going off duty and dropping detach today (suspected bug, see the report).
  @server @seam @global
  Scenario: Changing job detaches the unit from its call
    Given I am on duty as "tow" at grade 1
    And a dispatch call titled "FFT job change call" is raised for the job "tow"
    And I respond to the dispatch call "FFT job change call" as "en_route"
    When I am on duty as "mechanic" at grade 1
    Then the dispatch roster for the service "recovery" should not include me
    And I should not be attached to the dispatch call "FFT job change call"

  # --- Player alerts (kora_dispatch/server/ingress.lua) ---------------------

  @server @seam @global
  Scenario: A player alert raises a call at the reporter's position
    Given the player alert "fft:recovery-alert" is registered for the job "tow"
    When I raise the player alert "fft:recovery-alert"
    Then the dispatch call "fft:recovery-alert" should belong to the service "recovery"
    And the dispatch call "fft:recovery-alert" should have the field "title" set to "FFT player alert fft:recovery-alert"
    And the dispatch call "fft:recovery-alert" should have priority 3
    And the dispatch call "fft:recovery-alert" should last 60000 milliseconds
    And the dispatch call "fft:recovery-alert" should be located at my position
    And the dispatch call "fft:recovery-alert" should name me as its reporter
    And the dispatch call "fft:recovery-alert" should carry the data "fftNote" set to "kept"
    And the dispatch call "fft:recovery-alert" should carry no data "fftNested"
    And raising the player alert "fft:recovery-alert" again should be refused while it cools down

  @server @seam @global
  Scenario: A player alert never fires an onAccept hook
    Given I am on duty as "tow" at grade 1
    And I listen for the dispatch acceptance event "fft:dispatch:player-alert-accepted"
    And the player alert "fft:recovery-alert" is registered for the job "tow"
    When I raise the player alert "fft:recovery-alert"
    And I respond to the dispatch call "fft:recovery-alert" as "en_route"
    Then my response to the dispatch call "fft:recovery-alert" should be "en_route"
    And the acceptance event "fft:dispatch:player-alert-accepted" should not have fired

  @server @seam @rejection
  Scenario: A unit-only player alert refuses an off-duty reporter
    Given I am off duty as "tow" at grade 1
    And the player alert "fft:recovery-units-only" is registered for the job "tow" for on-duty "recovery" units only
    Then raising the player alert "fft:recovery-units-only" should be refused with "reporter is not an eligible on-duty unit"

  @server @seam @rejection
  Scenario: A unit-only player alert refuses a reporter from another service
    Given I am on duty as "mechanic" at grade 1
    And the player alert "fft:recovery-units-only" is registered for the job "tow" for on-duty "recovery" units only
    Then raising the player alert "fft:recovery-units-only" should be refused with "reporter is not an eligible on-duty unit"

  @server @seam @global
  Scenario: A unit-only player alert accepts an on-duty unit of its service
    Given I am on duty as "tow" at grade 1
    And the player alert "fft:recovery-units-only" is registered for the job "tow" for on-duty "recovery" units only
    When I raise the player alert "fft:recovery-units-only"
    Then the dispatch call "fft:recovery-units-only" should name me as its reporter

  @server @seam @rejection
  Scenario: Player alert requests are validated
    Then raising the player alert "fft:recovery-alert" for an invalid reporter should be refused with "invalid player alert request"
    And raising the player alert "fft:never-registered" should be refused with "unknown player alert type"

  @server @seam @rejection
  Scenario: Malformed player alert registrations are refused
    Then registering the player alert "fft bad key!" should be refused with "alert key must be 1-64 letters":
      """
      { "jobs": ["tow"], "title": "FFT refused alert" }
      """
    And registering the player alert "-fft:refused" should be refused with "alert key must be 1-64 letters":
      """
      { "jobs": ["tow"], "title": "FFT refused alert" }
      """
    And registering the player alert "fft:refused" without a definition should be refused with "definition must be a table"
    And registering the player alert "fft:refused" should be refused with "cooldown must be at least 1000ms":
      """
      { "jobs": ["tow"], "title": "FFT refused alert", "cooldown": 500 }
      """
    And registering the player alert "fft:refused" should be refused with "requiredJobType must be a non-empty string":
      """
      { "jobs": ["tow"], "title": "FFT refused alert", "requiredJobType": "" }
      """
    And registering the player alert "fft:refused" should be refused with "at least one job or job type":
      """
      { "title": "FFT refused alert" }
      """
    And raising the player alert "fft:refused" should be refused with "unknown player alert type"

  # --- Feed keys, routes and presentation (client) ---------------------------

  @ui @seam @global
  Scenario: The feed keys select the newest call and the respond key walks it to clear
    Given I am on duty as "tow" at grade 1
    And my dispatch service should be "recovery"
    And a dispatch call known as "FFT key call" is raised with:
      """
      { "jobs": ["tow"], "title": "FFT key call", "priority": 3, "coords": { "x": 215.0, "y": -810.0, "z": 30.7 } }
      """
    And the dispatch feed should show the call "FFT key call"
    When I select the newest dispatch call with the feed keys
    Then the dispatch feed should have the call "FFT key call" selected
    When I press the dispatch "respond" key
    Then my response to the dispatch call "FFT key call" should be "en_route"
    And my dispatch route should lead to the call "FFT key call"
    When I press the dispatch "respond" key
    Then my response to the dispatch call "FFT key call" should be "on_scene"
    When I press the dispatch "respond" key
    Then my response to the dispatch call "FFT key call" should be "clear"
    And I should have no dispatch route

  @ui @seam @global
  Scenario: The next and previous keys move through the feed
    Given I am on duty as "tow" at grade 1
    And my dispatch service should be "recovery"
    And a dispatch call titled "FFT older key call" is raised for the job "tow"
    And a dispatch call titled "FFT newer key call" is raised for the job "tow"
    And the dispatch feed should show the call "FFT newer key call"
    When I select the newest dispatch call with the feed keys
    Then the dispatch feed should have the call "FFT newer key call" selected
    When I press the dispatch "next" key
    Then the dispatch feed should have the call "FFT older key call" selected
    When I press the dispatch "previous" key
    Then the dispatch feed should have the call "FFT newer key call" selected

  @ui @seam @global
  Scenario: The toggle key hides the feed but new calls are still announced
    Given I am on duty as "tow" at grade 1
    And my dispatch service should be "recovery"
    And my dispatch feed is shown
    When I press the dispatch "toggle" key
    Then the dispatch feed should be hidden
    When a dispatch call titled "FFT hidden feed call" is raised for the job "tow"
    Then I should see a notification containing "FFT hidden feed call"
    When I press the dispatch "toggle" key
    Then the dispatch feed should be shown

  @ui
  Scenario: The toggle key closes an open tablet instead of hiding the feed
    Given I am on duty as "tow" at grade 1
    And my dispatch service should be "recovery"
    And my dispatch feed is shown
    When I press the dispatch tablet key
    Then the app "kora_dispatch:tablet" should be open
    And the dispatch feed should be cleared
    When I press the dispatch "toggle" key
    Then no app should be open
    And the dispatch feed should be shown

  @ui @rejection
  Scenario: The presentation exports refuse bad input
    Then setting the dispatch theme to "blue" should be refused with "accent must be a #RRGGBB hex colour, got blue"
    And setting the dispatch theme to "#12345" should be refused with "accent must be a #RRGGBB hex colour"
    And setting the dispatch UI options to a non-table should be refused

  @ui @seam @global
  Scenario: A new call with a code is announced under that code
    Given I am on duty as "tow" at grade 1
    And my dispatch service should be "recovery"
    When a dispatch call known as "FFT coded call" is raised with:
      """
      { "jobs": ["tow"], "title": "FFT coded call", "code": "FFT-10", "priority": 3 }
      """
    Then I should see a notification containing "Dispatch FFT-10"
    And the dispatch feed should show the call "FFT coded call"

  # --- Tablet (client/ui.lua) -----------------------------------------------

  @ui @seam @global
  Scenario: The tablet offers only the next response and routes to the selected call
    Given I am on duty as "tow" at grade 1
    And my dispatch service should be "recovery"
    And a dispatch call known as "FFT tablet route call" is raised with:
      """
      { "jobs": ["tow"], "title": "FFT tablet route call", "priority": 3, "coords": { "x": 215.0, "y": -810.0, "z": 30.7 } }
      """
    And the dispatch feed should show the call "FFT tablet route call"
    When I press the dispatch tablet key
    Then the app "kora_dispatch:tablet" should be open
    When I select the dispatch call "FFT tablet route call" on the tablet
    Then the app action "dispatch:respond:on_scene" should be unavailable
    And the app action "dispatch:respond:clear" should be unavailable
    When I route to the selected dispatch call on the tablet
    Then my dispatch route should lead to the call "FFT tablet route call"
    And I should not be attached to the dispatch call "FFT tablet route call"
    When I respond "en_route" to the selected dispatch call on the tablet
    And I respond "on_scene" to the selected dispatch call on the tablet
    Then my response to the dispatch call "FFT tablet route call" should be "on_scene"
    And the app action "dispatch:respond:en_route" should be unavailable

  @ui @seam @global @rejection
  Scenario: The tablet cannot accept a second call while the unit is committed
    Given I am on duty as "tow" at grade 1
    And my dispatch service should be "recovery"
    And a dispatch call titled "FFT tablet first call" is raised for the job "tow"
    And a dispatch call titled "FFT tablet second call" is raised for the job "tow"
    And I respond to the dispatch call "FFT tablet first call" as "en_route"
    And the dispatch feed should show the call "FFT tablet second call"
    When I press the dispatch tablet key
    Then the app "kora_dispatch:tablet" should be open
    When I select the dispatch call "FFT tablet second call" on the tablet
    Then responding "en_route" to the selected dispatch call on the tablet should fail
    And I should not be attached to the dispatch call "FFT tablet second call"
    And my response to the dispatch call "FFT tablet first call" should be "en_route"

  @ui @seam @global @rejection
  Scenario: A call closed while selected can no longer be answered from the tablet
    Given I am on duty as "tow" at grade 1
    And my dispatch service should be "recovery"
    And a dispatch call titled "FFT tablet closed call" is raised for the job "tow"
    And the dispatch feed should show the call "FFT tablet closed call"
    When I press the dispatch tablet key
    Then the app "kora_dispatch:tablet" should be open
    When I select the dispatch call "FFT tablet closed call" on the tablet
    And the dispatch call "FFT tablet closed call" is closed with the reason "resolved by fft"
    Then the app action "dispatch:respond:en_route" should be unavailable
    And I should not be attached to the dispatch call "FFT tablet closed call"

  @ui
  Scenario: Going off duty closes an open tablet
    Given I am on duty as "tow" at grade 1
    And my dispatch service should be "recovery"
    When I press the dispatch tablet key
    Then the app "kora_dispatch:tablet" should be open
    When I end my dispatch shift
    Then no app should be open
    And I should have no dispatch service

  @ui @seam @global
  Scenario: Coming on duty shows calls already in progress without announcing them
    Given I am off duty as "tow" at grade 1
    And I should have no dispatch service
    And a dispatch call titled "FFT backlog call" is raised for the job "tow"
    When I start my dispatch shift
    Then my dispatch service should be "recovery"
    And the dispatch feed should show the call "FFT backlog call"
    And I should not see a notification containing "FFT backlog call"

  # Only an off-duty member of a dispatch service is told why (client/keybinds.lua).
  @ui @seam @global @rejection
  Scenario Outline: Players outside dispatch hear nothing about a recovery call
    Given I am <duty> as "<job>" at grade 1
    And I should have no dispatch service
    When a dispatch call titled "FFT unheard call" is raised for the job "tow"
    Then I should not see a notification containing "FFT unheard call"
    When I press the dispatch tablet key
    Then no app should be open
    And I should not see a notification containing "You are off duty"

    Examples:
      | duty     | job        |
      | on duty  | mechanic   |
      | off duty | unemployed |
