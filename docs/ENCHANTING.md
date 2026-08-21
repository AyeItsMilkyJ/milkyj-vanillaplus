# Better enchanting in MilkyCraft Vanilla+

MilkyCraft uses the enchanting systems already present in the pack instead of adding another table replacement.

## Player progression

The normal Enchanting Table automatically opens **Quark Matrix Enchanting**. Insert an enchantable item and lapis, generate pieces with lapis and experience, place compatible pieces on the grid, and merge matching pieces to raise their level. The item and lapis remain in the table while the player works.

The tuned server configuration keeps the vanilla progression gates but reduces dead-end rolling:

- maximum enchanting power remains 15 bookshelves;
- one lapis supplies five Matrix piece charges instead of four;
- the experience-price step moves from every 9 generated pieces to every 12;
- the duplicate-piece weight rises from 1.4 to 1.75 so merging is more practical;
- a maximum of four coloured candles remains in force;
- each candle's influence rises from 0.125 to 0.25;
- treasure and undiscoverable enchantments remain unavailable from the table.

The last point is deliberate. Mending, Swift Sneak and other treasure-only results must still come from their intended loot, trade or exploration paths.

**Easy Anvils 8.0.2** removes the hard Too Expensive cap, halves book-application costs, makes renaming free and uses a fixed prior-work penalty. A Grindstone is the early destructive reset. **Create: Enchantment Industry 1.4.1** is the later workshop path for liquid experience, disenchanting and printing. **Enchantment Descriptions 17.1.21** remains the client-side explanation layer.

## Why another mod was not added

The latest Forge 1.20.1 Enchanting Infuser is `v8.0.3`. It provides exact enchantment selection, but it would become a third overlapping table/workstation path. More importantly for this pack, upstream reports cover missing Alex's Caves enchantments and Forge 1.20.1 gear operations failing in a GeckoLib environment. MilkyCraft contains both Alex's Caves and GeckoLib, so a clean startup alone cannot prove Infuser's item screen is safe.

Primary evidence:

- [Quark's Matrix Enchanting language and behaviour source](https://github.com/VazkiiMods/Quark/blob/master/src/main/resources/assets/quark/lang/en_us.json)
- [Easy Magic project and source](https://github.com/Fuzss/easy-magic)
- [Easy Anvils source](https://github.com/Fuzss/easy-anvils)
- [Enchanting Infuser source and supported-version table](https://github.com/Fuzss/enchanting-infuser)
- [Infuser and Alex's Caves report](https://github.com/Fuzss/enchanting-infuser/issues/83)
- [Infuser 1.20.1/GeckoLib gear-operation report](https://github.com/Fuzss/enchanting-infuser/issues/120)

No enchanting mod JAR was added, removed or updated by this change.

## Outstanding manual interaction check

Automated validation can prove the configuration parses, the quest graph is valid and Forge starts, but it cannot click the Matrix grid. Complete this checklist before promoting the pre-release to a final release or claiming the interaction itself is verified:

1. open a disposable authenticated client against the disposable server;
2. place a fresh Enchanting Table with fifteen clear bookshelves;
3. confirm the Matrix screen—not the classic three-offer screen—opens;
4. generate pieces on a disposable iron item;
5. merge a matching pair and commit one enchantment;
6. compare rolls with and without a coloured candle, then test soul-sand inversion;
7. enchant a book and combine it through an Anvil;
8. verify treasure enchantments do not appear;
9. test a Grindstone and Enchantment Industry machine only with disposable gear;
10. confirm another client sees the same server-authoritative result.

Do not use a live player's best gear for this gate.
