Vinegar for Rust Oxide
============

Vinegar is an Oxide plugin for Rust which allows players to modify structures and determine who owns a structure. It also allows the player to build non-standard structures.

Vinegar is enabled by default for all users, or can be optionally configured to use the Oxmin flag system for permissions. The flag is "canvinegar"


/vinegar - toggle structure destruction on or off.

Vinegar can be configured to use Oxmin's flag system for permissions, or it can be configured to be enabled for all players.

To use Oxmin's flag system, edit the vinegar.txt file and set "vinegarForAll" to false.

No changes to the vinegar.txt file are necessary if you want vinegar available to all players.

With Vinegar enabled, the user can destroy structures that they own. This includes walls, foundations, pillars, ceilings.

If the user is in god mode, they can destroy anyone's structure.

To deactivate destruction, toggle Vinegar off using /vinegar.


/vinegar {damage} - specify the amount of damage to be dealt per blow/hit/shot.

1000 is the default.

10000 will destroy any structure item in one hit.

Once set, the value is saved in vinegar.txt.


/prod

Prod allows the user to see the owner of any structure, deployable item or sleeper.

To toggle prod, use the chat command "/prod".

This requires the Oxmin flag "canprod".