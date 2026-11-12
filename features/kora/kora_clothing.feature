@kora @kora_clothing
Feature: kora_clothing shops, wardrobe and fitting room
  Sessions are opened through the public OpenClothingRoom / OpenWardrobe
  exports and the fitting room page's callbacks are run with a real fetch at
  the NUI-callback level; kora_clothing/fft_hooks.lua observes what the page
  is sent. Money, the routing bucket and the saved
  rows are checked on the server. Every scenario that opens a session cancels a
  session left open, puts the ped's clothes back, rewrites the saved appearance
  exactly as it was and deletes outfits named "fft-...". Camera framing, ped
  rotation and how the clothes look are visual and are not asserted. Barber,
  hairdresser, tattoo, first-character and admin sessions are not opened.

  Background:
    Given resource "kora_clothing" is running

  # Coordinates are Config.shops[1].points.racks ("Suburban") in config.lua; the
  # prompt text is ('Open %s'):format(shop.label) in client.lua.
  @world
  Scenario: Standing at the clothes racks offers the shop
    Given I stand at 121.63 -224.23 54.56 facing 152.18
    Then the clothing shop prompt should offer "Open Suburban"

  # Prices are Config.services.clothing.prices, currency is Config.shop.currency.
  @world @ui
  Scenario: A clothing shop opens a private fitting room and cancelling leaves everything as it was
    Given the fitting room hooks should be version 2
    And my saved appearance and outfits are put back after the scenario
    And I remember my saved appearance
    And I remember my "cash" balance
    And I remember my routing bucket before the fitting
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    Then the fitting room should have opened as a "shop" session for the "clothing" service
    And the fitting room should be for the shop "Suburban"
    And the fitting room should price "tops" at 175 in "cash"
    And the fitting room should price "legs" at 150 in "cash"
    And the fitting room should price "shoes" at 120 in "cash"
    And the fitting room should price "body" at 90 in "cash"
    And the fitting room should price "accessories" at 60 in "cash"
    And the fitting room camera should be active with the page focused
    And the HUD should be hidden for the fitting
    And I should be in my private fitting bucket
    When I point the fitting room camera at "torso"
    And I try on a different jacket
    And I cancel the fitting
    Then the fitting room should close
    And the fitting room camera should be released
    And I should be wearing the jacket the fitting started with
    And the HUD should be as it was before the fitting
    And I should be back in the routing bucket I came from
    And my "cash" balance should be unchanged
    And my saved appearance should be unchanged

  # Standing at Config.shops[2].points.register, about 1.2 km from shop 1. The
  # text is requestSession's sessionError in server.lua.
  @world @rejection
  Scenario: A shop cannot be opened from somewhere else
    Given I remember my routing bucket before the fitting
    And I stand at 75.80 -1392.88 29.38 facing 90.89
    When I ask to open the clothing shop 1
    Then I should see a notification containing "Move closer to the Suburban to open it."
    And the fitting room should not open
    And I should be back in the routing bucket I came from

  @rejection
  Scenario: A shop that is not configured does not open
    Given I remember my routing bucket before the fitting
    When I ask to open the clothing shop 9999
    Then the fitting room should not open
    And I should be back in the routing bucket I came from

  @world @ui @rejection
  Scenario: A jacket the character cannot afford is not sold
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I have 100 in my "cash" account
    And I remember my "cash" balance
    And I remember my saved appearance
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I try on a different jacket
    And I confirm the fitting
    Then the fitting room should report an error
    And the fitting room should still be open
    And my "cash" balance should be unchanged
    And my saved appearance should be unchanged
    When I cancel the fitting
    Then the fitting room should close
    And I should be wearing the jacket the fitting started with

  @world @ui
  Scenario: Buying a jacket charges the tops price and saves the new look
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I have 500 in my "cash" account
    And I remember my "cash" balance
    And I remember my saved appearance
    And I remember my routing bucket before the fitting
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I try on a different jacket
    And I confirm the fitting
    Then the fitting room should close
    And the fitting room should not report an error
    And I should see a notification containing "Outfit updated."
    And my "cash" balance should have decreased by 175
    And my saved appearance should have changed
    And I should be wearing the jacket I tried on
    And I should be back in the routing bucket I came from

  # Wardrobe sessions have no location check (requestSession, mode 'wardrobe').
  @ui
  Scenario: An outfit saved from the wardrobe can be listed and deleted
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I remember my "cash" balance
    And I remember my routing bucket before the fitting
    When I open my wardrobe
    Then the fitting room should have opened as a "wardrobe" session for the "clothing" service
    And I should be in my private fitting bucket
    When I confirm the fitting and save it as "fft-wardrobe-look"
    Then the fitting room should close
    And the fitting room should not report an error
    And I should have a saved outfit named "fft-wardrobe-look"
    And the legacy outfit list should include "fft-wardrobe-look"
    And my "cash" balance should be unchanged
    When I open my wardrobe
    Then the fitting room should list the saved outfit "fft-wardrobe-look"
    When I delete the saved outfit "fft-wardrobe-look" in the fitting room
    Then I should have no saved outfit named "fft-wardrobe-look"
    When I cancel the fitting
    Then the fitting room should close
    And I should be back in the routing bucket I came from

  @ui @rejection
  Scenario: The fitting room page is refused when no session is open
    Then the clothing exports should report no fitting in progress
    And the fitting room page should be refused "setVariation" without a session
    And the fitting room page should be refused "confirm" without a session
    And the fitting room page should be refused "cancel" without a session
    And the clothing exports should report no fitting in progress

  # Shared.models in shared/components.lua.
  Scenario: The compatibility exports describe an idle resource
    Then the clothing exports should report no fitting in progress
    And the clothing exports should name the ped models "mp_m_freemode_01" and "mp_f_freemode_01"

  # The refusal is OpenAdminSession's first return in server.lua.
  @server @rejection
  Scenario: Only kora_admin can open a remote admin fitting
    When another resource asks for a remote admin fitting of the "clothing" service on me
    Then the remote admin fitting should be refused with "only kora_admin may open a remote admin session"

  # ---------------------------------------------------------------------------
  # Every clothing shop (Config.shops[1..6], register and rack points)
  # ---------------------------------------------------------------------------

  # Points are Config.shops[n].points in config.lua; the label is shop.label.
  @world @ui
  Scenario Outline: Clothing shop <shop> opens from its <point> point as "<label>" with the clothing prices
    Given my saved appearance and outfits are put back after the scenario
    And I remember my "cash" balance
    And I remember my routing bucket before the fitting
    And I stand at <x> <y> <z> facing <heading>
    Then the clothing shop prompt should offer "Open <label>"
    When I open the clothing shop <shop>
    Then the fitting room should have opened as a "shop" session for the "clothing" service
    And the fitting room should be for the shop "<label>"
    And the fitting room should price "tops" at 175 in "cash"
    And the fitting room should price "accessories" at 60 in "cash"
    And I should be in my private fitting bucket
    When I cancel the fitting
    Then the fitting room should close
    And I should be back in the routing bucket I came from
    And my "cash" balance should be unchanged

    Examples:
      | shop | point    | label     | x        | y        | z     | heading |
      | 1    | register | Suburban  | 125.35   | -223.62  | 54.56 | 248.79  |
      | 2    | register | Suburban  | 75.80    | -1392.88 | 29.38 | 90.89   |
      | 2    | racks    | Suburban  | 78.76    | -1397.40 | 29.38 | 267.65  |
      | 3    | register | Ponsonbys | -710.34  | -152.69  | 37.42 | 298.30  |
      | 3    | racks    | Ponsonbys | -708.64  | -160.39  | 37.42 | 209.55  |
      | 4    | register | Ponsonbys | -163.47  | -303.67  | 39.73 | 70.19   |
      | 4    | racks    | Ponsonbys | -158.79  | -296.45  | 39.73 | 341.35  |
      | 5    | register | Binco     | -1192.75 | -768.44  | 17.32 | 36.34   |
      | 5    | racks    | Binco     | -1189.30 | -769.79  | 17.33 | 245.16  |
      | 6    | register | Binco     | -822.16  | -1073.86 | 11.33 | 29.02   |
      | 6    | racks    | Binco     | -824.60  | -1078.85 | 11.33 | 207.89  |

  # requestSession's nearShop check runs before any service policy, so every
  # configured shop far from the Suburban racks answers with its own label.
  @world @rejection
  Scenario Outline: Shop <shop> ("<label>") cannot be opened from the Suburban racks
    Given I remember my routing bucket before the fitting
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I ask to open the clothing shop <shop>
    Then I should see a notification containing "Move closer to the <label> to open it."
    And the fitting room should not open
    And I should be back in the routing bucket I came from

    Examples:
      | shop | label         |
      | 3    | Ponsonbys     |
      | 4    | Ponsonbys     |
      | 5    | Binco         |
      | 6    | Binco         |
      | 7    | Tattoo Artist |
      | 12   | Tattoo Artist |
      | 13   | Barber        |
      | 14   | Barber        |
      | 15   | Hairdresser   |
      | 16   | Hairdresser   |

  # Config.shops has 16 entries; anything else is not a shop (requestSession).
  @rejection
  Scenario Outline: Shop id <shop> is not a configured shop and opens nothing
    Given I remember my routing bucket before the fitting
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I ask to open the clothing shop <shop>
    Then the fitting room should not open
    And I should not see a notification containing "Move closer"
    And I should be back in the routing bucket I came from

    Examples:
      | shop |
      | 0    |
      | -1   |
      | 17   |

  @rejection
  Scenario Outline: A shop id that is not a number ("<id>") opens nothing
    Given I remember my routing bucket before the fitting
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I ask to open a clothing shop with the shop id "<id>"
    Then the fitting room should not open
    And I should be back in the routing bucket I came from

    Examples:
      | id    |
      | abc   |
      | one   |

  # ---------------------------------------------------------------------------
  # Other opening routes
  # ---------------------------------------------------------------------------

  @world @ui
  Scenario: The numeric qb-clothing form of OpenClothingRoom opens the shop
    Given my saved appearance and outfits are put back after the scenario
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1 the legacy way
    Then the fitting room should be for the shop "Suburban"
    And the clothing exports should report a fitting in progress
    When I cancel the fitting
    Then the fitting room should close

  # qb-clothing:client:openMenu with no shop -> openNearestShop('clothing').
  @world @ui
  Scenario: A third-party script opens the nearest clothing shop
    Given my saved appearance and outfits are put back after the scenario
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When a third-party script opens the nearest clothing shop
    Then the fitting room should have opened as a "shop" session for the "clothing" service
    And the fitting room should be for the shop "Suburban"
    When I cancel the fitting
    Then the fitting room should close

  # Text is ('You are not near a %s shop'):format(service) in client.lua.
  @world @rejection
  Scenario: Asking for the nearest tattoo shop at a clothing store is refused
    Given I stand at 121.63 -224.23 54.56 facing 152.18
    When a third-party script asks for the nearest "tattoo" shop
    Then I should see a notification containing "You are not near a tattoo shop"
    And the fitting room should not open

  # Standing at Config.shops[7].coords (a tattoo studio).
  @world @rejection
  Scenario: Asking for the nearest clothing shop at a tattoo studio is refused
    Given I stand at 1321.61 -1653.76 52.28 facing 354.98
    When a third-party script asks for the nearest "clothing" shop
    Then I should see a notification containing "You are not near a clothing shop"
    And the fitting room should not open

  @ui
  Scenario Outline: The wardrobe opens through <route>
    Given my saved appearance and outfits are put back after the scenario
    And I remember my routing bucket before the fitting
    When I open my wardrobe through "<route>"
    Then the fitting room should have opened as a "wardrobe" session for the "clothing" service
    And the fitting room should price "tops" at 175 in "cash"
    And I should be in my private fitting bucket
    When I cancel the fitting
    Then the fitting room should close
    And I should be back in the routing bucket I came from

    Examples:
      | route                              |
      | OpenWardrobe                       |
      | getOutfits                         |
      | qb-clothing:client:openOutfitMenu  |

  # openSession ignores a request while the page is on screen, and the server
  # ignores requestSession while sessions[src] exists.
  @world @ui @rejection
  Scenario: Asking for the wardrobe while a shop fitting is open changes nothing
    Given my saved appearance and outfits are put back after the scenario
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I ask to open my wardrobe while the fitting is open
    Then the fitting room should have been sent only one open message
    And the fitting room should be for the shop "Suburban"
    When I cancel the fitting
    Then the fitting room should close
    And the fitting room page should be refused "cancel" without a session

  # requestSession returns for 'firstCharacter' when a saved appearance exists.
  @rejection
  Scenario: First character creation cannot be reopened for a character with a saved look
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I remember my routing bucket before the fitting
    When a third-party script starts first character creation
    Then the fitting room should not open
    And the clothing exports should report no fitting in progress
    And I should be back in the routing bucket I came from

  # The [E] prompt is hidden while a session is open (refreshShopPrompt).
  @world @ui
  Scenario: The shop prompt is hidden during the fitting and comes back afterwards
    Given my saved appearance and outfits are put back after the scenario
    And I stand at 121.63 -224.23 54.56 facing 152.18
    Then the clothing shop prompt should offer "Open Suburban"
    When I open the clothing shop 1
    Then no text prompt should be shown
    When I cancel the fitting
    Then the fitting room should close
    And the text prompt should show "Open Suburban"

  # ---------------------------------------------------------------------------
  # Pricing: one price per category touched (priceDiff in server.lua)
  # ---------------------------------------------------------------------------

  @world @ui
  Scenario Outline: Changing component <component> in a clothing shop charges the <category> price of <price>
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I have 1000 in my "cash" account
    And I remember my "cash" balance
    And I remember my saved appearance
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I try on a different component <component>
    And I confirm the fitting
    Then the fitting room should close
    And my "cash" balance should have decreased by <price>
    And my saved component <component> should have changed

    Examples:
      | component | category    | price |
      | 3         | tops        | 175   |
      | 4         | legs        | 150   |
      | 5         | accessories | 60    |
      | 6         | shoes       | 120   |
      | 7         | accessories | 60    |
      | 8         | tops        | 175   |
      | 9         | tops        | 175   |
      | 10        | accessories | 60    |
      | 11        | tops        | 175   |

  @world @ui
  Scenario Outline: Changing prop <prop> in a clothing shop charges the accessories price
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I have 1000 in my "cash" account
    And I remember my "cash" balance
    And I remember my saved appearance
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I try on a different prop <prop>
    And I confirm the fitting
    Then the fitting room should close
    And my "cash" balance should have decreased by 60
    And my saved prop <prop> should have changed

    Examples:
      | prop |
      | 0    |
      | 1    |
      | 2    |
      | 6    |
      | 7    |

  # Components 0-2 are not in Config.services.clothing.components, so
  # mergeServiceSkin keeps the saved ones and nothing is charged.
  @world @ui
  Scenario Outline: A component <component> preview in a clothing shop is neither charged nor saved
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I have 1000 in my "cash" account
    And I remember my "cash" balance
    And I remember my saved appearance
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I try on a different component <component>
    And I confirm the fitting
    Then the fitting room should close
    And my "cash" balance should be unchanged
    And my saved component <component> should be as it was

    Examples:
      | component |
      | 0         |
      | 1         |
      | 2         |

  @world @ui
  Scenario: Two categories changed in one fitting are both charged
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I have 1000 in my "cash" account
    And I remember my "cash" balance
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I try on a different component 11
    And I try on a different component 4
    And I confirm the fitting
    Then the fitting room should close
    And my "cash" balance should have decreased by 325

  @world @ui
  Scenario: Two changes in the same category are charged once
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I have 1000 in my "cash" account
    And I remember my "cash" balance
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I try on a different component 11
    And I try on a different component 8
    And I try on a different prop 0
    And I try on a different prop 6
    And I confirm the fitting
    Then the fitting room should close
    And my "cash" balance should have decreased by 235

  @world @ui
  Scenario: Confirming without changing anything costs nothing
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I have 1000 in my "cash" account
    And I remember my "cash" balance
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I confirm the fitting
    Then the fitting room should close
    And the fitting room should not report an error
    And I should see a notification containing "Outfit updated."
    And my "cash" balance should be unchanged

  @world @ui
  Scenario: Exactly enough cash buys the jacket
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I have 175 in my "cash" account
    And I remember my "cash" balance
    And I remember my saved appearance
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I try on a different jacket
    And I confirm the fitting
    Then the fitting room should close
    And my "cash" balance should have decreased by 175
    And my saved appearance should have changed

  @world @ui @rejection
  Scenario: One short of the jacket price is refused
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I have 174 in my "cash" account
    And I remember my "cash" balance
    And I remember my saved appearance
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I try on a different jacket
    And I confirm the fitting
    Then the fitting room should report an error
    And the fitting room should still be open
    And my "cash" balance should be unchanged
    And my saved appearance should be unchanged
    When I cancel the fitting
    Then the fitting room should close
    And I should be wearing exactly what the fitting started with

  # Config.shop.currency is 'cash'; bank money does not pay.
  @world @ui @rejection
  Scenario: Money in the bank does not pay for clothes
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I have 0 in my "cash" account
    And I have 5000 in my "bank" account
    And I remember my "cash" balance
    And I remember my "bank" balance
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I try on a different jacket
    And I confirm the fitting
    Then the fitting room should report an error
    And my "cash" balance should be unchanged
    And my "bank" balance should be unchanged
    When I cancel the fitting
    Then the fitting room should close

  # The wardrobe is priced like a shop (confirmSession charges every mode but firstCharacter).
  @ui
  Scenario: A new jacket chosen in the wardrobe is charged like a shop
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I have 1000 in my "cash" account
    And I remember my "cash" balance
    When I open my wardrobe
    And I try on a different jacket
    And I confirm the fitting
    Then the fitting room should close
    And my "cash" balance should have decreased by 175

  @world @ui
  Scenario: Confirming twice in a row charges once
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I have 1000 in my "cash" account
    And I remember my "cash" balance
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I try on a different jacket
    And I confirm the fitting twice in a row
    Then the fitting room should close
    And exactly one clothing purchase of 175 should have been charged to "cash"
    And my "cash" balance should have decreased by 175

  # No playerskins row: the first confirm is a free sync (confirmSession).
  @world @ui
  Scenario: A character with no saved appearance is not charged for the first fitting
    Given my saved appearance and outfits are put back after the scenario
    And I have no saved appearance on record
    And I have 1000 in my "cash" account
    And I remember my "cash" balance
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I try on a different jacket
    And I confirm the fitting
    Then the fitting room should close
    And my "cash" balance should be unchanged
    And my saved appearance should exist
    And my saved appearance is put back now
    And I reload my saved appearance with the "reloadSkin export"

  # ownedOutfitMatch: an exact match for a saved outfit is not charged again.
  @world @ui @slow
  Scenario: Wearing a saved outfit again is free
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I have 1000 in my "cash" account
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open my wardrobe
    And I confirm the fitting and save it as "fft-owned-look"
    Then the fitting room should close
    And I should have a saved outfit named "fft-owned-look"
    When I remember my "cash" balance
    And I open the clothing shop 1
    And I try on a different jacket
    And I confirm the fitting
    Then the fitting room should close
    And my "cash" balance should have decreased by 175
    When I remember my "cash" balance
    And I remember my saved appearance
    And I open my wardrobe
    And I put on the saved outfit "fft-owned-look" in the fitting room
    And I confirm the fitting
    Then the fitting room should close
    And the fitting room should not report an error
    And my "cash" balance should be unchanged
    And my saved appearance should have changed

  @world @ui
  Scenario: A bought jacket is what the wardrobe puts on next time
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I have 1000 in my "cash" account
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I try on a different jacket
    And I confirm the fitting
    Then the fitting room should close
    When I open my wardrobe
    Then I should be wearing the jacket I tried on
    When I cancel the fitting
    Then the fitting room should close

  # ---------------------------------------------------------------------------
  # The fitting room page (NUI callbacks, client.lua)
  # ---------------------------------------------------------------------------

  @ui @rejection
  Scenario Outline: The fitting room page refuses "<callback>" when no session is open
    Then the fitting room page should be refused "<callback>" without a session
    And the clothing exports should report no fitting in progress

    Examples:
      | callback          |
      | loadOutfit        |
      | setTattoos        |
      | setUndress        |
      | setClothingToggle |
      | setHairColor      |
      | setHead           |

  @ui @rejection
  Scenario: The fitting room page does not start a rotate drag when no session is open
    Then the fitting room page should not start a rotate drag without a session

  # Config.services.clothing / Config.ui.clothingToggles.services (live config).
  @world @ui @rejection
  Scenario Outline: A clothing shop refuses the "<callback>" control that belongs to another service
    Given my saved appearance and outfits are put back after the scenario
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    Then the clothing shop page should refuse "<callback>"
    And I should be wearing exactly what the fitting started with
    When I cancel the fitting
    Then the fitting room should close

    Examples:
      | callback          |
      | setHairColor      |
      | setHead           |
      | setTattoos        |
      | setUndress        |
      | setClothingToggle |

  # setVariation only accepts Shared.components / Shared.props ids.
  @world @ui @rejection
  Scenario: Malformed variations are refused and change nothing
    Given my saved appearance and outfits are put back after the scenario
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    Then the fitting room page should refuse the variation:
      """
      { "kind": "component", "id": 12, "drawable": 1, "texture": 0 }
      """
    And the fitting room page should refuse the variation:
      """
      { "kind": "prop", "id": 3, "drawable": 1, "texture": 0 }
      """
    And the fitting room page should refuse the variation:
      """
      { "kind": "outfit", "id": 11, "drawable": 1, "texture": 0 }
      """
    And the fitting room page should refuse the variation:
      """
      { "kind": "component", "drawable": 1, "texture": 0 }
      """
    And I should be wearing exactly what the fitting started with
    When I cancel the fitting
    Then the fitting room should close

  # Negative drawables clamp to 0, a face index past the end falls back to 0,
  # and a prop drawable of -1 removes the prop; Cancel puts it all back.
  @world @ui
  Scenario: Out-of-range variations are clamped and cancelling undoes them
    Given my saved appearance and outfits are put back after the scenario
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And the fitting room page should accept the variation:
      """
      { "kind": "component", "id": 11, "drawable": -5, "texture": -2 }
      """
    Then the fitting room page should have answered with drawable 0
    And component 11 should be on drawable 0 on my ped
    When the fitting room page should accept the variation:
      """
      { "kind": "component", "id": 0, "drawable": 100000, "texture": 0 }
      """
    Then the fitting room page should have answered with drawable 0
    When the fitting room page should accept the variation:
      """
      { "kind": "prop", "id": 0, "drawable": -1, "texture": 0 }
      """
    Then prop 0 should be removed from my ped
    When I cancel the fitting
    Then the fitting room should close
    And I should be wearing exactly what the fitting started with

  @world @ui
  Scenario: Cancelling puts back several components and props
    Given my saved appearance and outfits are put back after the scenario
    And I remember my "cash" balance
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I try on a different component 4
    And I try on a different component 6
    And I try on a different prop 1
    And I cancel the fitting
    Then the fitting room should close
    And I should be wearing exactly what the fitting started with
    And my "cash" balance should be unchanged

  # Config.camera.zones; Camera.setZone ignores other names.
  @world @ui
  Scenario Outline: The fitting room camera frames the "<zone>" preset
    Given my saved appearance and outfits are put back after the scenario
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I point the fitting room camera at "<zone>"
    Then pointing the fitting room camera at "feet" should leave it on "<zone>"
    And choosing the "tops" category should leave the fitting room camera on "<zone>"
    When I cancel the fitting
    Then the fitting room should close
    And the fitting room camera should be released

    Examples:
      | zone  |
      | full  |
      | face  |
      | torso |
      | legs  |
      | shoes |

  # ---------------------------------------------------------------------------
  # Saved outfits
  # ---------------------------------------------------------------------------

  # confirmSession: saveName:sub(1, 50) then trimmed.
  @ui
  Scenario: An outfit name is trimmed before it is saved
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    When I open my wardrobe
    And I confirm the fitting and save it under the raw name "   fft-trimmed   "
    Then the fitting room should close
    And I should have a saved outfit named "fft-trimmed"

  @ui
  Scenario: An outfit name longer than 50 characters is cut to 50
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    When I open my wardrobe
    And I confirm the fitting and save it under the raw name "fft-long-name-0123456789012345678901234567890123456789XYZ"
    Then the fitting room should close
    And I should have a saved outfit named "fft-long-name-012345678901234567890123456789012345"

  @ui
  Scenario: A blank outfit name saves no outfit
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    And I remember how many outfits I have saved
    When I open my wardrobe
    And I confirm the fitting and save it under the raw name "    "
    Then the fitting room should close
    And the fitting room should not report an error
    And I should have as many saved outfits as before

  # getOutfitSkin answers nil for an id the citizen does not own.
  @ui @rejection
  Scenario: Loading an outfit that does not exist is refused
    Given my saved appearance and outfits are put back after the scenario
    When I open my wardrobe
    Then the fitting room should refuse to load the outfit id 0
    And the fitting room should refuse to load the outfit id -1
    And I should be wearing exactly what the fitting started with
    When I cancel the fitting
    Then the fitting room should close

  @ui @rejection
  Scenario: Deleting an outfit id that is not mine leaves my outfits alone
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    When I open my wardrobe
    And I confirm the fitting and save it as "fft-keep-me"
    Then the fitting room should close
    When I open my wardrobe
    And I delete the outfit id 0 in the fitting room
    Then I should have a saved outfit named "fft-keep-me"
    When I cancel the fitting
    Then the fitting room should close

  # qb-clothing:server:removeOutfit: the name must match the row and the
  # event has a 2 s per-player cooldown (stockAllowed, STOCK_COOLDOWN_MS).
  @ui @slow
  Scenario: A third-party script removes an outfit only under its real name
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    When I open my wardrobe
    And I confirm the fitting and save it as "fft-legacy-a"
    Then the fitting room should close
    When I wait 2100 milliseconds
    And a third-party script removes my saved outfit "fft-legacy-a" calling it "fft-legacy-other"
    Then I should have a saved outfit named "fft-legacy-a"
    When I wait 2100 milliseconds
    And a third-party script removes my saved outfit "fft-legacy-a"
    Then I should have no saved outfit named "fft-legacy-a"

  @ui @slow @rejection
  Scenario: A second outfit removal inside the cooldown is ignored
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    When I open my wardrobe
    And I confirm the fitting and save it as "fft-legacy-a"
    Then the fitting room should close
    When I open my wardrobe
    And I confirm the fitting and save it as "fft-legacy-b"
    Then the fitting room should close
    When I wait 2100 milliseconds
    And a third-party script removes my saved outfit "fft-legacy-a"
    And a third-party script removes my saved outfit "fft-legacy-b"
    Then I should have no saved outfit named "fft-legacy-a"
    And I should have a saved outfit named "fft-legacy-b"

  # ---------------------------------------------------------------------------
  # Appearance outside the fitting room
  # ---------------------------------------------------------------------------

  @ui
  Scenario Outline: The <route> puts the saved look back on
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    When I open my wardrobe
    And I cancel the fitting
    Then the fitting room should close
    When my jacket is changed outside the fitting room
    And I reload my saved appearance with the "<route>"
    Then I should be wearing the jacket the fitting started with

    Examples:
      | route               |
      | refreshskin command |
      | reloadSkin export   |

  # getStarterAppearance refuses a citizen with a saved appearance.
  @rejection
  Scenario: The starter outfit is refused for a character that already has a look
    Given my saved appearance and outfits are put back after the scenario
    And my appearance is on record with the server
    Then the starter appearance should be refused

  # ApplyAppearanceToPed's refusals in client.lua.
  @rejection
  Scenario: Appearances are not applied to a missing ped or a mismatched model
    Then applying an appearance to no ped should be refused with "invalid ped"
    And applying the "a_m_y_skater_01" appearance to my ped should be refused with "ped model does not match appearance model"
    And applying the other freemode appearance to my ped should be refused with "ped model does not match appearance model"

  Scenario: An appearance can dress a local copy of the ped without touching the player
    Then an appearance applied to a local copy of my ped should dress that copy

  # ---------------------------------------------------------------------------
  # Quick clothing toggles (client/quicktoggle.lua, Config.quickToggle)
  # ---------------------------------------------------------------------------

  # Shirt part: component 11 to drawable 15 (Config.quickToggle.parts).
  Scenario Outline: Taking the shirt off through <route> and putting it back
    Given I am wearing jacket drawable 0 outside the fitting room
    And I wait 1600 milliseconds
    When I toggle my shirt through "<route>"
    Then I should see a notification containing "Shirt taken off. Use it again to put it back."
    And my jacket should be drawable 15
    When I wait 1600 milliseconds
    And I run the command "c shirt"
    Then I should see a notification containing "Shirt put back on."
    And my jacket should be drawable 0

    Examples:
      | route                                    |
      | /c shirt                                 |
      | /c top                                   |
      | /c jacket                                |
      | /c torso                                 |
      | qb-radialmenu:ToggleClothing top         |
      | qb-radialmenu:ToggleClothing shirt by id |
      | qb-clothing:client:adjustfacewear 5      |

  Scenario: Quick toggle reset puts everything back
    Given I am wearing jacket drawable 0 outside the fitting room
    And I wait 1600 milliseconds
    When I run the command "c shirt"
    Then my jacket should be drawable 15
    When I wait 1600 milliseconds
    And I run the command "c reset"
    Then I should see a notification containing "Clothes put back on."
    And my jacket should be drawable 0

  # Config.quickToggle.cooldownMs is 1500.
  @rejection
  Scenario: A second quick toggle inside the cooldown is ignored
    Given I am wearing jacket drawable 0 outside the fitting room
    And I wait 1600 milliseconds
    When I run the command "c shirt"
    Then my jacket should be drawable 15
    When I run the command "c shirt"
    Then I should not see a notification containing "Shirt put back on."
    And my jacket should be drawable 15

  @rejection
  Scenario: Quick toggles explain how to use them
    When I run the command "c"
    Then I should see a notification containing "Usage: /c <vest|shirt|pants"
    When I run the command "c nonsense"
    Then I should see a notification containing "Usage: /c"

  @rejection
  Scenario: Quick toggles on a missing hat say so
    Given I am wearing no hat outside the fitting room
    And I wait 1600 milliseconds
    When I run the command "c hat"
    Then I should see a notification containing "You are not wearing anything there (Hat)."
    When I wait 1600 milliseconds
    And I run the command "c visor"
    Then I should see a notification containing "You are not wearing a hat or helmet."

  @world @ui @rejection
  Scenario: Quick toggles are refused while the fitting room is open
    Given my saved appearance and outfits are put back after the scenario
    And I stand at 121.63 -224.23 54.56 facing 152.18
    When I open the clothing shop 1
    And I run the command "c shirt"
    Then I should see a notification containing "Close the clothing menu first."
    And I should be wearing exactly what the fitting started with
    When I cancel the fitting
    Then the fitting room should close
