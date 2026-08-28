# Bundled fonts

All five faces are licensed under the SIL Open Font License 1.1, which permits bundling in
an application. Sources are the Google Fonts repository.

| File | Family | Designer / source |
|---|---|---|
| `Jua-Regular.ttf` | Jua | Woowahan Brothers — OFL 1.1 |
| `Andika-Bold.ttf` | Andika | SIL International — OFL 1.1. Drawn specifically for literacy and beginning readers. |
| `ComicNeue-Bold.ttf` | Comic Neue | Craig Rozynski — OFL 1.1 |
| `Sniglet-ExtraBold.ttf` | Sniglet | Haley Fiege / Sorkin Type — OFL 1.1 |
| `VarelaRound-Regular.ttf` | Varela Round | Joe Prince — OFL 1.1 |

Fonts are registered at runtime by `FontRegistry`, so adding another face is a matter of
dropping the TTF here and running `xcodegen generate`. Vet it against
`MaskRendererFontTests` first — see `WIREFRAME_SPEC.md` §7.2 for what makes a face
traceable.
