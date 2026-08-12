"""Shared visual language for the upgrade tiers.

Leading underscore on purpose: art/build_all.py's discover() skips files starting
with "_", so this is importable by the nine tier scripts without itself being
treated as a model. That is the existing affordance for a shared module inside a
category directory - do not rename it.

WHAT THE PLAYER HAS TO BE ABLE TO SEE
-------------------------------------
docs/design/upgrades.md 8: "a tower's tier must read at RTS-camera distance
without UI". Nine end-states across three families is a lot to ask someone to
learn from silhouette alone, so the ladder is carried by two signals, not one:

  1. RANK BANDS - a systemic, family-independent tier count. None at tier 1, one
     band at tier 2, two at tier 3. Learned once, read everywhere, and legible
     at distances where a barrel count is not. This is the only part of the tier
     language that is identical across all three families, and that is the point.
  2. SILHOUETTE - per upgrades.md 8. Tier 2 is the same shape, bulkier. Tier 3
     is a distinct shape per branch.

Bands alone would be a UI element glued to a model; silhouette alone fails when
two families' tier-3s are on screen at once and the player is looking at a lane
rather than at a tower. Together they degrade gracefully - if the shape read
fails at distance, the band count still lands.

NODE NAMING - READ THIS BEFORE ADDING A PART
--------------------------------------------
game/views/tower_view.gd tints by node name. It currently uses exact-match lists:

    BODY_PARTS   = ["Base", "Plinth", "TurretHead"]
    ACCENT_PARTS = ["AmmoDrum", "Sight", "Muzzle"]

A4 is replacing the accent half with `Accent*` prefix matching this session (see
docs/ROUND-2.md, A4 item 4). That change had not landed when these nine models
were built, so every tier here is named to survive BOTH regimes:

  * Body parts use the exact names Base / Plinth / TurretHead. These work today,
    and `Base` can never be renamed anyway - tower_view.gd finds it by name to
    drive the tower, so it is a behaviour contract, not just a tint list.
  * Each tier carries exactly one node named `Muzzle`, so at least one accent
    part is tinted under TODAY's exact-match list.
  * Every other accent part is named `Accent<Thing>`, so it tints the moment
    prefix matching lands and keeps its exported material until then.

The exported accent material below is a neutral light metal for exactly that
reason: an untinted accent part has to still read as a bright detail rather than
as a missing texture. See art/PENDING.md 3 for the hazard this hedges against.
"""

import math

import studio


def materials():
    """One palette for all nine tiers, so a family's tiers cannot drift apart.

    Hull is neutral grey: Godot overrides it with body_color, and a hand-tinted
    hull is how the Frost Mortar and Plasma Lance hid a missing tint for a whole
    release (art/PENDING.md 3).
    """
    return {
        "hull": studio.material("Hull", (0.55, 0.58, 0.62), metallic=0.35, roughness=0.5),
        "dark": studio.material("Dark", (0.15, 0.16, 0.19), metallic=0.25, roughness=0.68),
        # Neutral light metal, NOT a palette colour: this is what an accent part
        # looks like before accent_color reaches it.
        "accent": studio.material("Accent", (0.78, 0.76, 0.7), metallic=0.5, roughness=0.35),
        "glow": studio.material("Glow", (0.8, 0.92, 1.0), metallic=0.1,
                                roughness=0.25, emission=0.7),
    }


def rank_bands(parent, count, radius, base_z, material, spacing=0.12, thickness=0.07):
    """The tier pips: `count` rings stacked up the plinth.

    Rings rather than studs or a painted stripe because a ring has no facing -
    the count reads from every angle the RTS camera can reach, including from
    directly behind the tower, which is where half of them will be.

    Named Accent* so accent_color picks them up once prefix matching lands. Until
    then they are the neutral light metal above, which still separates them from
    the plinth they sit on - so the tier count is legible either way.
    """
    made = []
    for index in range(count):
        band = studio.cylinder(
            "AccentRank%d" % (index + 1),
            radius_bottom=radius, radius_top=radius,
            height=thickness, segments=8,
            parent=parent,
            location=(0.0, 0.0, base_z + index * spacing),
            material=material,
        )
        studio.bevel(band, width=0.012)
        made.append(band)
    return made


def ring(name, parent, radius, z, material, thickness=0.07, segments=10):
    """A reinforcement collar. Used for barrel banding on the heavier tiers,
    where 'this part is stronger than it was' is the entire brief."""
    obj = studio.cylinder(
        name, radius_bottom=radius, radius_top=radius, height=thickness,
        segments=segments, parent=parent, location=(0.0, 0.0, z), material=material,
    )
    studio.bevel(obj, width=0.012)
    return obj


def radial(count, radius, start_deg=0.0):
    """Yield (index, x, y, angle) for `count` items evenly around Z.

    Used for the Hailstorm's rotary barrels and the Glacier's vanes. Written
    once because both got it subtly wrong when written separately.
    """
    for index in range(count):
        angle = math.radians(start_deg) + index * math.tau / count
        yield index, math.cos(angle) * radius, math.sin(angle) * radius, angle
