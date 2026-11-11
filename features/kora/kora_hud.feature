@kora @kora_hud
Feature: kora_hud status HUD
  kora_hud is client-only and draws in its own NUI page. Its state is
  file-local, so these scenarios observe the messages client/hud.lua sends to
  the page through kora_hud/fft_hooks.lua, which wraps the global
  SendNUIMessage. Every "payload" assertion proves what Lua sent, not what the
  page rendered. The wrap is unverified live under use_experimental_fxv2_oal:
  if it cannot see the sends, every scenario fails at its first HUD step and a
  one-line seam in client/hud.lua's `send` is needed instead.

  The /ui element registry is exercised with fft itself as the owner, so no
  other resource's element is touched; only built-in sections, chatInput and
  elements a scenario registered are ever written to the saved layout, because
  writeLayout carries unknown ids over for good.

  Not covered: gauge, minimap and editor rendering and dragging (visual, DOM),
  layout persistence across a reconnect, /hudlayoutreset and /uireset (they
  delete the tester's own client-side layout, including entries of resources
  that are not running, which cannot be put back exactly), the layout size
  limits (48 entries, 16384 bytes: reaching them needs unknown ids that would
  stay in the layout), the real seatbelt buckle path (kora_utils plays the sound
  to nearby players), the stress gain rules in client/stress.lua (they write
  server metadata from driving and shooting), the pause-menu hide, the
  hud:client:LoadMap event and the microphone indicator.

  Background:
    Given resource "kora_hud" is running
    And the HUD should be visible

  @ui
  Scenario: Page handshake receives the full initial state
    When the HUD page asks for its initial state
    Then the HUD page should receive its full initial state
    And the HUD configuration payload should carry the layout command "hudlayout"
    And the HUD page should be told it is shown

  @ui
  Scenario: Hide and show exports toggle the HUD
    When I force the HUD hidden through its export
    Then the HUD should be hidden
    And the HUD page should be told it is not shown
    When I release the forced HUD hide through its export
    Then the HUD should be visible
    And the HUD page should be told it is shown
    And the HUD page should receive "kora_hud:update"

  @ui @rejection
  Scenario: A hidden HUD is not sent player updates
    Given I force the HUD hidden through its export
    And the HUD should be hidden
    And I start watching the HUD page messages
    When I have 311 in my "cash" account
    Then the HUD page should not receive "kora_hud:update" within 1500 milliseconds
    When I release the forced HUD hide through its export
    Then the HUD player payload should show "cash" as 311

  @ui
  Scenario: Cash and bank changes reach the HUD payload
    Given I start watching the HUD page messages
    When I have 311 in my "cash" account
    Then the HUD player payload should show "cash" as 311
    When I start watching the HUD page messages
    And I have 4242 in my "bank" account
    Then the HUD player payload should show "bank" as 4242

  @ui
  Scenario: Job change reaches the HUD payload
    Given I start watching the HUD page messages
    When my job is "mechanic" at grade 1
    Then the HUD player payload should name my job "mechanic"
    And my job should be "mechanic"

  @ui
  Scenario: Armour change reaches the vitals payload
    When my ped armour is 37 for the HUD
    Then the HUD vitals payload should show armour 37

  @ui
  Scenario: Balance command shows the authoritative cash
    Given I start watching the HUD page messages
    And I have 311 in my "cash" account
    And the HUD player payload should show "cash" as 311
    When I run the command "cash"
    Then I should see a notification containing "$311"

  @ui
  Scenario: Player id command toggles the id display
    When I toggle the HUD player id display
    And I toggle the HUD player id display
    Then the HUD player id toggles should alternate between my server id and cleared

  @ui
  Scenario: Legacy stress event overlays the display only
    Given I remember my server-side stress
    When the HUD receives the legacy stress event with 41
    Then the HUD player payload should show "stress" as 41
    And my server-side stress should be unchanged by the HUD

  @ui @world
  Scenario: Entering a vehicle starts vehicle telemetry
    Given I start watching the HUD page messages
    When I am driving a temporary "blista"
    Then the HUD vehicle payload should describe the vehicle I am in

  @ui
  Scenario: Layout editor opens and cancels without saving
    When I open the HUD layout editor
    Then the HUD layout editor should be open
    When I cancel the HUD layout editor
    Then the HUD layout editor should be closed
    And the saved HUD layout should be what it was before the editor opened

  @ui
  Scenario: Layout editor saves a moved section
    When I open the HUD layout editor
    And I save the HUD layout with the "gauges" section moved to 0.1 -0.2
    Then the HUD layout editor should be closed
    And the saved HUD layout should place "gauges" at 0.1 -0.2

  # LAYOUT_BOUNDS.gauges in client/hud.lua: x within -0.5..0.5, y within -0.95..0.
  @ui @rejection
  Scenario: Layout editor clamps an out-of-bounds section
    When I open the HUD layout editor
    And I save the HUD layout with the "gauges" section moved to 5.0 5.0
    Then the HUD layout editor should be closed
    And the saved HUD layout should place "gauges" at 0.5 0.0

  # ---------------------------------------------------------------------------
  # Handshake and visibility edges
  # ---------------------------------------------------------------------------

  @ui
  Scenario: Configuration payload mirrors the saved layout
    When the HUD page asks for its initial state
    Then the HUD configuration payload should match my saved layout

  @ui
  Scenario: Hiding an already hidden HUD sends nothing
    Given I force the HUD hidden through its export
    And the HUD should be hidden
    When I force the HUD hidden through its export again
    Then the HUD page should not receive "kora_hud:visibility" within 1000 milliseconds
    And the HUD should be hidden

  @ui
  Scenario: Showing a visible HUD sends nothing
    When I release the forced HUD hide through its export
    Then the HUD page should not receive "kora_hud:visibility" within 1000 milliseconds
    And the HUD should be visible

  @ui
  Scenario: A hidden HUD answers the page handshake without player data
    Given I force the HUD hidden through its export
    And the HUD should be hidden
    When the HUD page asks for its initial state
    Then the HUD page should receive "kora_hud:config"
    And the HUD page should receive "kora_hud:compat"
    And the HUD page should be told it is not shown
    And the HUD page should not receive "kora_hud:vitals" within 1000 milliseconds
    And the HUD page should not receive "kora_hud:update" within 200 milliseconds

  @ui @rejection
  Scenario: The layout editor does not open while the HUD is hidden
    Given I force the HUD hidden through its export
    And the HUD should be hidden
    When I try to open the HUD layout editor
    Then the HUD page should not receive "kora_hud:layoutMode" within 1000 milliseconds

  @ui
  Scenario: Hiding the HUD closes an open layout editor
    When I open the HUD layout editor
    Then the HUD layout editor should be open
    When I force the HUD hidden through its export
    Then the HUD layout editor should be closed
    And the HUD should announce that the layout editor is closed
    And the HUD layout editor should have released the cursor
    And the HUD page should be told it is not shown

  # ---------------------------------------------------------------------------
  # Layout editor
  # ---------------------------------------------------------------------------

  # Config.layout.command, Config.uiEditor.command and Config.uiEditor.aliases.
  @ui
  Scenario Outline: Every editor command opens the same editor
    When I open the HUD layout editor with the command "<command>"
    Then the HUD layout editor should be open
    And the HUD should announce that the layout editor is open
    And the HUD page should receive "kora_hud:uiElements"
    When I cancel the HUD layout editor
    Then the HUD layout editor should be closed
    And the HUD should announce that the layout editor is closed
    And the HUD layout editor should have released the cursor

    Examples:
      | command     |
      | hudlayout   |
      | ui          |
      | hudsettings |

  @ui @rejection
  Scenario: A second editor command is ignored while the editor is open
    When I open the HUD layout editor
    And I try to open the HUD layout editor
    Then the HUD page should not receive "kora_hud:layoutMode" within 1000 milliseconds
    When I cancel the HUD layout editor
    Then the HUD layout editor should be closed

  @ui @rejection
  Scenario: A layout confirmed while the editor is closed is not saved
    When the HUD page finishes the layout while the editor is closed
    Then the HUD page should not receive "kora_hud:layoutMode" within 500 milliseconds
    And the saved HUD layout should be what it was before the editor opened

  # LAYOUT_BOUNDS in client/hud.lua.
  @ui
  Scenario Outline: Each section is kept inside its own bounds
    When I open the HUD layout editor
    And I save the HUD layout with the "<section>" section moved to <x> <y>
    Then the HUD layout editor should be closed
    And the saved HUD layout should place "<section>" at <savedX> <savedY>

    Examples:
      | section  | x    | y    | savedX | savedY |
      | gauges   | -5.0 | -5.0 | -0.5   | -0.95  |
      | vehicle  | 0.2  | 0.3  | 0.2    | 0.0    |
      | identity | 0.5  | -2.0 | 0.0    | -0.95  |
      | identity | -0.3 | -0.4 | -0.3   | -0.4   |
      | status   | -2.0 | 2.0  | -0.95  | 1.0    |
      | status   | 0.4  | 0.5  | 0.0    | 0.5    |

  # LAYOUT_SCALE_MIN / LAYOUT_SCALE_MAX in client/hud.lua.
  @ui
  Scenario Outline: Section scale is clamped to 0.75-1.5
    When I open the HUD layout editor
    And I save the HUD layout with the "<section>" section scaled to <scale>
    Then the saved HUD layout should scale "<section>" to <saved>

    Examples:
      | section | scale | saved |
      | gauges  | 3.0   | 1.5   |
      | gauges  | 0.1   | 0.75  |
      | vehicle | 1.2   | 1.2   |
      | status  | -1.0  | 0.75  |

  @ui
  Scenario: A section can be justified
    When I open the HUD layout editor
    And I save the HUD layout with the "identity" section justified "right"
    Then the saved HUD layout should justify "identity" to the "right"

  @ui @rejection
  Scenario: An unknown justification is dropped
    When I open the HUD layout editor
    And I save the HUD layout with the "identity" section justified "middle"
    Then the HUD layout editor should be closed
    And the saved HUD layout should have no justification for "identity"

  @ui
  Scenario: A built-in section can be hidden
    When I open the HUD layout editor
    And I save the HUD layout with the "status" section hidden
    Then the saved HUD layout should hide "status"

  @ui
  Scenario: The gauges can be released from the bottom edge
    When I open the HUD layout editor
    And I save the HUD layout with the gauges no longer bottom anchored
    Then the saved HUD layout should not anchor the gauges to the bottom

  @ui
  Scenario: Minimap only in vehicle can be switched
    When I open the HUD layout editor
    And I save the HUD layout with minimap only in vehicle switched
    Then the saved HUD layout should have minimap only in vehicle switched

  @ui
  Scenario: Saving an empty layout clears moved sections
    When I open the HUD layout editor
    And I save the HUD layout with the "gauges" section moved to 0.12 -0.12
    Then the saved HUD layout should place "gauges" at 0.12 -0.12
    When I open the HUD layout editor
    And I save an empty HUD layout
    Then the saved HUD layout should have no offset for "gauges"

  @ui @rejection
  Scenario: A non-numeric offset is dropped
    When I open the HUD layout editor
    And I save the HUD layout with the "identity" section moved to -0.1 -0.1
    Then the saved HUD layout should place "identity" at -0.1 -0.1
    When I open the HUD layout editor
    And I save the HUD layout with a non-numeric offset for "identity"
    Then the saved HUD layout should have no offset for "identity"

  # syncChatInputLayout in client/hud.lua; chatInput bounds are +-0.95.
  @ui
  Scenario: Saving the chat composer position tells kora_chat
    Given resource "kora_chat" is running
    When I open the HUD layout editor
    And I save the HUD layout with the "chatInput" section moved to 0.25 -0.25
    Then the chat composer should be told to move to 0.25 -0.25
    And the saved HUD layout should place "chatInput" at 0.25 -0.25

  @ui
  Scenario: The chat composer is clamped to its bounds
    Given resource "kora_chat" is running
    When I open the HUD layout editor
    And I save the HUD layout with the "chatInput" section moved to 2.0 -2.0
    Then the saved HUD layout should place "chatInput" at 0.95 -0.95
    And the chat composer should be told to move to 0.95 -0.95

  # ---------------------------------------------------------------------------
  # Vitals and player payload
  # ---------------------------------------------------------------------------

  @ui
  Scenario: Armour changes reach the vitals payload at both ends of the range
    When my ped armour is 37 for the HUD
    Then the HUD vitals payload should show armour 37
    When my ped armour is 100 for the HUD
    Then the HUD vitals payload should show armour 100
    When my ped armour is 0 for the HUD
    Then the HUD vitals payload should show armour 0

  @ui
  Scenario: Health change reaches the vitals payload
    When my ped health is 150 for the HUD
    Then the HUD vitals payload should show health 150

  @ui
  Scenario: Vitals carry the ped's maximum health
    When the HUD page asks for its initial state
    Then the HUD vitals payload should carry my ped maximum health

  @ui
  Scenario: Job grade and duty reach the HUD payload
    Given I start watching the HUD page messages
    When I am off duty as "mechanic" at grade 1
    Then the HUD player payload should name my job "mechanic" at grade 1
    And the HUD player payload should show me off duty
    And I should be off duty
    When I start watching the HUD page messages
    And I am on duty as "mechanic" at grade 1
    Then the HUD player payload should show me on duty
    And I should be on duty

  # Gangs from kora_core/shared/gangs.lua; 'none' is sent as no gang.
  @ui
  Scenario: Gang membership reaches the HUD payload
    Given I start watching the HUD page messages
    When my gang is "ballas" at grade 0
    Then the HUD player payload should name my gang "ballas"
    When I start watching the HUD page messages
    And my gang is "none" at grade 0
    Then the HUD player payload should show no gang

  @ui
  Scenario: Hunger and thirst metadata reach the HUD payload
    Given I start watching the HUD page messages
    When my metadata "hunger" is 43
    And my metadata "thirst" is 57
    Then the HUD player payload should show "hunger" as 43
    And the HUD player payload should show "thirst" as 57

  # ---------------------------------------------------------------------------
  # qb-hud compatibility events (client/compat.lua)
  # ---------------------------------------------------------------------------

  @ui
  Scenario: Legacy needs event is clamped and display-only
    Given I start watching the HUD page messages
    And my metadata "hunger" is 40
    And my metadata "thirst" is 40
    And the HUD player payload should show "hunger" as 40
    And the HUD player payload should show "thirst" as 40
    When the HUD receives the legacy needs event with hunger 150 and thirst -5
    Then the HUD player payload should show "hunger" as 100
    And the HUD player payload should show "thirst" as 0
    And my metadata "hunger" should be at most 40
    And my metadata "thirst" should be at most 40

  @ui @rejection
  Scenario: Legacy needs event with unreadable values changes nothing
    Given I start watching the HUD page messages
    And my metadata "hunger" is 40
    And the HUD player payload should show "hunger" as 40
    When the HUD receives the legacy needs event with hunger 70 and thirst 70
    Then the HUD player payload should show "hunger" as 70
    When the HUD receives the legacy needs event with unreadable values
    And the HUD page asks for its initial state
    Then the HUD player payload should show "hunger" as 70

  @ui
  Scenario: Legacy stress event is clamped and ignores text
    Given I start watching the HUD page messages
    And my metadata "stress" is 20
    And the HUD player payload should show "stress" as 20
    When the HUD receives the legacy stress event with the raw value "250"
    Then the HUD player payload should show "stress" as 100
    When the HUD receives the legacy stress event with the raw value "-3"
    Then the HUD player payload should show "stress" as 0
    When the HUD receives the legacy stress event with the raw value "calm"
    And the HUD page asks for its initial state
    Then the HUD player payload should show "stress" as 0
    And my metadata "stress" should be at most 20

  @ui
  Scenario Outline: Legacy toggle events flip a display flag and back
    When the HUD receives the legacy toggle event "<event>"
    Then the HUD compat flag "<flag>" should be flipped
    When the HUD receives the legacy toggle event "<event>"
    Then the HUD compat flag "<flag>" should be back where it started

    Examples:
      | event                         | flag          |
      | hud:client:ToggleHealth       | dynamicHealth |
      | hud:client:ToggleAirHud       | altitude      |
      | hud:client:ToggleShowSeatbelt | showSeatbelt  |
      | seatbelt:client:ToggleCruise  | cruise        |

  @ui
  Scenario Outline: Legacy nitrous event is clamped to 0-100
    When the HUD receives the legacy nitrous event with level "<level>" and boost "<boost>"
    Then the HUD compat payload should show nitrous level <shown> with boost "<boost>"

    Examples:
      | level | boost | shown |
      | 150   | on    | 100.0 |
      | -20   | off   | 0.0   |
      | 42.5  | on    | 42.5  |
      | fast  | on    | 0.0   |

  @ui
  Scenario Outline: Legacy harness event is clamped to 0-100
    When the HUD receives the legacy harness event with "<uses>" uses
    Then the HUD compat payload should show <shown> harness uses

    Examples:
      | uses | shown |
      | 250  | 100.0 |
      | 3    | 3.0   |
      | -1   | 0.0   |

  @ui
  Scenario: Legacy harness event without a number clears the harness
    When the HUD receives the legacy harness event with "7" uses
    Then the HUD compat payload should show 7.0 harness uses
    When the HUD receives the legacy harness event with "none" uses
    Then the HUD compat payload should show no harness

  @ui
  Scenario: Legacy account event shows the bank balance
    Given I start watching the HUD page messages
    And I have 4242 in my "bank" account
    And the HUD player payload should show "bank" as 4242
    When the HUD receives the legacy show accounts event for "bank"
    Then I should see a notification containing "$4242"

  @ui
  Scenario: Bank command shows the authoritative balance
    Given I start watching the HUD page messages
    And I have 4243 in my "bank" account
    And the HUD player payload should show "bank" as 4243
    When I run the command "bank"
    Then I should see a notification containing "$4243"

  # ---------------------------------------------------------------------------
  # Vehicle telemetry
  # ---------------------------------------------------------------------------

  @ui @world
  Scenario: Leaving the vehicle clears the vehicle panel
    Given I am driving a temporary "blista"
    When I leave the temporary vehicle
    Then the HUD page should be told I am on foot

  @ui @world
  Scenario: A parked vehicle reads zero speed
    Given I start watching the HUD page messages
    When I am driving a temporary "blista"
    Then the HUD vehicle payload should show a speed of 0

  @ui @world
  Scenario: Switching the engine off reaches the vehicle payload
    Given I am driving a temporary "blista"
    When I switch the temporary vehicle engine off
    And the HUD page asks for its initial state
    Then the HUD vehicle payload should show the engine off

  @ui @world
  Scenario: Headlight state reaches the vehicle payload
    Given I am driving a temporary "blista"
    When I switch the temporary vehicle headlights to "low"
    Then the HUD vehicle payload should show headlights "low"
    When I switch the temporary vehicle headlights to "high"
    Then the HUD vehicle payload should show headlights "high"

  # Electric models come from kora_fuel's Config.electricVehicles.
  @ui @world
  Scenario Outline: Fuel kind follows kora_fuel's electric list
    Given resource "kora_fuel" is running
    And I start watching the HUD page messages
    When I am driving a temporary "<model>"
    Then the HUD vehicle payload should show the fuel kind "<kind>"

    Examples:
      | model  | kind   |
      | blista | fuel   |
      | voltic | charge |

  @ui @world @rejection
  Scenario: A hidden HUD sends no vehicle telemetry
    Given I am driving a temporary "blista"
    When I force the HUD hidden through its export
    Then the HUD page should not receive "kora_hud:vehicle" within 1500 milliseconds
    When I release the forced HUD hide through its export
    Then the HUD vehicle payload should describe the vehicle I am in

  @ui @world
  Scenario: Minimap command flips the player's choice and back
    Given I remember my on-foot minimap view
    And I am driving a temporary "blista"
    When I toggle the minimap
    Then my minimap choice should have flipped and the HUD should say so
    When I toggle the minimap
    Then my minimap choice should be back where it started

  # ---------------------------------------------------------------------------
  # /ui element registry, with fft as the owner (client/uiregistry.lua)
  # ---------------------------------------------------------------------------

  @ui
  Scenario: A registered element is listed and answered with its saved layout
    When I register the HUD UI element "fftProbe"
    Then the HUD should apply a "saved" layout to "fftProbe" with:
      """
      { "x": 0, "y": 0, "placed": false, "scale": 1, "hidden": false }
      """
    And the HUD page element list should include "fftProbe" with:
      """
      { "owner": "fft", "label": "FFT probe", "group": "Other", "origin": "left top",
        "rect": { "x": 0.4, "y": 0.4, "w": 0.1, "h": 0.1 },
        "movable": true, "scalable": true, "hideable": false, "scaleMin": 0.75, "scaleMax": 1.5 }
      """
    And the HUD UI layout for "fftProbe" should include:
      """
      { "x": 0, "y": 0, "scale": 1, "hidden": false }
      """

  @ui
  Scenario: A registered definition is sanitised
    When I register a HUD UI element with:
      """
      { "id": "fftProbe", "label": "An FFT probe label that is much longer than thirty two characters",
        "rect": { "x": 1.5, "y": -1, "w": 0.1, "h": 0.1 }, "origin": "middle nowhere",
        "scaleMin": 3, "scaleMax": 0.1, "defaultOffset": { "x": 5, "y": -5 },
        "settings": [
          { "key": "glow", "type": "toggle", "default": true },
          { "key": "size", "type": "range", "min": 0, "max": 10, "step": 2, "default": 3 },
          { "key": "mode", "type": "select", "options": [ "a", "b" ], "default": "z" },
          { "key": "9bad", "type": "toggle" }
        ] }
      """
    Then the HUD UI request should succeed
    And the HUD page element list should include "fftProbe" with:
      """
      { "label": "An FFT probe label that is much ", "group": "Other", "origin": "left top",
        "rect": { "x": 1, "y": 0, "w": 0.1, "h": 0.1 }, "defaultOffset": { "x": 1, "y": -1 },
        "scaleMin": 0.5, "scaleMax": 2,
        "settings": [
          { "key": "glow", "type": "toggle", "default": true },
          { "key": "size", "type": "range", "default": 4 },
          { "key": "mode", "type": "select", "default": "a" }
        ] }
      """
    And the HUD UI layout for "fftProbe" should include:
      """
      { "settings": { "glow": true, "size": 4, "mode": "a" } }
      """

  @ui @rejection
  Scenario: A definition that is not a table is refused
    When I register a HUD UI element that is not a table
    Then the HUD UI request should be refused with "definition must be a table"

  # HudUi.validId / RESERVED and HudUi.register in client/uiregistry.lua.
  @ui @rejection
  Scenario Outline: An unusable element id is refused
    When I register a HUD UI element with the id "<id>"
    Then the HUD UI request should be refused with "<reason>"
    And there should be no HUD UI layout for "<id>"

    Examples:
      | id                                | reason                       |
      | 1probe                            | invalid id                   |
      | fft probe                         | invalid id                   |
      | v                                 | invalid id                   |
      | minimapVehicleOnly                | invalid id                   |
      | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa | invalid id                   |
      | gauges                            | id is a built-in HUD section |
      | status                            | id is a built-in HUD section |

  @ui @rejection
  Scenario: The minimap id cannot be claimed
    When I register a HUD UI element with the id "minimap"
    Then the HUD UI request should be refused with "id taken"

  @ui @rejection
  Scenario: Another resource's element id cannot be claimed
    Given resource "kora_chat" is running
    When I register a HUD UI element with the id "chatInput"
    Then the HUD UI request should be refused with "id taken"

  @ui @rejection
  Scenario: A definition without a usable rect is refused
    When I register a HUD UI element with:
      """
      { "id": "fftProbe", "label": "FFT probe" }
      """
    Then the HUD UI request should be refused with "rect must be { x, y, w, h } in viewport fractions"
    When I register a HUD UI element with:
      """
      { "id": "fftProbe", "rect": { "x": 0.1, "y": 0.1, "w": 0, "h": 0.2 } }
      """
    Then the HUD UI request should be refused with "rect must be { x, y, w, h } in viewport fractions"
    And there should be no HUD UI layout for "fftProbe"

  # MAX_PER_OWNER = 12 in client/uiregistry.lua.
  @ui @rejection
  Scenario: A resource may register at most twelve elements
    When I register 12 HUD UI elements named "fftLimit"
    And I register a HUD UI element with the id "fftLimit13"
    Then the HUD UI request should be refused with "too many elements for this resource"
    And there should be no HUD UI layout for "fftLimit13"

  @ui
  Scenario: Registering the same id again replaces the definition
    When I register the HUD UI element "fftProbe"
    And I register a HUD UI element with:
      """
      { "id": "fftProbe", "label": "FFT probe again", "rect": { "x": 0.2, "y": 0.2, "w": 0.1, "h": 0.1 } }
      """
    Then the HUD UI request should succeed
    And the HUD page element list should include "fftProbe" with:
      """
      { "label": "FFT probe again", "rect": { "x": 0.2, "y": 0.2 } }
      """

  @ui
  Scenario: An owner can move its element's rect and default offset
    Given I register the HUD UI element "fftProbe"
    When I update the HUD UI element "fftProbe" with:
      """
      { "rect": { "x": 0.1, "y": 0.2, "w": 0.3, "h": 0.4 } }
      """
    Then the HUD UI request should succeed
    And the HUD page element list should include "fftProbe" with:
      """
      { "rect": { "x": 0.1, "y": 0.2, "w": 0.3, "h": 0.4 } }
      """
    When I update the HUD UI element "fftProbe" with:
      """
      { "defaultOffset": { "x": 0.1, "y": -0.1 } }
      """
    Then the HUD UI request should succeed
    And the HUD page element list should include "fftProbe" with:
      """
      { "defaultOffset": { "x": 0.1, "y": -0.1 } }
      """

  @ui @rejection
  Scenario: An update that changes nothing is refused
    Given I register the HUD UI element "fftProbe"
    When I update the HUD UI element "fftProbe" without a patch
    Then the HUD UI request should be refused with "patch must be a table"
    When I update the HUD UI element "fftProbe" with:
      """
      {}
      """
    Then the HUD UI request should be refused with "nothing to update"
    When I update the HUD UI element "fftProbe" with:
      """
      { "rect": { "x": 0.1 } }
      """
    Then the HUD UI request should be refused with "nothing to update"

  @ui @rejection
  Scenario Outline: Only the owner can update an element
    When I update the HUD UI element "<id>" with:
      """
      { "rect": { "x": 0.1, "y": 0.1, "w": 0.1, "h": 0.1 } }
      """
    Then the HUD UI request should be refused with "not registered by this resource"

    Examples:
      | id        |
      | fftGhost  |
      | minimap   |

  @ui
  Scenario: An owner can unregister its element once
    Given I register the HUD UI element "fftProbe"
    When I unregister the HUD UI element "fftProbe"
    Then the HUD UI request should succeed
    And the HUD page element list should not include "fftProbe"
    And there should be no HUD UI layout for "fftProbe"
    When I unregister the HUD UI element "fftProbe"
    Then the HUD UI request should be refused

  @ui @rejection
  Scenario: Another resource's element cannot be unregistered
    When I unregister the HUD UI element "minimap"
    Then the HUD UI request should be refused
    And the HUD UI layout for "minimap" should include:
      """
      { "hidden": false }
      """

  @ui @rejection
  Scenario: An unknown element has no layout
    Then there should be no HUD UI layout for "fftGhost"

  @ui @rejection
  Scenario: Previews are ignored while the editor is closed
    Given I register the HUD UI element "fftProbe"
    When the HUD page previews "fftProbe" with:
      """
      { "x": 0.2, "y": -0.1, "scale": 1.2 }
      """
    Then the HUD should not apply a "preview" layout to "fftProbe"

  @ui
  Scenario: A preview reaches the owner clamped, and cancelling puts the saved layout back
    Given I register the HUD UI element "fftProbe"
    When I open the HUD layout editor
    And the HUD page previews "fftProbe" with:
      """
      { "x": 0.2, "y": -0.1, "scale": 5 }
      """
    Then the HUD should apply a "preview" layout to "fftProbe" with:
      """
      { "x": 0.2, "y": -0.1, "placed": true, "scale": 1.5, "hidden": false }
      """
    When I cancel the HUD layout editor
    Then the HUD should apply a "saved" layout to "fftProbe" with:
      """
      { "x": 0, "y": 0, "placed": false, "scale": 1 }
      """

  @ui
  Scenario: A saved element layout is clamped and handed to its owner
    Given I register the HUD UI element "fftProbe"
    When I open the HUD layout editor
    And I save the HUD layout with these changes:
      """
      { "offsets": { "fftProbe": { "x": 0.3, "y": -0.2 } },
        "scales": { "fftProbe": 9 },
        "hidden": { "fftProbe": true } }
      """
    Then the HUD layout editor should be closed
    And the HUD should apply a "saved" layout to "fftProbe" with:
      """
      { "x": 0.3, "y": -0.2, "placed": true, "scale": 1.5, "hidden": false }
      """
    And the HUD UI layout for "fftProbe" should include:
      """
      { "x": 0.3, "y": -0.2, "scale": 1.5, "hidden": false }
      """

  @ui
  Scenario: A hideable element keeps its visibility and cleaned settings
    Given I register a HUD UI element with:
      """
      { "id": "fftProbe", "label": "FFT probe", "rect": { "x": 0.4, "y": 0.4, "w": 0.1, "h": 0.1 },
        "hideable": true, "scaleMin": 0.8, "scaleMax": 1.2,
        "settings": [
          { "key": "glow", "type": "toggle", "default": true },
          { "key": "size", "type": "range", "min": 0, "max": 10, "step": 2, "default": 4 },
          { "key": "mode", "type": "select", "options": [ "a", "b" ] }
        ] }
      """
    And the HUD UI request should succeed
    When I open the HUD layout editor
    And I save the HUD layout with these changes:
      """
      { "scales": { "fftProbe": 0.1 },
        "hidden": { "fftProbe": true },
        "settings": { "fftProbe": { "glow": false, "size": 7, "mode": "b", "extra": 1 } } }
      """
    Then the HUD should apply a "saved" layout to "fftProbe" with:
      """
      { "scale": 0.8, "hidden": true, "settings": { "glow": false, "size": 8, "mode": "b" } }
      """
    And the HUD UI layout for "fftProbe" should include:
      """
      { "scale": 0.8, "hidden": true, "settings": { "glow": false, "size": 8, "mode": "b" } }
      """
