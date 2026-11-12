@kora @kora_lib
Feature: kora_lib shared interface and callback library
  kora_lib provides the notifications, text prompts, menus, dialogs, progress
  bars and client-server callbacks every other Kora resource builds on. These
  scenarios open each surface through the real consumer exports, as resource
  "fft", and answer it through kora_lib's existing test hook.

  Level: @ui scenarios work at the NUI-callback level. They prove the Lua side
  of the contract (payload validation, ownership, the value handed back to the
  caller). They do not click rendered controls and prove nothing about what the
  browser draws or validates; a refusal "as disabled", "as invalid" or "as
  locked" is the hook declining what the rendered surface would not offer.

  Not covered: minigames (never forced), cancelling a progress bar by control
  or by dying (only the owner cancel is), broadcast notifications to every player,
  AppShell apps and the interact selector (covered through kora_lib-playground,
  which registers real ones), keybinds, zones, placement, sounds, the clipboard,
  screenshots and the config editor (ACE-gated, global).

  Background:
    Given resource "kora_lib" is running

  @ui
  Scenario Outline: Client notification resolves its type
    When I send a kora_lib notification titled "<title>" with message "Sent by the functional tests" of type "<sent>"
    Then I should see a notification containing "<title>"
    And the kora_lib notification titled "<title>" should have type "<shown>"

    Examples:
      | title             | sent    | shown   |
      | FFT lib success   | success | success |
      | FFT lib inform    | inform  | info    |
      | FFT lib warn      | warn    | warning |
      | FFT lib error     | error   | error   |

  @ui @rejection
  Scenario: Notification with an unknown type is dropped
    When I send a kora_lib notification titled "FFT lib bogus type" with message "Must never be shown" of type "fft_bogus"
    Then I should not see a notification containing "FFT lib bogus type"

  @ui
  Scenario: Server notification reaches only the addressed player
    When the server sends me a kora_lib notification titled "FFT lib from server" with message "Pushed to the tester"
    Then I should see a notification containing "Pushed to the tester"
    # Config.notify.defaultType in kora_lib/config.lua.
    And the kora_lib notification titled "FFT lib from server" should have type "info"

  @ui
  Scenario: Text prompts stack, update and restore the previous prompt
    When I show the kora_lib text prompt "FFT first prompt"
    Then the text prompt should show "FFT first prompt"
    When I show the kora_lib text prompt "FFT second prompt" with key "E"
    Then the text prompt should show "FFT second prompt"
    And the kora_lib text prompt should show key "E" at "right-center"
    And the kora_lib text prompt "FFT second prompt" should be the visible one
    When I change the kora_lib text prompt "FFT second prompt" to "FFT changed prompt"
    Then the text prompt should show "FFT changed prompt"
    When I hide the kora_lib text prompt "FFT changed prompt"
    Then the text prompt should show "FFT first prompt"
    And the kora_lib text prompt "FFT changed prompt" should be gone
    When I hide the kora_lib text prompt "FFT first prompt"
    Then the kora_lib text prompt "FFT first prompt" should be gone

  @ui
  Scenario: Menu returns the chosen entry and the path through its submenus
    When I open a kora_lib menu titled "FFT lib menu" with:
      """
      [
        { "id": "fft_plain", "label": "FFT plain entry" },
        { "id": "fft_branch", "label": "FFT branch", "submenu": { "title": "FFT branch", "items": [
          { "id": "fft_leaf", "label": "FFT leaf entry" }
        ] } }
      ]
      """
    Then a menu titled "FFT lib menu" should open
    And the open kora_lib menu should be a "openMenu" menu
    And the menu should list "FFT plain entry"
    And the menu should list "FFT leaf entry"
    And choosing "FFT branch" in the kora_lib menu should be refused as "submenu"
    When I choose "FFT leaf entry" in the menu
    Then no menu should be open
    And the kora_lib menu should return the selection "fft_leaf" with path "fft_branch > fft_leaf"

  @ui @rejection
  Scenario: Context menu keeps a disabled entry unselectable and reports a cancel
    When I open a kora_lib context menu with:
      """
      [
        { "id": "fft_allowed", "label": "FFT allowed entry" },
        { "id": "fft_blocked", "label": "FFT blocked entry", "disabled": true }
      ]
      """
    Then a menu should open
    And the open kora_lib menu should be a "openContextMenu" menu
    And choosing "FFT blocked entry" in the kora_lib menu should be refused as "disabled"
    And choosing "FFT missing entry" in the kora_lib menu should be refused as "not_visible"
    When I close the menu
    Then no menu should be open
    And the kora_lib menu should return a cancellation

  @ui
  Scenario: Input dialog returns the submitted values
    When I open a kora_lib input dialog titled "FFT lib input" with fields:
      """
      [
        { "id": "fft_name", "label": "Name", "type": "text", "required": true },
        { "id": "fft_count", "label": "Count", "type": "number", "default": 1, "min": 1, "max": 10 }
      ]
      """
    Then an input dialog should open
    And the kora_lib input dialog should be titled "FFT lib input"
    And the kora_lib input dialog should have the field "fft_count"
    When I submit the input dialog with:
      """
      { "fft_name": "Functional Tester", "fft_count": 3 }
      """
    Then the kora_lib input dialog should be closed
    And the kora_lib input dialog should return "fft_name" as "Functional Tester"
    And the kora_lib input dialog should return "fft_count" as "3"

  @ui @rejection
  Scenario: Input dialog stays open on an incomplete submit and reports a cancel
    When I open a kora_lib input dialog titled "FFT lib required input" with fields:
      """
      [
        { "id": "fft_name", "label": "Name", "type": "text", "required": true }
      ]
      """
    Then an input dialog should open
    And submitting the kora_lib input dialog should be refused as "invalid" with:
      """
      { "fft_name": "" }
      """
    And submitting the kora_lib input dialog should be refused as "not_visible" with:
      """
      { "fft_name": "Functional Tester", "fft_unknown": "x" }
      """
    When I cancel the input dialog
    Then the kora_lib input dialog should be closed
    And the kora_lib input dialog should return a cancellation

  @ui
  Scenario Outline: Confirmation returns the player's answer
    When I open a kora_lib confirmation titled "FFT lib confirm" with message "Answered by the functional tests"
    Then a confirmation should open
    And the kora_lib confirmation should be titled "FFT lib confirm"
    When I <answer>
    Then the kora_lib confirmation should be closed
    And the kora_lib confirmation should return <result>

    Examples:
      | answer  | result    |
      | confirm | confirmed |
      | decline | declined  |

  @ui @rejection
  Scenario: Acknowledge-only alert cannot be declined
    When I open a kora_lib acknowledgement titled "FFT lib acknowledge" with message "Only the confirm button closes this"
    Then a confirmation should open
    And declining the kora_lib confirmation should be refused as locked
    When I confirm
    Then the kora_lib confirmation should be closed
    And the kora_lib confirmation should return confirmed

  @ui
  Scenario: Progress bar runs to the end and refuses a second bar meanwhile
    When I start a kora_lib progress bar labelled "FFT lib progress" lasting 3000 milliseconds
    Then a progress bar labelled "FFT lib progress" should start
    And starting a second kora_lib progress bar should be refused
    And the progress bar should finish
    And the kora_lib progress bar should report completion

  Scenario: Callbacks round-trip in both directions
    Given the server registers the kora_lib callback "fft:kora_lib:server-echo"
    And my client registers the kora_lib callback "fft:kora_lib:client-echo"
    When I trigger the kora_lib server callback "fft:kora_lib:server-echo" with "ping from client"
    Then the kora_lib server callback should answer "server echo: ping from client"
    And the kora_lib callback "fft:kora_lib:server-echo" should have been called by me with "ping from client"
    And the server asking my client for the kora_lib callback "fft:kora_lib:client-echo" with "ping from server" should get "client echo: ping from server"

  @rejection
  Scenario: Unregistered callbacks are refused in both directions
    Given the server registers the kora_lib callback "fft:kora_lib:server-echo"
    When I trigger the kora_lib server callback "fft:kora_lib:never-registered" with "ping"
    Then the kora_lib server callback should fail with "is not registered on the server"
    And the kora_lib callback "fft:kora_lib:server-echo" should not have been called
    And the server asking my client for the kora_lib callback "fft:kora_lib:never-registered" should fail with "is not registered on the client"

  @ui @rejection
  Scenario: Invalid surface payloads are refused before anything opens
    Then showing a kora_lib text prompt at position "middle-nowhere" should be refused
    And hiding a kora_lib text prompt that was never shown should be refused
    And opening a kora_lib menu whose item has no id should be refused
    And starting a kora_lib progress bar lasting 0 milliseconds should be refused
    And no menu should be open
    And no progress bar should be running

  @server
  Scenario: Utility exports answer from the server and refuse invalid arguments
    Then kora_lib should clamp 15 between 1 and 10 to 10
    And kora_lib should clamp -4 between 1 and 10 to 1
    And kora_lib should clamp 7 between 1 and 10 to 7
    And kora_lib should round 2.346 to 2 decimal places as 2.35
    And kora_lib should round 7.5 to 0 decimal places as 8.0
    And kora_lib should trim "  padded text  " to "padded text"
    And kora_lib should truncate "functional" to 4 characters as "func"
    And kora_lib should treat the callback name "fft:kora_lib:server-echo" as valid
    But kora_lib should refuse to clamp 5 between 10 and 1
    And kora_lib should refuse an empty callback name

  # -------------------------------------------------------------------------
  # Edge cases
  # -------------------------------------------------------------------------

  @ui
  Scenario: Message-only notification takes the configured defaults
    When I send a kora_lib notification with only the message "FFT lib defaults only"
    Then I should see a notification containing "FFT lib defaults only"
    # Config.notify in kora_lib/config.lua: info, top-right, 5000 ms.
    And the kora_lib notification with message "FFT lib defaults only" should use position "top-right" and last 5000 milliseconds

  @ui @rejection
  Scenario Outline: Malformed notification payloads never reach the screen
    Then sending a kora_lib notification with "<problem>" should be dropped

    Examples:
      | problem                      |
      | no title or message          |
      | a zero duration              |
      | a fractional duration        |
      | a duration above the maximum |
      | an unknown position          |
      | a non-string title           |
      | an unknown icon animation    |

  @ui @rejection
  Scenario: Server notification longer than the maximum duration is dropped
    When the server sends me a kora_lib notification titled "FFT lib too long" lasting 120001 milliseconds
    Then I should not see a notification containing "FFT lib too long"

  @ui
  Scenario Outline: Text prompt honours every supported position
    When I show the kora_lib text prompt "FFT positioned prompt" with key "G" at position "<position>"
    Then the text prompt should show "FFT positioned prompt"
    And the kora_lib text prompt should show key "G" at "<position>"
    When I hide the kora_lib text prompt "FFT positioned prompt"
    Then the kora_lib text prompt "FFT positioned prompt" should be gone

    Examples:
      | position      |
      | left-center   |
      | right-center  |
      | top-center    |
      | bottom-center |

  @ui
  Scenario: Hiding a prompt below the top of the stack leaves the visible one alone
    When I show the kora_lib text prompt "FFT bottom prompt"
    And I show the kora_lib text prompt "FFT middle prompt"
    And I show the kora_lib text prompt "FFT top prompt"
    Then the kora_lib text prompt "FFT top prompt" should be the visible one
    And the kora_lib text prompt "FFT middle prompt" should not be the visible one
    When I hide the kora_lib text prompt "FFT middle prompt"
    Then the text prompt should show "FFT top prompt"
    And the kora_lib text prompt "FFT middle prompt" should be gone
    And hiding the kora_lib text prompt "FFT middle prompt" again should be refused
    When I hide the kora_lib text prompt "FFT top prompt"
    Then the text prompt should show "FFT bottom prompt"
    And a kora_lib text prompt should be open
    When I hide the kora_lib text prompt "FFT bottom prompt"
    Then the kora_lib text prompt "FFT bottom prompt" should be gone

  @ui @rejection
  Scenario Outline: Invalid text prompts are refused
    Then showing a kora_lib text prompt with "<problem>" should be refused
    And changing a kora_lib text prompt that was never shown should be refused

    Examples:
      | problem                   |
      | empty text                |
      | an empty key              |
      | an unknown icon animation |
      | a numeric icon            |

  @ui
  Scenario: Radial menu returns the chosen entry
    When I open a kora_lib radial menu with:
      """
      [
        { "id": "fft_radial_one", "label": "FFT radial one" },
        { "id": "fft_radial_two", "label": "FFT radial two" }
      ]
      """
    Then a menu should open
    And the open kora_lib menu should be a "openRadialMenu" menu
    And the menu should list "FFT radial two"
    When I choose "FFT radial two" in the menu
    Then no menu should be open
    And the kora_lib menu should return the selection "fft_radial_two" with path "fft_radial_two"

  @ui @rejection
  Scenario: Menu that cannot be closed refuses a cancel until an entry is chosen
    When I open a kora_lib menu titled "FFT locked menu" that cannot be closed with:
      """
      [
        { "id": "fft_locked_only", "label": "FFT locked entry" }
      ]
      """
    Then a menu titled "FFT locked menu" should open
    And closing the kora_lib menu should be refused as locked
    When I choose "FFT locked entry" in the menu
    Then no menu should be open
    And the kora_lib menu should return the selection "fft_locked_only" with path "fft_locked_only"

  @ui @rejection
  Scenario Outline: Menus with invalid items are refused before opening
    Then opening a kora_lib menu with "<problem>" should be refused

    Examples:
      | problem                           |
      | a duplicate item id               |
      | an empty label                    |
      | an empty id                       |
      | progress above 100                |
      | a negative progress               |
      | a default index without values    |
      | a default index beyond its values |
      | a non-boolean disabled flag       |
      | an invalid submenu item           |
      | no items table                    |

  @ui @rejection
  Scenario: Menus with invalid options are refused before opening
    Then opening a kora_lib menu with the option "a non-boolean canClose" should be refused
    And opening a kora_lib menu with the option "an unknown presentation" should be refused
    And opening a kora_lib menu with the option "a zero start index" should be refused
    And opening a kora_lib menu with the option "a negative width" should be refused
    And opening a kora_lib menu with the option "an unknown horizontal position" should be refused
    And opening a kora_lib radial menu with "a zero radius" should be refused
    And opening a kora_lib radial menu with "five label lines" should be refused
    And opening a kora_lib radial menu with "zero label lines" should be refused
    And opening a kora_lib context menu at a non-numeric position should be refused
    And no menu should be open

  @ui @rejection
  Scenario Outline: Invalid confirmations are refused before opening
    Then opening a kora_lib confirmation with "<problem>" should be refused

    Examples:
      | problem                        |
      | an empty message               |
      | no message                     |
      | an unknown size                |
      | a non-boolean cancellable flag |
      | a numeric title                |

  @ui @rejection
  Scenario Outline: Input dialogs with invalid fields are refused before opening
    Then opening a kora_lib input dialog with "<problem>" should be refused

    Examples:
      | problem                          |
      | a duplicate field id             |
      | an unknown field type            |
      | a field without a label          |
      | a minimum above its maximum      |
      | a select without options         |
      | a vector without dimensions      |
      | a dependency on an unknown field |
      | a non-boolean checkbox default   |
      | a non-numeric number default     |
      | a non-boolean required flag      |

  @ui
  Scenario: Owner can cancel its own progress bar
    Given cancelling a kora_lib progress bar when none is running should be refused
    When I start a kora_lib progress bar labelled "FFT lib cancelled progress" lasting 8000 milliseconds
    Then a progress bar labelled "FFT lib cancelled progress" should start
    When I cancel the kora_lib progress bar
    Then the kora_lib progress bar should report a cancellation
    And no progress bar should be running
    And cancelling a kora_lib progress bar when none is running should be refused

  @ui
  Scenario: Progress bar validation accepts the limits without starting a bar
    Then kora_lib should accept a progress bar lasting 1 milliseconds
    And kora_lib should accept a progress bar lasting 600000 milliseconds
    And kora_lib should accept a progress bar lasting 900000 milliseconds with no maximum
    And no progress bar should be running

  @ui @rejection
  Scenario Outline: Progress bar validation refuses malformed payloads
    Then validating a kora_lib progress bar with "<problem>" should be refused

    Examples:
      | problem                          |
      | an empty label                   |
      | a fractional duration            |
      | a negative duration              |
      | a duration above the maximum     |
      | a duration above its own maximum |
      | a zero maximum                   |
      | an unknown presentation          |
      | an unknown position              |
      | a non-boolean canCancel          |
      | both an animation and a scenario |

  @rejection
  Scenario: Server callback rate limit refuses calls beyond the limit
    Given the server registers the kora_lib callback "fft:kora_lib:limited-echo" limited to 2 calls per 10000 milliseconds
    When I trigger the kora_lib server callback "fft:kora_lib:limited-echo" with "first"
    Then the kora_lib server callback should answer "server echo: first"
    When I trigger the kora_lib server callback "fft:kora_lib:limited-echo" with "second"
    Then the kora_lib server callback should answer "server echo: second"
    When I trigger the kora_lib server callback "fft:kora_lib:limited-echo" with "third"
    Then the kora_lib server callback should fail with "Callback rate limit exceeded; retry in"
    And the kora_lib callback "fft:kora_lib:limited-echo" should have been called 2 times by me

  @rejection
  Scenario: Unregistered server callback stops answering
    Given the server registers the kora_lib callback "fft:kora_lib:server-echo"
    When I trigger the kora_lib server callback "fft:kora_lib:server-echo" with "before"
    Then the kora_lib server callback should answer "server echo: before"
    When the server unregisters the kora_lib callback "fft:kora_lib:server-echo"
    And I trigger the kora_lib server callback "fft:kora_lib:server-echo" with "after"
    Then the kora_lib server callback should fail with "is not registered on the server"
    And the kora_lib callback "fft:kora_lib:server-echo" should have been called 1 times by me
    And the server unregistering the kora_lib callback "fft:kora_lib:never-registered" it never registered should be refused

  Scenario: Callback hands back every value its handler returned
    Given the server registers the kora_lib callback "fft:kora_lib:two-values" answering false and "FFT lib reason"
    Then triggering the kora_lib server callback "fft:kora_lib:two-values" should answer false and "FFT lib reason"

  @server @rejection
  Scenario: Callback names, handlers, rate limits and targets are validated
    Then kora_lib should refuse a callback name longer than 128 bytes
    And kora_lib should refuse a non-string callback name
    And kora_lib should refuse to register the callback "fft:kora_lib:bad-limit" with a rate limit of 0 calls
    And kora_lib should refuse to register the callback "fft:kora_lib:no-handler" without a handler
    And the server asking player 0 for a kora_lib callback should be refused

  Scenario: Client events reach the registered server handler only while registered
    Given the server registers the kora_lib event "fft:kora_lib:event"
    When I trigger the kora_lib server event "fft:kora_lib:event" with "first event"
    Then the kora_lib event "fft:kora_lib:event" should have reached the server 1 times from me
    And the first kora_lib event "fft:kora_lib:event" should have carried "first event"
    When I trigger the kora_lib server event "fft:kora_lib:never-registered-event" with "dropped"
    And the server unregisters the kora_lib event "fft:kora_lib:event"
    And I trigger the kora_lib server event "fft:kora_lib:event" with "after unregister"
    Then the kora_lib event "fft:kora_lib:event" should have reached the server 1 times from me

  @rejection
  Scenario: Server event rate limit silently drops calls beyond the limit
    Given the server registers the kora_lib event "fft:kora_lib:limited-event" limited to 2 calls per 10000 milliseconds
    When I trigger the kora_lib server event "fft:kora_lib:limited-event" with "one"
    And I trigger the kora_lib server event "fft:kora_lib:limited-event" with "two"
    And I trigger the kora_lib server event "fft:kora_lib:limited-event" with "three"
    Then the kora_lib event "fft:kora_lib:limited-event" should have reached the server 2 times from me

  Scenario: Server pushes reach my client only while it listens
    Given my client listens for the kora_lib push "fft:kora_lib:push"
    When the server pushes the kora_lib event "fft:kora_lib:push" to me with "first push"
    Then my client should have received 1 kora_lib pushes named "fft:kora_lib:push"
    And the last kora_lib push named "fft:kora_lib:push" should carry "first push"
    When my client stops listening for the kora_lib push "fft:kora_lib:push"
    And the server pushes the kora_lib event "fft:kora_lib:push" to me with "unheard push"
    Then my client should have received 1 kora_lib pushes named "fft:kora_lib:push"
    And my client stopping the kora_lib push "fft:kora_lib:push" it never listened for should be refused

  @server @rejection
  Scenario: Event names, handlers and push targets are validated
    Then kora_lib should refuse an empty event name
    And kora_lib should refuse an event name longer than 128 bytes
    And kora_lib should refuse to push an event to player 0
    And kora_lib should refuse to register the event "fft:kora_lib:no-handler-event" without a handler

  Scenario: Client status effect is applied, reported and removed by its owner
    Given my client registers the kora_lib status effect "fft:kora_lib:status-plain"
    And my client listens for kora_lib status changes
    When I apply the kora_lib status effect "fft:kora_lib:status-plain"
    Then the kora_lib status effect "fft:kora_lib:status-plain" should be active on my client
    When I remove the kora_lib status effect "fft:kora_lib:status-plain"
    Then the kora_lib status effect "fft:kora_lib:status-plain" should be inactive on my client
    And my client should have heard the kora_lib status effect "fft:kora_lib:status-plain" applied then removed
    And removing the kora_lib status effect "fft:kora_lib:status-plain" from my client should be refused
    And my client stops listening for kora_lib status changes

  Scenario: Timed client status effect expires by itself
    Given my client registers the kora_lib status effect "fft:kora_lib:status-timed"
    When I apply the kora_lib status effect "fft:kora_lib:status-timed" for 1500 milliseconds
    Then the kora_lib status effect "fft:kora_lib:status-timed" should be active on my client
    And the kora_lib status effect "fft:kora_lib:status-timed" should be inactive on my client

  Scenario: Server-applied status effect can only be removed by the server
    Given my client registers the kora_lib status effect "fft:kora_lib:status-server"
    And the server registers the kora_lib status effect "fft:kora_lib:status-server"
    When the server applies the kora_lib status effect "fft:kora_lib:status-server" to me
    Then the kora_lib status effect "fft:kora_lib:status-server" should be active on my client
    And removing the kora_lib status effect "fft:kora_lib:status-server" from my client should be refused
    When the server removes the kora_lib status effect "fft:kora_lib:status-server" from me
    Then the kora_lib status effect "fft:kora_lib:status-server" should be inactive on my client

  @rejection
  Scenario: Unknown and malformed status effects are refused
    Then applying the unregistered kora_lib status effect "fft:kora_lib:status-never" should be refused
    And the server applying the unregistered kora_lib status effect "fft:kora_lib:status-never" to me should be refused
    And kora_lib should refuse a status effect with the stacking mode "fft_pile"

  @server
  Scenario: Timeouts and intervals fire, stop when cleared and refuse bad arguments
    Then a kora_lib timeout of 300 milliseconds should fire exactly once
    And a cleared kora_lib timeout should never fire
    And a kora_lib interval of 200 milliseconds should tick until it is cleared
    And clearing a kora_lib timer that was never set should be refused
    And kora_lib should refuse a timeout with a negative delay
    And kora_lib should refuse an interval without a callable

  @server
  Scenario: Cooldowns gate each key separately and reset on request
    Then a kora_lib cooldown of 60000 milliseconds should gate each key separately

  @server
  Scenario: Text utilities hash, clean, truncate and decode
    Then kora_lib should hash "" as "811c9dc5"
    And kora_lib should hash "a" as "e40c292c"
    And kora_lib should hash "kora_lib" as "7eadc4fe"
    And kora_lib should clean "  several   spaced    words  " to "several spaced words"
    And kora_lib should clean "functional tests" to at most 5 characters as "funct"
    And kora_lib should clean "     " to nothing because it is "empty"
    And kora_lib should refuse to clean a number as text
    And kora_lib should truncate "héllo wörld" to 4 characters as "héll"
    And kora_lib should truncate "short" to 10 characters as "short"
    And kora_lib should truncate "functional" to 0 characters as ""
    And kora_lib should decode valid JSON and report broken JSON as invalid
    And kora_lib should tell finite numbers and integers apart

  @server
  Scenario: Numeric and vector utilities compute the expected values
    Then kora_lib should clamp 1 between 1 and 1 to 1
    And kora_lib should round 2.5 to 0 decimal places as 3.0
    And kora_lib should round -2.5 to 0 decimal places as -2.0
    And kora_lib should round 1234.0 to -2 decimal places as 1200.0
    And kora_lib should interpolate from 10 to 20 at 0.25 as 12.5
    And kora_lib should interpolate from 10 to 20 at 1.5 as 25.0
    And kora_lib should interpolate from 10 to 20 at -0.5 as 5.0
    And kora_lib vector helpers should agree on a 3-4-5 triangle
    And kora_lib headings and directions should round-trip

  @server @rejection
  Scenario: Text utilities refuse invalid arguments
    Then kora_lib should refuse invalid text arguments

  @server
  Scenario: Random helpers and rewards stay inside their contract
    Then kora_lib random helpers should stay inside their bounds
    And kora_lib should generate deterministic rewards

  @server @rejection
  Scenario: Random helpers refuse invalid arguments
    Then kora_lib should refuse invalid random arguments

  @server @rejection
  Scenario: Reward generation refuses invalid tables
    Then kora_lib should refuse invalid reward tables

  @server
  Scenario: Vehicle plates are normalised and invalid plates rejected
    Then kora_lib should normalise the plate "  ab 12  cd " to "AB 12 CD"
    And kora_lib should normalise the plate " ab 12  cd" without whitespace to "AB12CD"
    And kora_lib should normalise the plate "fft1" to "FFT1"
    And kora_lib should reject the plate "TOOLONGPLATE" as "too_long"
    And kora_lib should reject the plate "AB-12" as "invalid_characters"
    And kora_lib should reject the plate "    " as "empty"
    And kora_lib should accept the plate "ab-12" with any characters up to 10 long as "AB-12"

  @server
  Scenario: Permission helpers resolve the tester's level read-only
    Then I should hold the kora_lib permission "user"
    And my kora_lib permission level among "fft_kora_lib_never, user" should be "user"
    And I should meet the kora_lib level "user" among "fft_kora_lib_never, user"
    But I should not meet the kora_lib level "fft_kora_lib_never" among "fft_kora_lib_never, user"

  @server @rejection
  Scenario: Permission helpers refuse invalid players and level lists
    Then kora_lib should refuse permission checks without a valid player or level list
