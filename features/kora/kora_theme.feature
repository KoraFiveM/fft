@kora @kora_theme
Feature: kora_theme palette, tokens and personal colour
  The palette, token and font exports are checked against kora_theme's own
  theme.json, read when the scenario runs. The personal colour is driven through
  the real /theme command and the setPlayerTheme export; it lives in the client
  KVP, so every scenario puts the previous choice back.
  The picker frame is driven at the NUI-callback level (kora_theme:set and
  kora_theme:close, which only kora_theme registers); nothing clicks the rendered
  swatches, and "open" is inferred from NUI focus because the resource exposes
  no picker state.
  Not covered: that consumer UIs actually repaint (each resource's own browser
  frame applies the tokens, not observable from Lua), the in-game /config font
  editor (admin configuration that changes what every player sees), the
  emergency palette used when theme.json is unreadable, the disabled-player-theme
  branch (server configuration), and that the colour survives a reconnect (the
  KVP belongs to kora_theme and cannot be read from fft).

  Background:
    Given resource "kora_theme" is running

  @server
  Scenario: Palette follows the theme file
    Then the theme primary colour should match the theme file
    And the theme palette should match every colour in the theme file

  @server
  Scenario: A caller can override the primary colour
    Then the theme palette with the primary override "#7c3aed" should use "#7C3AED" as primary

  @server @rejection
  Scenario: An invalid override is ignored
    Then the theme palette should ignore the invalid primary override "purple"

  @server
  Scenario Outline: Design tokens are derived from the palette
    Then the theme token "<token>" for the primary "<primary>" should be "<value>"

    Examples:
      | primary | token              | value     |
      | #FFFFFF | primary            | 0 0% 100% |
      | #FFFFFF | primary-foreground | 0 0% 6.3% |
      | #000000 | primary            | 0 0% 0%   |
      | #000000 | primary-foreground | 0 0% 100% |

  @server
  Scenario: Fixed tokens and fonts are available
    Then the theme token "radius-full" should be "9999px"
    And the theme token "duration-fast" should be "120ms"
    And the theme should resolve a body, heading and mono font

  Scenario: Command sets and resets the personal colour
    When I run the theme command "theme #7c3aed"
    Then my personal theme colour should be "#7C3AED"
    When I run the theme command "theme reset"
    Then I should have no personal theme colour

  Scenario: Command accepts a colour without the hash
    When I run the theme command "theme 3B82F6"
    Then my personal theme colour should be "#3B82F6"

  @rejection
  Scenario Outline: An invalid personal colour is refused and nothing changes
    Given my personal theme colour is "#06B6D4"
    Then setting my personal theme colour to "<colour>" should be refused with "Use a six-digit hex colour such as #7C3AED, or reset."
    And my personal theme colour should be "#06B6D4"

    Examples:
      | colour  |
      | purple  |
      | #12345  |
      | #GGGGGG |

  @rejection
  Scenario: Command ignores an invalid colour
    Given my personal theme colour is "#06B6D4"
    When I run the theme command "theme notacolour"
    Then my personal theme colour should be "#06B6D4"

  @ui
  Scenario: Command without a colour opens the picker
    When I run the theme command "theme"
    Then the theme picker should hold the cursor
    When I close the theme picker
    Then the theme picker should have released the cursor

  @ui
  Scenario: Picker applies a preset
    When I run the theme command "theme"
    Then the theme picker should hold the cursor
    When I pick the preset "Violet" in the theme picker
    Then the theme picker should accept the choice and show "#7C3AED" as selected
    And the theme picker should offer the server default first and the preset "Violet"
    And my personal theme colour should be "#7C3AED"
    When I close the theme picker
    Then the theme picker should have released the cursor

  @ui @rejection
  Scenario: Picker refuses a malformed colour
    Given my personal theme colour is "#06B6D4"
    When I pick the colour "#XYZ" in the theme picker
    Then the theme picker should refuse the choice with "Use a six-digit hex colour such as #7C3AED, or reset."
    And my personal theme colour should be "#06B6D4"

  # ---------------------------------------------------------------------------
  # Palette overrides (resolveColours in kora_theme/shared.lua)
  # ---------------------------------------------------------------------------

  @server
  Scenario Outline: Any palette colour can be overridden by a caller
    Then the theme palette with the "<key>" override "<colour>" should use "<expected>" for it

    Examples:
      | key        | colour  | expected |
      | danger     | #123456 | #123456  |
      | success    | #abcdef | #ABCDEF  |
      | background | #000000 | #000000  |
      | primary    | #7c3aed | #7C3AED  |

  @server @rejection
  Scenario Outline: A malformed override for a palette colour is ignored
    Then the theme palette should ignore the invalid "<key>" override "<colour>"

    Examples:
      | key     | colour   |
      | danger  | red      |
      | danger  | #FFF     |
      | success | 22C55E   |
      | border  | #1234567 |

  @server @rejection
  Scenario: An override for an unknown colour adds nothing
    Then the theme palette should ignore an override for the unknown colour "notAColour"

  @server @rejection
  Scenario: An override that is neither a colour nor a table is ignored
    Then the theme palette with a numeric override should be the base palette

  # ---------------------------------------------------------------------------
  # Token derivation (getTokens in kora_theme/shared.lua); values computed with
  # the resource's own hslToken/contrastToken.
  # ---------------------------------------------------------------------------

  @server
  Scenario Outline: Brand tokens follow the primary colour
    Then the theme token "<token>" for the primary "<primary>" should be "<value>"

    Examples:
      | primary | token              | value                    |
      | #7C3AED | primary            | 262.1 83.3% 57.8%        |
      | #7C3AED | primary-foreground | 0 0% 100%                |
      | #7C3AED | brand-hover        | 262.1 83.3% 52.7%        |
      | #7C3AED | brand-pressed      | 262.1 83.3% 47.2%        |
      | #7C3AED | focus-ring         | 262.1 83.3% 57.8% / 0.55 |
      | #7C3AED | brand-soft         | 262.1 83.3% 57.8% / 0.14 |
      | #7C3AED | selection          | 262.1 83.3% 57.8% / 0.35 |
      | #95FF00 | primary-foreground | 0 0% 6.3%                |
      | #95FF00 | brand-hover        | 84.9 100% 44.9%          |
      | #FF0000 | primary            | 0 100% 50%               |
      | #FF0000 | brand-pressed      | 0 100% 39.4%             |
      | #3B82F6 | ring               | 217.2 91.2% 59.8%        |

  @server
  Scenario Outline: Status colour overrides drive their own tokens
    Then the theme token "<token>" with the "<key>" override "<colour>" should be "<value>"

    Examples:
      | key     | colour  | token                  | value     |
      | success | #000000 | success                | 0 0% 0%   |
      | success | #000000 | success-foreground     | 0 0% 100% |
      | danger  | #FFFFFF | destructive            | 0 0% 100% |
      | danger  | #FFFFFF | destructive-foreground | 0 0% 6.3% |
      | danger  | #FFFFFF | danger                 | 0 0% 100% |

  @server
  Scenario Outline: Tokens that share a palette colour agree
    Then the theme token "<token>" should equal the token "<other>"

    Examples:
      | token              | other          |
      | ring               | primary        |
      | card-foreground    | foreground     |
      | popover-foreground | foreground     |
      | danger             | destructive    |
      | muted              | secondary      |
      | input              | control-border |
      | secondary-text     | info           |

  @server
  Scenario Outline: Fixed tokens keep their values
    Then the theme token "<token>" should be "<value>"

    Examples:
      | token            | value                         |
      | space            | 0.25rem                       |
      | space-4          | 1rem                          |
      | space-6          | 1.5rem                        |
      | duration-popover | 160ms                         |
      | duration-dialog  | 180ms                         |
      | ease-entry       | cubic-bezier(0.16, 1, 0.3, 1) |

  @server
  Scenario: Corner and shadow tokens follow the theme file shape
    Then the theme radius tokens should follow the theme file shape
    And the theme shadow tokens should follow the theme file shape

  @server
  Scenario: Fonts come from the bundled catalog and feed the font tokens
    Then every theme font should come from the font catalog or its default
    And the theme font tokens should match the resolved fonts

  Scenario: The client exports read the same theme file
    Then the client theme palette should match every colour in the theme file

  # ---------------------------------------------------------------------------
  # Personal colour through the export (setPlayerTheme in client/main.lua)
  # ---------------------------------------------------------------------------

  Scenario Outline: The export normalises a personal colour
    When I set my personal theme colour to "<colour>"
    Then my personal theme colour should be "<stored>"

    Examples:
      | colour      | stored  |
      | #abcdef     | #ABCDEF |
      | ec4899      | #EC4899 |
      | 7C3AED      | #7C3AED |

  # normaliseHex trims surrounding whitespace before checking the colour.
  Scenario: The export trims a padded personal colour
    When I set my personal theme colour to "  #7c3aed  "
    Then my personal theme colour should be "#7C3AED"

  Scenario Outline: The export clears the personal colour on reset words
    Given my personal theme colour is "#06B6D4"
    When I set my personal theme colour to "<word>"
    Then I should have no personal theme colour

    Examples:
      | word    |
      | reset   |
      | default |
      |         |

  Scenario: The export clears the personal colour without a value
    Given my personal theme colour is "#06B6D4"
    When I clear my personal theme colour through the export
    Then I should have no personal theme colour

  # Only the command lower-cases reset words; the export compares them exactly.
  @rejection
  Scenario Outline: The export refuses other values
    Given my personal theme colour is "#06B6D4"
    Then setting my personal theme colour to "<colour>" should be refused with "Use a six-digit hex colour such as #7C3AED, or reset."
    And my personal theme colour should be "#06B6D4"

    Examples:
      | colour    |
      | RESET     |
      | #7C3AED00 |
      | ##7C3AED  |
      | 7C3 AED   |

  Scenario: An accepted change is announced to the UI bridges
    Given I watch for personal theme changes
    When I set my personal theme colour to "#22C55E"
    Then a personal theme change should have been announced

  @rejection
  Scenario: A refused change is not announced
    Given my personal theme colour is "#06B6D4"
    And I watch for personal theme changes
    Then setting my personal theme colour to "teal" should be refused with "Use a six-digit hex colour such as #7C3AED, or reset."
    And no personal theme change should have been announced

  # ---------------------------------------------------------------------------
  # /theme command
  # ---------------------------------------------------------------------------

  Scenario Outline: Command reset words are case-insensitive
    Given my personal theme colour is "#06B6D4"
    When I run the theme command "theme <word>"
    Then I should have no personal theme colour

    Examples:
      | word    |
      | RESET   |
      | Default |

  @rejection
  Scenario: Command explains a refused colour in chat
    Given my personal theme colour is "#06B6D4"
    And I watch for theme chat messages
    When I run the theme command "theme notacolour"
    Then the theme command should answer in chat with "Use a six-digit hex colour such as #7C3AED, or reset."
    And my personal theme colour should be "#06B6D4"

  Scenario: Command with a valid colour does not answer in chat
    Given I watch for theme chat messages
    When I run the theme command "theme #F97316"
    Then my personal theme colour should be "#F97316"
    And the theme command should not answer in chat

  # ---------------------------------------------------------------------------
  # Picker frame callbacks
  # ---------------------------------------------------------------------------

  @ui
  Scenario: Picker reset clears the personal colour
    Given my personal theme colour is "#06B6D4"
    When I reset my colour in the theme picker
    Then the theme picker should accept the choice and show no colour as selected
    And I should have no personal theme colour

  @ui
  Scenario: Picker normalises a typed colour
    When I pick the colour "ec4899" in the theme picker
    Then the theme picker should accept the choice and show "#EC4899" as selected
    And my personal theme colour should be "#EC4899"

  @ui
  Scenario: Picker lists the server default and the theme file presets in order
    When I pick the preset "Cyan" in the theme picker
    Then the theme picker should accept the choice and show "#06B6D4" as selected
    And the theme picker should list the theme file presets in order

  @ui
  Scenario: Page handshake reports the personal colour, presets and fonts
    Given my personal theme colour is "#3B82F6"
    Then the theme page handshake should report my personal colour, the presets and the fonts

  @ui
  Scenario: Page handshake without a personal colour
    Given my personal theme colour is "#3B82F6"
    And I clear my personal theme colour through the export
    Then the theme page handshake should report my personal colour, the presets and the fonts

  @ui
  Scenario: Opening the picker twice needs only one close
    When I run the theme command "theme"
    And I run the theme command "theme"
    Then the theme picker should hold the cursor
    When I close the theme picker
    Then the theme picker should have released the cursor

  @ui
  Scenario: Closing a picker that is not open is answered and harmless
    When I close the theme picker
    Then the theme picker should have released the cursor
