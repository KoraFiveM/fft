@kora @kora_loading
Feature: kora_loading loading screen
  kora_loading has no server realm and its page exists only while the client
  loads, before a tester and an FFT session exist. Nothing the player sees on
  the loading screen (progress bar, tips, wallpaper, video, music player) can
  be tested from a running session, and neither can the moment of the handoff.
  These scenarios cover what remains: the manifest contract, the fact that the
  manually shut down screen is gone, and the answers of the two NUI callbacks
  the pages fetch, run with a real fetch from the FFT page at the callback
  level. The live reaction to a /theme change is not driven because it would
  change the tester's personal theme colour.

  Background:
    Given resource "kora_loading" is running

  # Paths are the loadscreen, ui_page and files entries of kora_loading/fxmanifest.lua.
  @server
  Scenario: Manifest declares a manually shut down loading screen
    Then the loading screen manifest should declare the page "html/index.html" with manual shutdown
    And the loading screen resource should ship the file "html/app.js"
    And the loading screen resource should ship the file "html/style.css"
    And the loading screen resource should ship the file "html/sync.html"
    And the loading screen resource should ship the file "html/sync.js"
    And the loading screen resource should ship the file "html/kora_theme/theme.js"

  Scenario: Loading screen is gone once the character is in game
    Then the loading screen should have been shut down

  @ui
  Scenario: Loading screen page is given complete settings
    When the loading screen page fetches its settings
    Then the loading screen settings should be complete
    And the loading screen settings should keep their numbers within the configured ranges

  @ui
  Scenario: Sync page is given the same player colour as the loading screen
    When the loading screen page fetches its settings
    Then the loading screen sync page should be given the same player colour

  # loadscreen_cursor and ui_page are lines of kora_loading/fxmanifest.lua.
  @server
  Scenario Outline: Manifest entry <key> is declared
    Then the loading screen manifest entry "<key>" should be "<value>"

    Examples:
      | key                        | value             |
      | loadscreen                 | html/index.html   |
      | loadscreen_manual_shutdown | yes               |
      | loadscreen_cursor          | yes               |
      | ui_page                    | html/sync.html    |
      | fx_version                 | cerulean          |
      | lua54                      | yes               |

  @server
  Scenario Outline: Loading screen depends on <dependency>
    Then the loading screen manifest should depend on "<dependency>"

    Examples:
      | dependency |
      | kora_theme |
      | kora_lib   |

  @server
  Scenario: Loading screen has no server realm
    Then the loading screen should register no server script

  # html/kora_theme/** and html/media/* entries; the files are the synced theme
  # copy and the default video (Config.media.video = 'media/loading.webm').
  @server
  Scenario Outline: Loading screen ships <path>
    Then the loading screen resource should ship the file "<path>"

    Examples:
      | path                                  |
      | html/index.html                       |
      | html/kora_theme/theme.json            |
      | html/kora_theme/fonts/fonts.css       |
      | html/kora_theme/fonts/catalog.json    |
      | html/media/loading.webm               |

  @server
  Scenario: Synced theme copy is valid JSON
    Then the loading screen theme copy should be valid JSON

  @ui
  Scenario: Media and music player settings have the configured types
    When the loading screen page fetches its settings
    Then the loading screen media settings should have the configured types
    And the loading screen video should be empty or a WebM file

  @ui
  Scenario: Settings callback ignores the request body
    When the loading screen page fetches its settings
    And the loading screen page fetches its settings with an unexpected body
    Then the loading screen settings should not echo the unexpected body

  @ui
  Scenario: Settings callback answers the same on a repeated fetch
    When the loading screen page fetches its settings
    Then fetching the loading screen settings again should give the same answer

  # Steps from the kora_theme suite; they restore the tester's personal colour.
  @ui
  Scenario: A personal theme colour reaches both loading screen pages
    Given my personal theme colour is "#7C3AED"
    When the loading screen page fetches its settings
    Then the loading screen settings should give the player colour "#7C3AED"
    And the loading screen sync page should be given the player colour "#7C3AED"

  @ui
  Scenario: Resetting the personal theme gives the pages no colour
    Given my personal theme colour is "#06B6D4"
    When I run the theme command "theme reset"
    Then I should have no personal theme colour
    When the loading screen page fetches its settings
    Then the loading screen settings should give no player colour
    And the loading screen sync page should be given no player colour

  @ui
  Scenario: A /theme change is answered by the next sync fetch
    Given my personal theme colour is "#06B6D4"
    When I run the theme command "theme 3B82F6"
    Then my personal theme colour should be "#3B82F6"
    And the loading screen sync page should be given the player colour "#3B82F6"
    When the loading screen page fetches its settings
    Then the loading screen settings should give the player colour "#3B82F6"
